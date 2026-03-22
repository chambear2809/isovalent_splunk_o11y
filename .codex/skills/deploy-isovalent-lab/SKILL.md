---
name: deploy-isovalent-lab
description: Install, configure, validate, or adapt the Isovalent components in this repository for Kubernetes, Amazon EKS, or OpenShift. Use when Codex needs to work with Cilium Enterprise, Hubble, Tetragon, DNS proxy HA, platform-specific Helm values, or Kubernetes/OpenShift differences for the Isovalent stack.
---

# Deploy Isovalent Lab

Use this skill for the Isovalent side of the repo. If the task is primarily about the Splunk OpenTelemetry Collector, Operator, auto-instrumentation, metric filtering, or dashboard imports, use `deploy-splunk-o11y-lab`.

## Quick Start

1. Read `references/repo-map.md`.
2. Decide which platform path applies:
   - Read `references/kubernetes.md` for EKS or standard Kubernetes.
   - Read `references/openshift.md` for OpenShift.
3. Pull in the O11y skill separately if the task also changes collector selectors, dashboards, or Splunk distribution settings.

## Workflow

1. Establish scope.
   - Determine whether the task is cluster bootstrap, Cilium install, Hubble or Envoy tuning, Tetragon enablement, DNS proxy HA, validation, or troubleshooting.
   - Prefer discovery over reinstall when the user already has a cluster.
2. Inventory the cluster before changing anything.
   - Check namespaces, Helm releases and release status, installed CRDs, ServiceMonitors, and running Isovalent workloads.
   - Confirm whether the `cilium`, `cilium-dnsproxy`, and `tetragon` releases have created Cilium, Envoy, operator, Hubble Relay, Hubble Timescape, DNS proxy HA, and Tetragon operator resources before applying charts.
   - Refresh the Helm repos and compare installed chart versions to the latest official `isovalent/*` chart versions before deciding whether to upgrade.
   - If a previous upgrade may have used `--reuse-values`, inspect computed Helm values or rendered manifests for stale image tags before assuming the runtime moved with the chart revision.
   - Prefer the live release state over older doc names or versions when they disagree.
3. Reuse repo artifacts.
   - Treat `examples/` as the source of truth for Isovalent values and bootstrap files.
   - Treat the prose docs as operator guidance, not immutable truth, because the repo has a few command and version inconsistencies.
4. Apply the platform branch.
   - For Kubernetes or EKS, keep the repo's EKS workflow only when AWS is actually the target.
   - For generic Kubernetes, keep the observability-facing Isovalent values but strip AWS-only networking assumptions.
   - For OpenShift, follow the OpenShift-specific branch and do not reuse the EKS bootstrap files unchanged.
5. Validate the install.
   - Confirm pod rollouts, service exposure, ServiceMonitors, metrics ports, and any platform-specific constraints before handing off to O11y validation.

## Non-Negotiables

- Do not assume the EKS-specific values in `examples/cilium-enterprise-values.yaml` are portable to OpenShift or generic Kubernetes.
- Preserve Hubble, Envoy, operator, and Tetragon observability settings unless the platform or packaging makes them invalid.
- Resolve latest chart versions from the official Helm repos at runtime instead of trusting stale hard-coded pins.
- Keep the DNS proxy chart version aligned with the actual Cilium version in use.
- Preserve Hubble Relay, Hubble Timescape, and the separate `cilium-dnsproxy` release when they already exist.
- Do not default to `--reuse-values` for `cilium` or `cilium-dnsproxy` when upgrading to the latest chart versions. Reapply the intended values file or explicit live values so Helm does not preserve stale computed image tags.
- Do not assume every Isovalent subcomponent image tag numerically matches the chart version. Compare live images against rendered manifests or chart defaults; Hubble Timescape can intentionally track its own tag inside the Cilium chart.
- Prefer adapting an existing Cilium or Tetragon install over reinstalling it blindly.

## Validation Checklist

- Cilium agent, Hubble, Envoy, operator, and Tetragon metrics ports match the repo assumptions.
- DNS proxy HA still exposes service `cilium-dnsproxy` on `9967` when that component is enabled.
- Helm status and runtime state agree for `cilium`, `cilium-dnsproxy`, and `tetragon`, or any mismatch is explained before changing the releases.
- The live container images for Cilium, Envoy, operator, relay, and DNS proxy match the intended chart train instead of just the Helm release metadata.
- Any transient Hubble Relay `NOT_SERVING` state during a Cilium rollout is resolved or explicitly traced to `hubble-peer` or certificate convergence before rollback.
- `k8sServiceHost` has been replaced with the real API server endpoint when using the EKS values file.
- Namespaces and workload labels still line up with the repo's observability assumptions. If not, hand the collector relabel work to `deploy-splunk-o11y-lab`.
- OpenShift-specific constraints were handled explicitly instead of reusing AWS or generic Kubernetes settings.

## References

- `references/repo-map.md`
- `references/kubernetes.md`
- `references/openshift.md`
