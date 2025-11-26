# Isovalent Enterprise Platform Integration with Splunk Observability Cloud

## Overview

This lab guide provides step-by-step instructions for installing and configuring the Isovalent Enterprise Platform (Cilium, Hubble, and Tetragon) on Amazon EKS and integrating it with Splunk Observability Cloud for comprehensive monitoring and observability.

## Architecture

[Architecture diagram placeholder - will be added]

### Components

- **Amazon EKS**: Managed Kubernetes cluster running in AWS
- **Cilium Enterprise**: eBPF-based networking and security with ENI mode for AWS
- **Hubble**: Network observability with metrics, relay, and Timescape
- **Tetragon**: Runtime security and observability
- **DNS Proxy HA**: High-availability DNS proxy for FQDN-based policies
- **Splunk OpenTelemetry Collector**: Metrics collection and export to Splunk Observability Cloud

### Metrics Endpoints

| Component | Service Name | Port | Metrics Path |
|-----------|-------------|------|--------------|
| Cilium Agent | cilium-agent | 9962 | /metrics |
| Cilium Envoy | cilium-envoy | 9964 | /metrics |
| Cilium Operator | cilium-operator | 9963 | /metrics |
| Hubble | hubble-metrics | 9965 | /metrics |
| Tetragon | tetragon | 2112 | /metrics |

## Prerequisites

Before starting this lab, ensure you have:

- **AWS CLI** configured with appropriate credentials
- **kubectl** CLI tool installed
- **eksctl** CLI tool installed
- **Helm 3.x** installed
- **Splunk Observability Cloud** account with:
  - Access token
  - Realm identifier (e.g., us1, us2, eu0)
- Appropriate AWS permissions to create EKS clusters, VPCs, and related resources

> **📁 Configuration Files**: All configuration files used in this lab are available in the [`examples/`](examples/) directory. See the [examples README](examples/README.md) for details on required placeholders and customization options.

### Verify Prerequisites

```bash
# Check AWS CLI
aws --version

# Check kubectl
kubectl version --client

# Check eksctl
eksctl version

# Check Helm
helm version
```

## Lab Setup

### Step 1: Add Helm Repositories

Add the required Helm repositories for Isovalent and Splunk:

```bash
# Add Isovalent Helm repository
helm repo add isovalent https://helm.isovalent.com

# Add Splunk OpenTelemetry Collector Helm repository
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart

# Update Helm repositories
helm repo update
```

### Step 2: Create EKS Cluster Configuration

Create a cluster configuration file that disables the default AWS VPC CNI, as Cilium will provide the CNI functionality.

Create `cluster.yaml`:

```yaml
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
```

**Key Configuration Details:**
- `disableDefaultAddons: true` - Disables AWS VPC CNI and kube-proxy (Cilium will replace both)
- `withOIDC: true` - Enables IAM roles for service accounts (required for Cilium to manage ENIs)
- `coredns` addon is retained as it's needed for DNS resolution

**Why this matters:** Cilium provides its own CNI implementation using eBPF, which is more performant than the default AWS VPC CNI. By disabling the defaults, we avoid conflicts and let Cilium handle all networking.

### Step 3: Create the EKS Cluster

Create the cluster (this takes approximately 15-20 minutes):

```bash
eksctl create cluster -f cluster.yaml
```

Verify the cluster is created:

```bash
aws eks update-kubeconfig --name isovalent-demo --region us-east-1
kubectl get pods -n kube-system
```

**Expected Output:**
- CoreDNS pods will be in `Pending` state (normal - waiting for CNI)
- No worker nodes yet

**What's happening:** Without a CNI plugin, pods cannot get IP addresses or network connectivity. CoreDNS will remain pending until Cilium is installed to provide networking.

### Step 4: Get Kubernetes API Server Endpoint

You'll need this for the Cilium configuration:

```bash
aws eks describe-cluster --name isovalent-demo --region us-east-1 --query 'cluster.endpoint' --output text
```

Save this endpoint - you'll use it in the next step.

### Step 5: Install Prometheus CRDs

Cilium uses Prometheus ServiceMonitor CRDs for metrics:

```bash
kubectl apply -f https://github.com/prometheus-operator/prometheus-operator/releases/download/v0.68.0/stripped-down-crds.yaml
```

### Step 6: Configure Cilium Enterprise

Create `cilium-enterprise-values.yaml` with your specific configuration:

