# Kubernetes Path

## Platform Split

Use this path for:

- Amazon EKS.
- Standard Kubernetes clusters that are not OpenShift.

Within this branch, split again:

- If the target is EKS, reuse the repo's bootstrap files and AWS-specific values.
- If the target is generic Kubernetes, keep the Isovalent logic but remove AWS-only settings.

## Discovery

Before changing anything, check:

- `helm repo update`
- `kubectl version`
- `kubectl get ns`
- `helm list -A`
- `helm status cilium -n kube-system`
- `helm status cilium-dnsproxy -n kube-system`
- `helm status tetragon -n tetragon`
- `helm get values cilium -n kube-system -o yaml`
- `helm get values cilium -n kube-system -a -o yaml`
- `helm get values cilium-dnsproxy -n kube-system -o yaml`
- `helm search repo isovalent/cilium --versions | head -n 3`
- `helm search repo isovalent/cilium-dnsproxy --versions | head -n 3`
- `helm search repo isovalent/tetragon --versions | head -n 3`
- `kubectl get pods,ds,deploy,svc -n kube-system`
- `kubectl get pods,ds,deploy,svc -n tetragon`
- `kubectl get crd | egrep 'ciliumnetworkpolicies|servicemonitors'`
- `kubectl get servicemonitor -n kube-system`

If Cilium or Tetragon already exist, prefer `helm upgrade` over reinstall, but do not blindly use `--reuse-values` when the goal is to move to the latest published Isovalent charts.
If the repo example values still match the live user-supplied values, reapply the example files directly and inject the live `k8sServiceHost` for EKS.
If older docs disagree about DNS proxy naming or versions, trust the live release state first and align the chart version to the running Cilium version.
If the user wants the latest versions, resolve them from `helm search repo` at runtime before upgrading instead of pinning old versions in commands.
If the chart revision advanced but the pod images did not, inspect `helm get values ... -a` and rendered manifests for stale computed image tags left behind by a previous `--reuse-values` upgrade.
Do not assume every subcomponent image numerically matches the chart version. Hubble Timescape can intentionally be pinned to a different tag in the selected Cilium chart.
After the upgrade, verify the live container images directly from the workloads. Do not stop at `helm list` or `helm status`.

## EKS Workflow

For EKS, reuse the repo artifacts directly:

- `examples/cluster.yaml`
- `examples/nodegroup.yaml`
- `examples/cilium-enterprise-values.yaml`
- `examples/tetragon-network-values.yaml`
- `examples/cilium-dns-proxy-ha-values.yaml`

Key EKS-only settings to preserve:

- `eni.enabled: true`
- `ipam.mode: eni`
- `routingMode: native`
- `kubeProxyReplacement: "true"`
- `k8sServiceHost` and `k8sServicePort`
- `distribution: eks`
- `cloudProvider: aws`

## Generic Kubernetes Adaptation

If the cluster is not EKS:

- Do not reuse `examples/cluster.yaml` or `examples/nodegroup.yaml`.
- Remove or replace AWS-specific Cilium settings:
  - `eni.*`
  - `ipam.mode: eni`
  - `k8sServiceHost`
  - `k8sServicePort`
  - Any assumption that Cilium manages AWS ENIs.
- Keep the Hubble, Envoy, operator, and ServiceMonitor settings only if the target Cilium packaging supports them.
- Do not carry over `distribution: eks` or `cloudProvider: aws` unless the target platform explicitly matches them.

For a generic cluster, the safest move is usually:

1. Discover how Cilium is already installed.
2. Apply only the Isovalent values that are portable.
3. Preserve the observability ports and labels that the repo expects whenever the packaging allows it.

## Tetragon

The repo expects Tetragon network observability to be enabled via `examples/tetragon-network-values.yaml`.

When enabling or tuning it:

- Keep `enableNetworkEvents: true`.
- Keep the Prometheus metrics settings.
- Keep the export denylist intent, but update namespaces only if the deployment layout changed.
- Verify that the namespace filter still allows the workload namespaces you care about.

## DNS Proxy HA

When touching the DNS proxy chart:

- Use release name `cilium-dnsproxy` unless the live cluster proves otherwise.
- Keep the deployment aligned with the Cilium chart version you are upgrading to.
- Validate service name `cilium-dnsproxy`, service port `9967`, and ServiceMonitor presence before assuming the example docs are current.

## Rollout Caveats

During Cilium upgrades:

- `hubble-relay` can briefly report `NOT_SERVING` or log connection refusals to `hubble-peer` while the Cilium agents restart and Hubble cert jobs finish.
- Let `helm --wait` and the Hubble certificate job or cronjob settle before treating relay unready state as a failed upgrade.
- Re-check `hubble-relay` and `hubble-timescape` after the agent DaemonSet is healthy. Agent readiness alone does not prove the full release converged.

## Validation

Validate with:

- `helm status cilium -n kube-system`
- `helm status cilium-dnsproxy -n kube-system`
- `helm status tetragon -n tetragon`
- `kubectl get pods,ds,deploy,svc -n kube-system`
- `kubectl get pods,ds,deploy,svc -n tetragon`
- `kubectl get ds cilium -n kube-system -o jsonpath='{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}'`
- `kubectl get ds cilium-dnsproxy -n kube-system -o jsonpath='{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}'`
- `kubectl get deploy cilium-operator hubble-relay -n kube-system -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}{end}'`
- `kubectl get sts hubble-timescape -n kube-system -o jsonpath='{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}'`
- `kubectl get servicemonitor -n kube-system`
- `kubectl logs -n kube-system deploy/hubble-relay --tail=100`
- `kubectl exec -n kube-system ds/cilium -- curl -s localhost:9962/metrics | head`
- `kubectl exec -n kube-system ds/cilium -- curl -s localhost:9965/metrics | head`
- `kubectl exec -n tetragon ds/tetragon -- curl -s localhost:2112/metrics | head`

If the repo's expected namespaces or labels do not match the running cluster, keep the Isovalent install consistent first and then hand off selector updates to `deploy-splunk-o11y-lab`.
