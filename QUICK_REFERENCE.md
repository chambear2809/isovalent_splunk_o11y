# Quick Reference Guide

## All Commands in Order

### 1. Add Helm Repositories
```bash
helm repo add isovalent https://helm.isovalent.com
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
helm repo update
export API_ENDPOINT="$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '{print $NF}' | sed 's|https://||')"
export CILIUM_CHART_VERSION="$(helm search repo isovalent/cilium --versions | awk 'NR==2 {print $2}')"
export CILIUM_DNSPROXY_CHART_VERSION="$(helm search repo isovalent/cilium-dnsproxy --versions | awk 'NR==2 {print $2}')"
export TETRAGON_CHART_VERSION="$(helm search repo isovalent/tetragon --versions | awk 'NR==2 {print $2}')"
export SPLUNK_OTEL_CHART_VERSION="$(helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | awk 'NR==2 {print $2}')"
```

### 2. Create Cluster Configuration Files

**cluster.yaml:**
```bash
cat > cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: isovalent-demo
  region: us-east-1
  version: "1.30"
iam:
  withOIDC: true
addonsConfig:
  disableDefaultAddons: true
addons:
- name: coredns
EOF
```

### 3. Create EKS Cluster
```bash
eksctl create cluster -f cluster.yaml
aws eks update-kubeconfig --name isovalent-demo --region us-east-1
```

### 4. Get API Server Endpoint
```bash
aws eks describe-cluster --name isovalent-demo --region us-east-1 --query 'cluster.endpoint' --output text
```

### 5. Install Prometheus CRDs
```bash
kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.68.0/stripped-down-crds.yaml
```

### 6. Create Cilium Values File