```yaml
# Enable/disable debug logging
debug:
  enabled: false
  verbose: ~

# Configure unique cluster name & ID
cluster:
  name: isovalent-demo
  id: 0

# Configure ENI specifics
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

# BPF / KubeProxyReplacement
kubeProxyReplacement: "true"
k8sServiceHost: <YOUR-EKS-API-SERVER-ENDPOINT>
k8sServicePort: 443

# Configure TLS configuration in the agent.
tls:
  ca:
    certValidityDuration: 3650 # 10 years

# Enable Cilium Hubble to gain visibility
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
      certValidityDuration: 1095 # 3 years
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

# Enable Cilium Operator metrics
operator:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true

# Enable Cilium Agent metrics
prometheus:
  enabled: true
  serviceMonitor:
    enabled: true

# Configure Cilium Envoy options.
envoy:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true

# Enable Cilium agent's support for Cilium DNS Proxy HA
extraConfig:
  external-dns-proxy: "true"

enterprise:
  featureGate:
    approved:
      - DNSProxyHA
      - HubbleTimescape
```

**Important:** Replace `<YOUR-EKS-API-SERVER-ENDPOINT>` with the actual endpoint from Step 4 (without `https://` prefix).

**Understanding the Configuration:**

**ENI Mode** (`eni.enabled: true`): Cilium manages AWS Elastic Network Interfaces directly, giving each pod a native VPC IP address. This eliminates overlay networking overhead and integrates seamlessly with AWS networking.

**Kube-Proxy Replacement** (`kubeProxyReplacement: "true"`): Cilium's eBPF programs handle service load balancing directly in the kernel, eliminating the need for iptables rules that kube-proxy creates. This provides better performance and observability.

**Hubble**: Network observability layer built into Cilium. It captures all network flows using eBPF and provides visibility into L3-L7 traffic, including HTTP, DNS, and TCP metrics.

**Timescape**: Extends Hubble to store historical flow data, enabling time-travel debugging of network issues.

### Step 7: Install Cilium Enterprise

Install Cilium using Helm:

```bash
helm install cilium isovalent/cilium --version 1.18.4 \
  --namespace kube-system -f cilium-enterprise-values.yaml
```

**Note:** The installation may initially fail waiting for nodes. This is expected - proceed to the next step.

**What's happening:** Cilium's Helm chart includes a job that generates TLS certificates for Hubble. This job needs a node to run on. Once we add nodes in the next step, the installation will complete automatically.

### Step 8: Create Node Group

Create `nodegroup.yaml`:

```yaml
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
```

Create the node group:

```bash
eksctl create nodegroup -f nodegroup.yaml
```

This will take 5-10 minutes. Once complete, verify nodes and Cilium:

```bash
# Check nodes
kubectl get nodes

# Check Cilium pods
kubectl get pods -n kube-system -l k8s-app=cilium

# Check all Cilium components
kubectl get pods -n kube-system | grep -E "(cilium|hubble)"
```

**Expected Output:**
- 2 nodes in `Ready` state
- Cilium pods running (1 per node)
- Hubble relay and timescape running
- Cilium operator running

**Component Roles:**
- **Cilium Agent** (DaemonSet): Runs on every node, manages networking and security using eBPF programs loaded into the kernel
- **Cilium Operator** (Deployment): Cluster-wide operations like managing identities and CEPs (Cilium Endpoints)
- **Hubble Relay** (Deployment): Aggregates network flow data from all Cilium agents for cluster-wide visibility
- **Hubble Timescape** (StatefulSet): Stores historical network flows in a time-series database

### Step 9: Install Tetragon Enterprise

**What is Tetragon?** Runtime security and observability tool that uses eBPF to monitor kernel-level events like process execution, file access, and network connections. Unlike traditional security tools, it operates at the kernel level with minimal overhead.

Install Tetragon for runtime security:

```bash
helm install tetragon isovalent/tetragon --version 1.18.0 \
  --namespace tetragon --create-namespace
```

Verify installation:

```bash
kubectl get pods -n tetragon
```

**What you'll see:** Tetragon runs as a DaemonSet (one pod per node) plus an operator. Each agent loads eBPF programs to trace system calls, process execution, and file operations without requiring kernel modules.

### Step 10: Install Cilium DNS Proxy HA

**Why DNS Proxy HA?** FQDN-based network policies (e.g., allowing traffic to `api.github.com`) require DNS inspection. The HA proxy ensures policies continue working during Cilium upgrades by running as a separate deployment.

Create `cilium-dns-proxy-ha-values.yaml`:

```yaml
enableCriticalPriorityClass: true
metrics:
  serviceMonitor:
    enabled: true
```

Install DNS Proxy HA:

```bash
helm upgrade -i cilium-dnsproxy isovalent/cilium-dnsproxy --version 1.16.7 \
  -n kube-system -f cilium-dns-proxy-ha-values.yaml
```

