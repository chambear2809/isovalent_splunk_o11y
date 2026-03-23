# Configuration Examples

This directory contains the configuration files used during the deployment of Isovalent Enterprise Platform with Splunk Observability Cloud integration.

## Files Overview

### EKS Cluster Configuration
- **cluster.yaml** - Initial EKS cluster configuration
- **nodegroup.yaml** - Node group configuration

### Cilium Enterprise Configuration
- **cilium-enterprise-values.yaml** - Main Cilium Enterprise Helm values
- **cilium-dns-proxy-ha-values.yaml** - DNS Proxy HA Helm values

### Splunk OpenTelemetry Configuration
- **splunk-otel-isovalent.yaml** - Splunk OpenTelemetry Collector Helm values with Isovalent metrics receivers and metric filtering

### Splunk Observability Cloud Dashboards
- **Cilium by Isovalent.json** - Pre-built dashboard for Cilium metrics (agent status, ENI allocation, BPF map pressure)
- **Hubble by Isovalent.json** - Pre-built dashboard for Hubble metrics (network flows, DNS queries, dropped packets)

## Required Placeholders

Before using these configuration files, you **must** replace the following placeholders with your actual values:

### 1. EKS API Server Endpoint
**File:** `cilium-enterprise-values.yaml`  
**Placeholder:** `<YOUR-EKS-API-SERVER-ENDPOINT>`  
**Location:** Line 28 (`k8sServiceHost`)

**How to get it:**
```bash
kubectl cluster-info | grep 'Kubernetes control plane' | awk '{print $NF}' | sed 's|https://||'
```

You can either replace the placeholder in the file or keep the repo copy unchanged and pass the endpoint at install time with `--set k8sServiceHost="${EKS_API_ENDPOINT}"`.

**Example value:**
```
79F5FA6349FF9D1DC9052A3140032E7A.gr7.us-east-1.eks.amazonaws.com
```

### 2. Splunk Access Token
**File:** `splunk-otel-isovalent.yaml`  
**Placeholder:** `<YOUR-SPLUNK-ACCESS-TOKEN>`  
**Field:** `splunkObservability.accessToken`

**How to get it:**
1. Log into Splunk Observability Cloud
2. Navigate to **Settings** > **Access Tokens**
3. Create a new token with **INGEST** permissions or use an existing one

**Security note:** Keep this token secure. Do not commit it to version control.

### 3. Splunk Realm
**File:** `splunk-otel-isovalent.yaml`  
**Placeholder:** `<YOUR-SPLUNK-REALM>`  
**Field:** `splunkObservability.realm`

**How to find it:**
1. Log into Splunk Observability Cloud
2. Navigate to **Settings** > **Account**
3. Your realm is displayed (e.g., `us0`, `us1`, `eu0`, `ap0`)

**Common realms:**
- `us0` - US East (N. Virginia)
- `us1` - US East (Ohio)
- `eu0` - Europe (Frankfurt)
- `ap0` - Asia Pacific (Tokyo)

## Usage

After replacing the placeholders, use these files with the commands documented in the main [README.md](../README.md):

```bash
# Refresh repos and resolve the latest chart versions from the official Helm repos
helm repo update
export CILIUM_CHART_VERSION="$(helm search repo isovalent/cilium --versions | awk 'NR==2 {print $2}')"
export CILIUM_DNSPROXY_CHART_VERSION="$(helm search repo isovalent/cilium-dnsproxy --versions | awk 'NR==2 {print $2}')"
export TETRAGON_CHART_VERSION="$(helm search repo isovalent/tetragon --versions | awk 'NR==2 {print $2}')"
export SPLUNK_OTEL_CHART_VERSION="$(helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | awk 'NR==2 {print $2}')"

# Create EKS cluster
eksctl create cluster -f examples/cluster.yaml

# Add node group
eksctl create nodegroup -f examples/nodegroup.yaml

export EKS_API_ENDPOINT="$(kubectl cluster-info | grep 'Kubernetes control plane' | awk '{print $NF}' | sed 's|https://||')"

# Install Cilium Enterprise
helm upgrade --install cilium isovalent/cilium \
  --version "${CILIUM_CHART_VERSION}" \
  --namespace kube-system \
  -f examples/cilium-enterprise-values.yaml \
  --set k8sServiceHost="${EKS_API_ENDPOINT}"

# Install DNS Proxy HA
helm upgrade --install cilium-dnsproxy isovalent/cilium-dnsproxy \
  --version "${CILIUM_DNSPROXY_CHART_VERSION}" \
  --namespace kube-system \
  -f examples/cilium-dns-proxy-ha-values.yaml

# Install Tetragon
helm upgrade --install tetragon isovalent/tetragon \
  --version "${TETRAGON_CHART_VERSION}" \
  --namespace tetragon --create-namespace

# Install Splunk OpenTelemetry Collector
helm upgrade --install splunk-otel-collector splunk-otel-collector-chart/splunk-otel-collector \
  --version "${SPLUNK_OTEL_CHART_VERSION}" \
  --namespace otel-splunk \
  --create-namespace \
  -f examples/splunk-otel-isovalent.yaml
```

