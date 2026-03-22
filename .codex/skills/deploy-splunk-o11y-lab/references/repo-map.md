# Repo Map

## Files To Reuse

- `README.md`: End-to-end lab narrative, currently EKS-first.
- `ARCHITECTURE.md`: Component model, ports, and data flow.
- `examples/splunk-otel-isovalent.yaml`: Splunk OpenTelemetry Collector values with custom Isovalent receivers and strict metric filtering.
- `examples/Cilium by Isovalent.json`: Splunk dashboard for Cilium metrics.
- `examples/Hubble by Isovalent.json`: Splunk dashboard for Hubble metrics.

## Chart-Managed Runtime Shape

When this repo is installed through the Splunk Helm chart, expect the runtime footprint to be chart-managed instead of `OpenTelemetryCollector`-CR-managed.

Inventory these first:

- Helm release `splunk-otel-collector` in namespace `otel-splunk`.
- `Deployment/splunk-otel-collector` as the gateway / central collector service.
- `DaemonSet/splunk-otel-collector-agent` as the node-local collector.
- `DaemonSet/splunk-otel-collector-obi` on newer chart versions.
- `Deployment/splunk-otel-collector-k8s-cluster-receiver`.
- `Deployment/splunk-otel-collector-operator` plus webhook services.
- Cert-manager components created by the chart when `certmanager.enabled: true`.
- ConfigMaps `splunk-otel-collector-otel-agent`, `splunk-otel-collector-otel-collector`, and `splunk-otel-collector-otel-k8s-cluster-receiver`.
- One or more `Instrumentation` resources, even when `kubectl get opentelemetrycollectors -A` returns no resources.

## Metrics Endpoints Assumed By The Collector

| Component | Label Selector Used By Collector | Port |
| --- | --- | --- |
| Cilium agent | `k8s_app=cilium` | `9962` |
| Hubble metrics on Cilium pods | `k8s_app=cilium` | `9965` |
| Cilium Envoy | `k8s_app=cilium-envoy` | `9964` |
| Cilium operator | `io_cilium_app=operator` | `9963` |
| Tetragon | `app_kubernetes_io_name=tetragon` | `2112` |

When the platform or packaging changes these labels, update the relabel rules. Do not remove the selectors and scrape everything.

## Current Repo Assumptions

- Splunk OpenTelemetry Collector release name is `splunk-otel-collector` in namespace `otel-splunk`.
- Splunk collector uses `gateway.enabled: true`, `certmanager.enabled: true`, and `operator.enabled: true`.
- The collector config uses explicit Prometheus receivers plus `hostmetrics`, `kubeletstats`, and `otlp`.
- Auto-instrumentation can be attached at namespace or workload level, and annotation values can be same-namespace or cross-namespace references.
- Cilium Enterprise runs in `kube-system`, and Tetragon runs in `tetragon`.

## Important Repo Inconsistencies

- Tetragon is installed into namespace `tetragon` in this repo, while upstream Tetragon docs often show `kube-system`.
- The repo is EKS-first, so distribution flags in `examples/splunk-otel-isovalent.yaml` are not automatically portable.
- A Helm release can show `STATUS: failed` because of operator webhook or certificate errors while the existing collector pods and ConfigMaps still remain in service.
- The chart can install OTel CRDs and `Instrumentation` resources without creating any `OpenTelemetryCollector` resources.
- The chart version does not guarantee the collector, operator, or OBI image tags numerically match the chart. Validate against rendered manifests instead of assuming equality.
- Newer upgrades can fail on server-side apply ownership conflicts for webhook configurations. Confirm the chart-managed release should own those resources before retrying with `--force-conflicts`.
- Stale namespace-level instrumentation defaults can block pod admission even when workloads do not carry their own `instrumentation.opentelemetry.io/*` annotations.

Resolve these before acting. Default to the user's stated intent and the values files already present in `examples/`.

## Placeholders That Must Be Replaced

- `examples/splunk-otel-isovalent.yaml`
  - `splunkObservability.accessToken`
  - `splunkObservability.realm`
- Any imported dashboard filters that still point at an old cluster name.

## Boundary With The Isovalent Skill

Use `deploy-isovalent-lab` when the task changes:

- `examples/cilium-enterprise-values.yaml`
- `examples/tetragon-network-values.yaml`
- `examples/cilium-dns-proxy-ha-values.yaml`
- Cilium install, Tetragon install, or AWS ENI and IPAM behavior