**Replace `<YOUR-EKS-API-SERVER-ENDPOINT>` with actual endpoint (without https://):**

```bash
export API_ENDPOINT="<YOUR-EKS-API-SERVER-ENDPOINT>"

cat > cilium-enterprise-values.yaml <<EOF
debug:
  enabled: false
  verbose: ~

cluster:
  name: isovalent-demo
  id: 0

eni:
  enabled: true
  updateEC2AdapterLimitViaAPI: true
  awsEnablePrefixDelegation: true

enableIPv4Masquerade: false
loadBalancer:
  serviceTopology: true

ipam:
  mode: eni

routingMode: native

kubeProxyReplacement: "true"
k8sServiceHost: ${API_ENDPOINT}
k8sServicePort: 443

tls:
  ca:
    certValidityDuration: 3650

hubble:
  enabled: true
  metrics:
    enableOpenMetrics: true
    enabled:
      - dns:labelsContext=source_namespace,destination_namespace
      - drop:labelsContext=source_namespace,destination_namespace
      - tcp:labelsContext=source_namespace,destination_namespace
      - port-distribution:labelsContext=source_namespace,destination_namespace
      - icmp:labelsContext=source_namespace,destination_namespace;sourceContext=workload-name|reserved-identity;destinationContext=workload-name|reserved-identity
      - flow:sourceContext=workload-name|reserved-identity;destinationContext=workload-name|reserved-identity
      - "httpV2:exemplars=true;labelsContext=source_ip,source_namespace,source_workload,destination_namespace,destination_workload,traffic_direction;sourceContext=workload-name|reserved-identity;destinationContext=workload-name|reserved-identity"
      - "policy:sourceContext=app|workload-name|pod|reserved-identity;destinationContext=app|workload-name|pod|dns|reserved-identity;labelsContext=source_namespace,destination_namespace"
      - flow_export
    serviceMonitor:
      enabled: true
  tls:
    enabled: true
    auto:
      enabled: true
      method: cronJob
      certValidityDuration: 1095
  relay:
    enabled: true
    tls:
      server:
        enabled: true
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: true
  timescape:
    enabled: true

operator:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true

prometheus:
  enabled: true
  serviceMonitor:
    enabled: true

envoy:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true

extraConfig:
  external-dns-proxy: "true"

enterprise:
  featureGate:
    approved:
      - DNSProxyHA
      - HubbleTimescape
EOF
```

### 7. Install Cilium
```bash
helm upgrade --install cilium isovalent/cilium --version "${CILIUM_CHART_VERSION}" \
  --namespace kube-system -f cilium-enterprise-values.yaml \
  --set k8sServiceHost="${API_ENDPOINT}"
```

Do not use `--reuse-values` when moving `cilium` or `cilium-dnsproxy` to a newer published chart. Reapply the intended values file so Helm does not preserve older computed image tags.

### 8. Create Nodegroup

**nodegroup.yaml:**
```bash
cat > nodegroup.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: isovalent-demo
  region: us-east-1
managedNodeGroups:
- name: standard
  instanceType: m5.xlarge
  desiredCapacity: 2
  privateNetworking: true
EOF
```

```bash
eksctl create nodegroup -f nodegroup.yaml
```

### 9. Install Tetragon
```bash
helm upgrade --install tetragon isovalent/tetragon --version "${TETRAGON_CHART_VERSION}" \
  --namespace tetragon --create-namespace
```

### 10. Install DNS Proxy HA

**cilium-dns-proxy-ha-values.yaml:**

The values file keeps the historical repo filename, but the live Helm release is `cilium-dnsproxy`.
```bash
cat > cilium-dns-proxy-ha-values.yaml <<EOF
enableCriticalPriorityClass: true
metrics:
  serviceMonitor:
    enabled: true
EOF
```

```bash
helm upgrade --install cilium-dnsproxy isovalent/cilium-dnsproxy --version "${CILIUM_DNSPROXY_CHART_VERSION}" \
  -n kube-system -f cilium-dns-proxy-ha-values.yaml
```

### 11. Configure Splunk OpenTelemetry Collector

**Replace placeholders with your Splunk credentials:**

```bash
export SPLUNK_TOKEN="<YOUR-SPLUNK-ACCESS-TOKEN>"
export SPLUNK_REALM="<YOUR-SPLUNK-REALM>"

cat > examples/splunk-otel-isovalent.yaml <<EOF
agent:
  config:
    extensions:
      k8s_observer:
        auth_type: serviceAccount
        observe_pods: true
    receivers:
      kubeletstats:
        insecure_skip_verify: true
      prometheus/isovalent_cilium:
        config:
          scrape_configs:
          - job_name: 'cilium_metrics_9962'
            metrics_path: /metrics
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_k8s_app]
              action: keep
              regex: cilium
            - source_labels: [__meta_kubernetes_pod_ip]
              target_label: __address__
              replacement: \${__meta_kubernetes_pod_ip}:9962
            - target_label: job
              replacement: 'cilium_metrics_9962'
          - job_name: 'hubble_metrics_9965'
            metrics_path: /metrics
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_k8s_app]
              action: keep
              regex: cilium
            - source_labels: [__meta_kubernetes_pod_ip]
              target_label: __address__
              replacement: \${__meta_kubernetes_pod_ip}:9965
            - target_label: job
              replacement: 'hubble_metrics_9965'
      prometheus/isovalent_envoy:
        config:
          scrape_configs:
          - job_name: 'envoy_metrics_9964'
            metrics_path: /metrics
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_k8s_app]
              action: keep
              regex: cilium-envoy
            - source_labels: [__meta_kubernetes_pod_ip]
              target_label: __address__
              replacement: \${__meta_kubernetes_pod_ip}:9964
            - target_label: job
              replacement: 'cilium_metrics_9964'
      prometheus/isovalent_operator:
        config:
          scrape_configs:
          - job_name: 'cilium_operator_metrics_9963'
            metrics_path: /metrics
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_io_cilium_app]
              action: keep
              regex: operator
            - target_label: job
              replacement: 'cilium_metrics_9963'
      prometheus/isovalent_tetragon:
        config:
          scrape_configs:
          - job_name: 'tetragon_metrics_2112'
            metrics_path: /metrics
            kubernetes_sd_configs:
            - role: pod
            relabel_configs:
            - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
              action: keep
              regex: tetragon
            - source_labels: [__meta_kubernetes_pod_ip]
              target_label: __address__
              replacement: \${__meta_kubernetes_pod_ip}:2112
            - target_label: job
              replacement: 'tetragon_metrics_2112'
    processors:
      # Filter metrics to prevent overwhelming Splunk Observability Cloud
      filter/includemetrics:
        metrics:
          include:
            match_type: strict
            metric_names:
            # Kubernetes metrics
            - container.cpu.usage
            - container.memory.rss
            - k8s.container.restarts
            - k8s.pod.phase
            # Cilium metrics
            - cilium_endpoint_state
            - cilium_bpf_map_ops_total
            - cilium_policy_l7_total
            # Hubble metrics
            - hubble_flows_processed_total
            - hubble_drop_total
            - hubble_dns_queries_total
            - hubble_http_requests_total
            # Tetragon metrics
            - tetragon_dns_total
            - tetragon_http_response_total
      resourcedetection:
        detectors: [system]
        system:
          hostname_sources: [os]
    service:
      pipelines:
        metrics:
          receivers:
          - prometheus/isovalent_cilium
          - prometheus/isovalent_envoy
          - prometheus/isovalent_operator
          - prometheus/isovalent_tetragon
          - hostmetrics
          - kubeletstats
          - otlp
          processors:
          - filter/includemetrics
          - resourcedetection
autodetect:
  prometheus: true
clusterName: isovalent-demo
environment: isovalent-demo
splunkObservability:
  accessToken: ${SPLUNK_TOKEN}
  realm: ${SPLUNK_REALM}
  profilingEnabled: true
cloudProvider: aws
distribution: eks
gateway:
  enabled: true
certmanager:
  enabled: true
operator:
  enabled: true
EOF
```

### 12. Install Splunk OpenTelemetry Collector
```bash
helm upgrade --install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --version "${SPLUNK_OTEL_CHART_VERSION}" \
  -n otel-splunk --create-namespace \
  -f examples/splunk-otel-isovalent.yaml

# Existing release: preserve live values before upgrading
helm get values splunk-otel-collector -n otel-splunk -o yaml > splunk-otel-live-values.yaml
# Merge the receiver and filter settings from examples/splunk-otel-isovalent.yaml into splunk-otel-live-values.yaml before using it for an upgrade.

helm status splunk-otel-collector -n otel-splunk
kubectl get deploy,ds,svc,cm -n otel-splunk
kubectl get instrumentation -A
manifest="$(helm get manifest splunk-otel-collector -n otel-splunk)"
if printf '%s\n' "$manifest" | grep -q '^kind: Instrumentation$'; then
  echo "Helm renders Instrumentation"
else
  echo "Helm does not render Instrumentation"
fi
kubectl get instrumentation -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MANAGED_BY:.metadata.labels.app\.kubernetes\.io/managed-by,HELM_RELEASE:.metadata.annotations.meta\.helm\.sh/release-name,EXPORTER:.spec.exporter.endpoint'
kubectl get ds cilium -n kube-system -o jsonpath='{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}'
kubectl get ds cilium-dnsproxy -n kube-system -o jsonpath='{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}'
kubectl get deploy splunk-otel-collector splunk-otel-collector-operator -n otel-splunk -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}{end}'
```

## Verification Commands

### Check All Components
```bash
kubectl get nodes
helm status cilium -n kube-system
helm status cilium-dnsproxy -n kube-system
helm status tetragon -n tetragon
helm status splunk-otel-collector -n otel-splunk
kubectl get pods,ds,deploy,svc -n kube-system
kubectl get pods,ds,deploy,svc -n tetragon
kubectl get pods,deploy,ds,svc,cm -n otel-splunk
kubectl get instrumentation -A
```

### Test Metrics Endpoints
```bash
kubectl exec -n kube-system ds/cilium -- curl -s localhost:9962/metrics | head -20
kubectl exec -n kube-system ds/cilium -- curl -s localhost:9965/metrics | head -20
kubectl get --raw '/api/v1/namespaces/tetragon/services/http:tetragon:metrics/proxy/metrics' | grep '^tetragon_' | head -20
```

### Check OTel Collector Logs
```bash
kubectl logs -n otel-splunk -l app=splunk-otel-collector,component=otel-collector-agent --tail=100 | grep -i "cilium\|hubble\|tetragon"
```

## Import Dashboards

### Dashboard Import Steps
1. Log in to Splunk Observability Cloud
2. Navigate to **Dashboards** → **Create** → **Import**
3. Upload dashboard JSON files from `examples/` directory:
   - `Cilium by Isovalent.json`
   - `Hubble by Isovalent.json`
4. Click **Import** for each dashboard
5. (Optional) Move dashboards to a dashboard group (e.g., "Isovalent")

### Available Dashboards
- **Cilium by Isovalent**: Agent health, ENI allocation, BPF maps, operator status
- **Hubble by Isovalent**: Network flows, DNS queries, dropped packets, HTTP metrics

## Cleanup Commands

```bash
# Delete nodegroup
eksctl delete nodegroup --cluster=isovalent-demo --name=standard --region=us-east-1

# Delete cluster
eksctl delete cluster --name=isovalent-demo --region=us-east-1
```

## Useful Troubleshooting Commands

```bash
# Check Cilium status
kubectl exec -n kube-system ds/cilium -- cilium status

# Check Cilium connectivity
kubectl exec -n kube-system ds/cilium -- cilium connectivity test

# View OTel configuration
kubectl get configmap -n otel-splunk splunk-otel-collector-otel-agent -o yaml | grep -A 5 "prometheus/isovalent"

# Check Helm release state before reinstalling the collector
helm status splunk-otel-collector -n otel-splunk

# Re-resolve latest published chart versions before upgrading
helm repo update
export CILIUM_CHART_VERSION="$(helm search repo isovalent/cilium --versions | awk 'NR==2 {print $2}')"
export CILIUM_DNSPROXY_CHART_VERSION="$(helm search repo isovalent/cilium-dnsproxy --versions | awk 'NR==2 {print $2}')"
export TETRAGON_CHART_VERSION="$(helm search repo isovalent/tetragon --versions | awk 'NR==2 {print $2}')"
export SPLUNK_OTEL_CHART_VERSION="$(helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | awk 'NR==2 {print $2}')"
printf 'cilium=%s\ncilium-dnsproxy=%s\ntetragon=%s\nsplunk-otel-collector=%s\n' \
  "${CILIUM_CHART_VERSION}" \
  "${CILIUM_DNSPROXY_CHART_VERSION}" \
  "${TETRAGON_CHART_VERSION}" \
  "${SPLUNK_OTEL_CHART_VERSION}"

# Check service discovery
kubectl get pods -n kube-system -l k8s-app=cilium -o wide
kubectl get pods -n tetragon -l app.kubernetes.io/name=tetragon -o wide
```