**Note:** `cilium-dns-proxy-ha-values.yaml` is the values file name used in this repo, but the live Helm release and chart name are `cilium-dnsproxy`.
**Upgrade note:** Avoid `--reuse-values` for `cilium` and `cilium-dnsproxy` when updating to a newer chart version. Reapply the repo values files so the live images move with the chart instead of staying pinned to older computed tags.
**Splunk upgrade note:** On an existing `splunk-otel-collector` release, start from `helm get values splunk-otel-collector -n otel-splunk -o yaml` and merge the repo's receiver and filter settings into that file before upgrading. Do not blindly reuse `examples/splunk-otel-isovalent.yaml` over live cluster-specific values.

## Current Runtime Shape

Current cluster inventory observed on March 22, 2026:

- `cilium` `1.18.8` in `kube-system`, with Cilium agents, Envoy, operator, Hubble Relay, Hubble Timescape, ServiceMonitors, and namespace `cilium-secrets`
- `cilium-dnsproxy` `1.18.8` in `kube-system`, exposed on `9967/TCP`
- `tetragon` `1.18.1` in `tetragon`, with daemonset, operator, and `TracingPolicy/l3l4networking`
- `splunk-otel-collector` `0.147.1` in `otel-splunk`, with gateway deployment, agent daemonset, `k8s-cluster-receiver`, operator, cert-manager, `splunk-otel-collector-obi`, ConfigMaps, and separately applied `Instrumentation` resources in app namespaces

`kubectl get opentelemetrycollectors -A` may still return no resources because the Splunk collector is chart-managed here rather than deployed through `OpenTelemetryCollector` custom resources.

Helm can expose `instrumentation.spec` defaults without rendering or owning live `Instrumentation` resources. Prove ownership with `helm get manifest splunk-otel-collector -n otel-splunk` plus the live object metadata before reconciling any `Instrumentation` CRs.

If `helm status splunk-otel-collector -n otel-splunk` reports `failed` while the workloads are still healthy, inspect the operator webhook and cert-manager resources before reinstalling. A failed upgrade can leave the previous collector stack running.

## Metric Filtering

The `splunk-otel-isovalent.yaml` file includes a `filter/includemetrics` processor that limits which metrics are sent to Splunk Observability Cloud. This processor uses **strict include semantics**: only metrics explicitly listed in `metric_names` are forwarded; all other metrics are dropped. This is essential to:

- **Prevent metric explosion**: Cilium, Hubble, and Tetragon can generate hundreds of metrics
- **Control costs**: Splunk charges based on metrics volume (MTS - Metric Time Series)
- **Focus on key indicators**: Only send metrics that provide actionable insights

**Default filtered metrics include:**
- Container and pod resource metrics (CPU, memory, restarts)
- Cilium networking metrics (endpoints, BPF maps, policies, API limiter)
- Hubble observability metrics (flows, DNS, HTTP, drops)
- Tetragon security metrics (processes, HTTP, DNS, sockets)

**Customizing the filter:**
Edit the `metric_names` list under `processors.filter/includemetrics` to add or remove metrics based on your monitoring requirements. Use `kubectl exec` to view available metrics:

```bash
# View all Cilium metrics
kubectl exec -n kube-system ds/cilium -- curl -s localhost:9962/metrics | grep "^cilium_"

# View all Hubble metrics
kubectl exec -n kube-system ds/cilium -- curl -s localhost:9965/metrics | grep "^hubble_"

# View all Tetragon metrics
kubectl get --raw '/api/v1/namespaces/tetragon/services/http:tetragon:metrics/proxy/metrics' | grep "^tetragon_"
```

## Customization

Feel free to modify these files to match your environment:

- Change cluster name and region in `cluster.yaml` and `nodegroup.yaml`
- Adjust instance types and capacity in `nodegroup.yaml`
- Modify Hubble metrics in `cilium-enterprise-values.yaml`
- Update cluster name and environment in `splunk-otel-isovalent.yaml` to match your deployment
- Customize the metric filter list in `splunk-otel-isovalent.yaml` based on your monitoring needs

## Security Best Practices

1. **Never commit sensitive values** to version control
2. Use **environment variables** or **secret management tools** (e.g., AWS Secrets Manager, HashiCorp Vault) for credentials
3. Rotate access tokens regularly
4. Use **principle of least privilege** for IAM roles and service accounts
5. Enable **audit logging** in both EKS and Splunk Observability Cloud