Verify:

```bash
kubectl rollout status -n kube-system ds/cilium-dnsproxy --watch
```

### Step 11: Configure Splunk OpenTelemetry Collector

**Integration Overview:** The Splunk OTel Collector uses Prometheus receivers to scrape metrics from Cilium, Hubble, and Tetragon. Each component exposes metrics on different ports, so we configure separate receivers with Kubernetes service discovery to automatically find pods.

**Why separate receivers?** Isovalent components expose metrics on multiple ports within the same pod (e.g., Cilium agent serves both Cilium and Hubble metrics on different ports). Standard Prometheus annotations only support one port per pod, so we explicitly configure each endpoint.

Create `splunk-otel-isovalent.yaml` with your Splunk credentials:

```yaml
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
              replacement: ${__meta_kubernetes_pod_ip}:9962
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
              replacement: ${__meta_kubernetes_pod_ip}:9965
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
              replacement: ${__meta_kubernetes_pod_ip}:9964
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
              replacement: ${__meta_kubernetes_pod_ip}:2112
            - target_label: job
              replacement: 'tetragon_metrics_2112'
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
autodetect:
  prometheus: true
clusterName: isovalent-demo
splunkObservability:
  accessToken: <YOUR-SPLUNK-ACCESS-TOKEN>
  realm: <YOUR-SPLUNK-REALM>
```

**Important:** Replace:
- `<YOUR-SPLUNK-ACCESS-TOKEN>` with your actual Splunk Observability Cloud access token
- `<YOUR-SPLUNK-REALM>` with your realm (e.g., us1, us2, eu0)

### Step 12: Install Splunk OpenTelemetry Collector

Install the collector:

```bash
helm upgrade --install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  -n otel-splunk --create-namespace \
  -f splunk-otel-isovalent.yaml
```

Wait for rollout to complete:

```bash
kubectl rollout status daemonset/splunk-otel-collector-agent -n otel-splunk --timeout=60s
```

## Verification

### Verify All Components

Run this comprehensive check:

```bash
echo "=== Cluster Nodes ==="
kubectl get nodes

echo -e "\n=== Cilium Components ==="
kubectl get pods -n kube-system -l k8s-app=cilium

echo -e "\n=== Hubble Components ==="
kubectl get pods -n kube-system | grep hubble

echo -e "\n=== Tetragon ==="
kubectl get pods -n tetragon

echo -e "\n=== Splunk OTel Collector ==="
kubectl get pods -n otel-splunk
```

### Verify Metrics Endpoints

Test that metrics are accessible:

```bash
# Test Cilium metrics
kubectl exec -n kube-system ds/cilium -- curl -s localhost:9962/metrics | head -20

# Test Hubble metrics
kubectl exec -n kube-system ds/cilium -- curl -s localhost:9965/metrics | head -20

# Test Tetragon metrics
kubectl exec -n tetragon ds/tetragon -- curl -s localhost:2112/metrics | head -20
```

### Verify Metrics Collection

Check that the Splunk OTel Collector is scraping metrics:

```bash
kubectl logs -n otel-splunk -l app=splunk-otel-collector,component=otel-collector-agent --tail=100 | grep -i "cilium\|hubble\|tetragon"
```

You should see log entries indicating successful scraping of each component.

**What to look for:** Log entries showing "Scrape manager started" for each Prometheus receiver, confirming the collector discovered and is scraping metrics from Cilium, Hubble, Envoy, and Tetragon.

### Verify in Splunk Observability Cloud

1. Log in to your Splunk Observability Cloud account
2. Navigate to **Infrastructure** → **Kubernetes**
3. Find your cluster: `isovalent-demo`
4. Verify metrics are flowing:
   - Cilium metrics (prefix: `cilium_`)
   - Hubble metrics (prefix: `hubble_`)
   - Tetragon metrics (prefix: `tetragon_`)

## Import Dashboards to Splunk Observability Cloud

Pre-built dashboards are included in the `examples/` directory to help you visualize Cilium, Hubble, and Tetragon metrics.

### Available Dashboards

1. **Cilium by Isovalent** - Monitors Cilium agent health, ENI allocation, BPF map pressure, and operator status
2. **Hubble by Isovalent** - Visualizes network flows, DNS queries, dropped packets, and HTTP metrics

### Import Process

**Step 1:** Navigate to Dashboards
1. Log in to Splunk Observability Cloud
2. Click on **Dashboards** in the left navigation
3. Click the **Create** button (top right)
4. Select **Import** from the dropdown

