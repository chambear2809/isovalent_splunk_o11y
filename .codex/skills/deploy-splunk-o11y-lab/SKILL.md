---
name: deploy-splunk-o11y-lab
description: Install, configure, validate, or adapt the Splunk Observability Cloud components in this repository for Kubernetes, Amazon EKS, or OpenShift. Use when Codex needs to work with the Splunk OpenTelemetry Collector or Operator, auto-instrumentation, curated metric filters, dashboard imports, or platform-specific collector settings.
---

# Deploy Splunk O11y Lab

Use this skill for the Splunk Observability side of the repo. If the task changes Cilium, Hubble, Tetragon, DNS proxy HA, or platform networking values, use `deploy-isovalent-lab`.

## Quick Start

1. Read `references/repo-map.md`.
2. Decide which platform path applies:
   - Read `references/kubernetes.md` for EKS or standard Kubernetes.
   - Read `references/openshift.md` for OpenShift.
3. Read `references/collector.md` whenever the task touches receivers, filters, the Operator, instrumentation, or dashboards.

## Workflow

1. Establish scope.
   - Determine whether the task is collector install, operator install, app onboarding, auto-instrumentation, dashboard import, validation, or troubleshooting.
   - Prefer discovery over reinstall when the collector already exists.
2. Inventory the cluster before changing anything.
   - Check namespaces, Helm releases and release status, collector ConfigMaps, installed CRDs, `Instrumentation` resources, and running collector or Operator workloads.
   - Confirm whether the `splunk-otel-collector` release has created the gateway deployment, agent DaemonSet, `k8s-cluster-receiver`, Operator, cert-manager, and webhook resources.
   - Refresh the Helm repos and compare the installed chart version to the latest official Splunk chart version before deciding whether to upgrade.
   - Audit both namespace and workload `instrumentation.opentelemetry.io/*` annotations, and keep a real `Instrumentation` object handy for server-side dry-run webhook checks when admission health is in doubt.
   - Do not treat Helm `STATUS: failed` as proof the collector is absent. Upgrade failures can leave the existing collector stack running.
3. Reuse repo artifacts.
   - Treat `examples/splunk-otel-isovalent.yaml` and the dashboard JSON files as the source of truth.
   - Treat the prose docs as operator guidance, not immutable truth, because the repo is still EKS-first.
4. Apply the platform branch.
   - For Kubernetes or EKS, keep the repo's EKS-specific collector settings only when AWS is actually the target.
   - For generic Kubernetes, keep the receiver and filter logic but strip distribution flags that no longer apply.
   - For OpenShift, follow the OpenShift-specific branch and do not reuse the EKS distribution settings unchanged.
5. Validate telemetry flow.
   - Confirm the rendered collector config, Helm status, operator state, annotation targets, scrape targets, and dashboard filters before considering the change complete.

## Non-Negotiables

- Preserve the curated metric filter unless the user explicitly wants a broader export.
- Preserve the repo's explicit Prometheus receivers and relabel rules unless the platform changes namespaces, labels, or chart packaging.
- Resolve the latest Splunk chart version from the official Helm repo at runtime instead of trusting stale hard-coded pins.
- If enabling OpenTelemetry auto-instrumentation, make sure the Operator and `Instrumentation` resources exist before annotating workloads.
- Match `Instrumentation` annotation values to real objects before restarting workloads.
- Namespace-level instrumentation defaults can break pod admission even when workloads are unannotated. Audit namespaces as well as workloads.
- Do not assume `OpenTelemetryCollector` custom resources exist; this repo can be chart-managed with ConfigMaps plus `Instrumentation` resources only.
- Do not assume the Splunk chart version equals the collector, operator, or optional OBI image tags. Compare live images against rendered manifests or chart defaults.
- If a Helm upgrade hits server-side apply ownership conflicts on webhook configurations, verify the chart-managed release is the intended owner before retrying with `--force-conflicts`.
- Keep dashboard JSON imports aligned with the actual `clusterName`.

## Validation Checklist

- The rendered collector config still contains the `prometheus/isovalent_*` receivers and the include filter.
- `clusterName`, `environment`, realm, and token values match the target deployment.
- Helm status and runtime state agree, or any mismatch is explained before changing the release.
- Collector, gateway, agent, and Operator pods rolled out cleanly.
- A server-side dry-run annotation against a real `Instrumentation` object succeeds after Operator or cert-manager changes, or any failure is explained.
- Live collector, operator, agent, and optional OBI images match the rendered chart expectations.
- Namespace or workload annotations still point at real `Instrumentation` resources.
- Dashboard JSON imports do not contain stale cluster filters for a different cluster name.

## References

- `references/repo-map.md`
- `references/kubernetes.md`
- `references/openshift.md`
- `references/collector.md`
