# Repo Map

## Files To Reuse

- `README.md`: End-to-end lab narrative, currently EKS-first.
- `QUICK_REFERENCE.md`: Short command-first summary of the EKS workflow.
- `ARCHITECTURE.md`: Component model, ports, and data flow.
- `examples/cluster.yaml`: EKS bootstrap file.
- `examples/nodegroup.yaml`: EKS node group file.
- `examples/cilium-enterprise-values.yaml`: Cilium Enterprise, Hubble, Envoy, operator, and Timescape values for EKS.
- `examples/tetragon-network-values.yaml`: Tetragon network observability values.
- `examples/cilium-dns-proxy-ha-values.yaml`: DNS proxy HA values.

## Chart-Managed Runtime Shape

When this repo is installed through Helm, inventory the live release layout before touching values:

- Helm release `cilium` in namespace `kube-system`
- Helm release `cilium-dnsproxy` in namespace `kube-system`
- Helm release `tetragon` in namespace `tetragon`
- `DaemonSet/cilium` and `DaemonSet/cilium-envoy`
- `Deployment/cilium-operator`, `Deployment/hubble-relay`, and `StatefulSet/hubble-timescape`
- Namespace `cilium-secrets` plus Hubble certificate jobs or cronjobs
- `DaemonSet/cilium-dnsproxy`
- `DaemonSet/tetragon` plus `Deployment/tetragon-operator`
- ServiceMonitors for Cilium agent, Envoy, operator, Hubble, Hubble Relay, and DNS proxy

## Metrics Endpoints Exposed By The Isovalent Stack

| Component | Expected Label Selector | Port |
| --- | --- | --- |
| Cilium agent | `k8s_app=cilium` | `9962` |
| Hubble metrics on Cilium pods | `k8s_app=cilium` | `9965` |
| Cilium Envoy | `k8s_app=cilium-envoy` | `9964` |
| Cilium operator | `io_cilium_app=operator` | `9963` |
| Tetragon | `app_kubernetes_io_name=tetragon` | `2112` |

When the platform or packaging changes these labels, keep the metrics endpoints but update the downstream collector relabel rules through `deploy-splunk-o11y-lab`.

## Current Repo Assumptions

- Cilium Enterprise runs in `kube-system`.
- Cilium Enterprise is installed as Helm release `cilium`, with Hubble Relay and Hubble Timescape enabled.
- DNS proxy HA is installed as separate Helm release `cilium-dnsproxy` in `kube-system`.
- Tetragon runs in namespace `tetragon`.
- The repo expects Hubble, Envoy, and operator metrics to stay enabled.

## Important Repo Inconsistencies

- Older revisions of this repo mixed DNS proxy chart names and versions. Prefer the live `cilium-dnsproxy` release name and keep its version aligned with Cilium.
- Tetragon is installed into namespace `tetragon` in this repo, while upstream Tetragon docs often show `kube-system`.
- Enterprise features can appear under the standard `cilium` release name. Verify Hubble Timescape and enterprise cluster roles before assuming this is an OSS-only install.
- A previous `--reuse-values` upgrade can preserve old computed image tags for `cilium` or `cilium-dnsproxy` even after the chart revision changes. If runtime images lag, inspect `helm get values -a` and reapply explicit values.
- Do not assume every subcomponent image tag matches the chart version. Hubble Timescape can intentionally use a separate tag inside the selected Cilium chart.

Resolve these before acting. Default to the user's stated intent and the values files already present in `examples/`.

## Placeholders That Must Be Replaced

- `examples/cilium-enterprise-values.yaml`
  - `k8sServiceHost: <YOUR-EKS-API-SERVER-ENDPOINT>`
  - Prefer injecting the live endpoint at install or upgrade time if you want to keep the repo file unchanged.

## Boundary With The O11y Skill

Use `deploy-splunk-o11y-lab` when the task changes:

- `examples/splunk-otel-isovalent.yaml`
- Dashboard JSON imports
- Collector or Operator settings
- Auto-instrumentation resources or annotations