**Step 2:** Upload Dashboard JSON
1. Click **Choose File** or drag and drop
2. Select one of the dashboard JSON files:
   - `examples/Cilium by Isovalent.json`
   - `examples/Hubble by Isovalent.json`
3. Click **Import**

**Step 3:** Configure Dashboard Group (Optional)
1. After import, the dashboard opens automatically
2. Click the **Dashboard Info** icon (ⓘ) in the top right
3. Click **Move to Dashboard Group**
4. Select an existing group or create a new one (e.g., "Isovalent")

**Step 4:** Repeat for Other Dashboards
Repeat steps 1-3 for each dashboard JSON file.

### Dashboard Details

#### Cilium by Isovalent Dashboard

This dashboard provides visibility into Cilium's core networking and security components:

**Charts included:**
- **Agent Status** - Running vs not running Cilium agents
- **Agent Restarts** - Tracks Cilium agent restart events
- **Envoy Restarts** - Tracks Cilium Envoy proxy restarts
- **DNS Proxy Status** - High-availability DNS proxy health
- **ENI Allocation** - AWS ENI and IP address usage per node
- **BPF Map Pressure** - eBPF map memory utilization
- **Endpoint Count** - Number of managed endpoints (pods)
- **Identity Count** - Security identity allocation
- **Policy Operations** - Network policy enforcement rate
- **Datapath Latency** - Packet processing latency in the datapath

**Use cases:**
- Monitor overall Cilium health
- Track ENI capacity and scaling
- Identify eBPF map resource constraints
- Observe network policy performance

#### Hubble by Isovalent Dashboard

This dashboard provides deep network observability:

**Charts included:**
- **DNS Queries** - Total DNS query rate by source
- **Top 10 DNS Queries** - Most frequently queried domains
- **Dropped Flows** - Packet drops by reason (policy, invalid, error)
- **TCP Connections** - TCP flow tracking by namespace
- **HTTP Requests** - L7 HTTP request rate and status codes
- **Network Flows** - Overall flow volume by source/destination
- **Flow Processing Rate** - Hubble's flow processing throughput
- **Top Talkers** - Workloads generating most network traffic

**Use cases:**
- Investigate network connectivity issues
- Analyze DNS resolution patterns
- Debug policy denials
- Monitor application-level (L7) traffic
- Identify unusual traffic patterns

### Customizing Dashboards

After import, you can customize dashboards:

1. **Edit Chart Time Range**: Click on any chart → **Chart Options** → **Time**
2. **Add Filters**: Use dashboard variables to filter by cluster, namespace, or pod
3. **Clone Charts**: Right-click any chart → **Copy** to duplicate and modify
4. **Add New Charts**: Click **+** button to add custom SignalFlow queries

### Troubleshooting Dashboard Import

**No data showing in charts:**
- Wait 2-3 minutes after OTel Collector installation for initial metrics ingestion
- Verify metrics are flowing (see "Verify Metrics Collection" section above)
- Check that your cluster name matches the filter in chart queries

**Chart shows "No Data":**
- Edit the chart and check the SignalFlow query
- Verify the metric name exists: Go to **Metrics Finder** and search for the metric (e.g., `cilium_endpoint_count`)
- Adjust time range to last 15 minutes or 1 hour

**Import fails:**
- Ensure you're using the correct JSON files from the `examples/` directory
- Check that your Splunk Observability Cloud account has dashboard creation permissions

## Understanding the Architecture

### Cilium ENI Mode

Cilium is configured in ENI (Elastic Network Interface) mode for AWS:

**How it works:** Instead of creating a virtual overlay network, Cilium uses AWS ENIs to assign VPC IP addresses directly to pods. Each node gets multiple ENIs, and with prefix delegation enabled, each ENI can allocate a /28 CIDR block (16 IPs) instead of individual IPs.

- **Benefits:**
  - Higher performance (no overlay encapsulation)
  - Native AWS networking (pods get real VPC IPs)
  - No NAT for pod-to-pod communication
  - Supports prefix delegation for more IPs per node (up to 110 pods/node on m5.xlarge)
  - Full visibility in AWS VPC Flow Logs

- **Configuration:**
  - `eni.enabled: true` - Enable ENI mode
  - `ipam.mode: eni` - Use ENI-based IP allocation
  - `routingMode: native` - Use native VPC routing (no tunnels)
  - `enableIPv4Masquerade: false` - Pods use their VPC IPs directly

### Kube-Proxy Replacement

Cilium replaces kube-proxy using eBPF:

**How it works:** Traditional kube-proxy uses iptables rules (thousands of them in large clusters) to implement Kubernetes services. Cilium instead uses eBPF programs attached to network interfaces that perform load balancing in-kernel with hash tables—much more efficient.

- **Benefits:**
  - Better performance (no iptables linear rule processing)
  - Lower latency (kernel-level load balancing)
  - Full IPv6 support and DSR (Direct Server Return)
  - Service topology awareness (prefer same-zone backends)
  - Maglev consistent hashing for connection affinity
  - Required for advanced features (Gateway API, etc.)
  - Better observability with Hubble (can see service→pod traffic)

- **Configuration:**
  - `kubeProxyReplacement: "true"` - Enable feature
  - Must specify API server endpoint (Cilium needs direct API access since kube-proxy isn't doing it)

### Metrics Pipeline

The metrics flow follows this path:

```
Cilium/Hubble/Tetragon
    ↓ (expose metrics on ports)
Prometheus Receivers in OTel Collector
    ↓ (scrape via Kubernetes service discovery)
OTel Collector Processing Pipeline
    ↓ (process & batch)
Splunk Observability Cloud
```

### Key Metrics to Monitor

**Cilium Metrics (port 9962):**
- `cilium_datapath_conntrack_gc_*` - Connection tracking and cleanup (important for connection lifecycle)
- `cilium_endpoint_*` - Endpoint management (tracks pod network state)
- `cilium_policy_*` - Network policy enforcement (policy verdict stats)
- `cilium_bpf_map_*` - eBPF map statistics (kernel map memory usage)
- `cilium_identity_*` - Security identity allocation (labels→identity mapping)

**Hubble Metrics (port 9965):**
- `hubble_flows_processed_total` - Flow processing rate (network activity volume)
- `hubble_drop_total` - Dropped packets by reason (policy denies, invalid packets)
- `hubble_tcp_flags_total` - TCP connection states (SYN, FIN, RST tracking)
- `hubble_dns_*` - DNS query statistics (FQDN policy insights)
- `hubble_http_*` - HTTP request/response metrics (L7 visibility)

**Tetragon Metrics (port 2112):**
- `tetragon_process_*` - Process execution events (exec tracking)
- `tetragon_syscalls_*` - System call monitoring (kernel call activity)
- `tetragon_policy_events_*` - Security policy enforcement actions
- `tetragon_event_cache_*` - Event cache statistics (buffering performance)

## Troubleshooting

### Cilium Pods Not Starting

```bash
# Check Cilium status
kubectl exec -n kube-system ds/cilium -- cilium status

# Check logs
kubectl logs -n kube-system ds/cilium --tail=100
```

### Metrics Not Appearing in Splunk

1. Verify OTel Collector configuration:
```bash
kubectl get configmap -n otel-splunk splunk-otel-collector-otel-agent -o yaml | grep -A 5 "prometheus/isovalent"
```

2. Check OTel Collector logs:
```bash
kubectl logs -n otel-splunk -l app=splunk-otel-collector --tail=100
```

3. Verify network connectivity:
```bash
kubectl exec -n otel-splunk ds/splunk-otel-collector-agent -- curl -s http://cilium-agent.kube-system:9962/metrics | head -20
```

### Node Not Ready

If nodes remain in `NotReady` state:

1. Check if Cilium is running on the node
2. Verify ENI limits haven't been exceeded
3. Check AWS IAM permissions for ENI management

## Cleanup

To delete all resources:

```bash
# Delete the node group
eksctl delete nodegroup --cluster=isovalent-demo --name=standard --region=us-east-1

# Delete the cluster
eksctl delete cluster --name=isovalent-demo --region=us-east-1
```

**Note:** This will delete all AWS resources including VPC, subnets, and security groups.

## Additional Resources

- [Cilium Documentation](https://docs.cilium.io/)
- [Isovalent Enterprise Documentation](https://docs.isovalent.com/)
- [Hubble Documentation](https://docs.cilium.io/en/stable/observability/hubble/)
- [Tetragon Documentation](https://tetragon.io/)
- [Splunk OpenTelemetry Collector Documentation](https://docs.splunk.com/Observability/gdi/opentelemetry/opentelemetry.html)

## Support

For issues or questions:
- Isovalent Support: [Isovalent Support Portal](https://support.isovalent.com/)
- Splunk Support: [Splunk Support](https://www.splunk.com/en_us/support-and-services.html)

## License

This lab guide is provided for educational purposes.

---

**Lab Guide Version:** 1.0  
**Last Updated:** November 2025  
**Tested With:**
- EKS 1.30
- Cilium Enterprise 1.18.4
- Tetragon 1.18.0
- Splunk OpenTelemetry Collector 0.140.0
