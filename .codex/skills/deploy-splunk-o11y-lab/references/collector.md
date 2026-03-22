# Splunk O11y Collector

## Source Of Truth

Use `examples/splunk-otel-isovalent.yaml` as the source of truth for the collector behavior in this repo.

This file already contains:

- Custom Prometheus receivers for Cilium, Hubble, Envoy, operator, and Tetragon metrics.
- `kubeletstats`, `hostmetrics`, and `otlp` receivers.
- A strict `filter/includemetrics` processor.
- `clusterName` and `environment`.
- `gateway.enabled: true`
- `certmanager.enabled: true`
- `operator.enabled: true`

## Runtime Shape

The repo installs the collector through the Splunk Helm chart, so discovery should start from the chart-managed resources instead of assuming `OpenTelemetryCollector` custom resources exist.

Inventory these resources first:

- `Deployment/splunk-otel-collector`
- `DaemonSet/splunk-otel-collector-agent`
- `DaemonSet/splunk-otel-collector-obi` on newer chart versions
- `Deployment/splunk-otel-collector-k8s-cluster-receiver`
- `Deployment/splunk-otel-collector-operator`
- The operator webhook services and cert-manager resources
- The rendered ConfigMaps for the agent, gateway, and cluster receiver
- `Instrumentation` resources used by app namespaces

It is valid for `kubectl get opentelemetrycollectors -A` to return no resources in this repo.

## Chart Version Maintenance

To keep the Splunk collector current:

- Run `helm repo update`.
- Resolve the latest chart version with `helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | head -n 3`.
- Compare that result to `helm status splunk-otel-collector -n otel-splunk`.
- Upgrade with the existing values file only after confirming the current runtime is healthy enough to carry the change.
- Do not assume the chart version numerically matches the collector or operator image tags. Validate against rendered manifests or live pod images.

## Metric Filter Intent

The include filter is deliberate.

Interpret it this way:

- Only listed metrics are exported.
- Anything not listed is dropped.
- This is cost control, not an accident.

Do not replace it with a broad allow-all pipeline unless the user explicitly asks for that tradeoff.

## Receiver Intent

The receiver layout exists because Isovalent metrics come from multiple ports and label sets:

- Cilium agent and Hubble metrics share Cilium pods but not ports.
- Envoy metrics come from `cilium-envoy`.
- Operator metrics come from a separate label family.
- Tetragon metrics come from a different namespace and pod label.

If the deployment layout changes:

- Update the relabel selectors.
- Keep the explicit receiver split.

## Auto-Instrumentation

When application tracing is in scope:

- Keep `operator.enabled: true`.
- Install CRDs if needed with `operatorcrds.install: true`.
- Ensure `Instrumentation` objects exist before the workload rollout.
- Inspect both namespace annotations and workload pod-template annotations for `instrumentation.opentelemetry.io/*`; workload annotations override namespace defaults.
- Annotation values can be `true`, a same-namespace instrumentation name, or a `namespace/name` reference. Match them to real objects before restarting workloads.
- Match the exporter protocol and port to the real `Instrumentation.spec.exporter.endpoint` instead of hardcoding OTLP HTTP `:4318`.
- A stale namespace annotation can block unrelated pod admissions even if the workload itself is not annotated. Clear invalid namespace defaults before blaming the Operator.
- When webhook or certificate health is in doubt, set `NS` and `INSTRUMENTATION` to a real object and probe admission with `kubectl annotate instrumentation -n "$NS" "$INSTRUMENTATION" skill-probe=$(date +%s) --overwrite --dry-run=server -o yaml`.

## Platform Toggles

Use these distribution rules:

- EKS: `distribution: eks` and `cloudProvider: aws`
- OpenShift: `distribution: openshift` and omit `cloudProvider`
- Generic Kubernetes: omit distribution-specific flags unless the target matches a documented Splunk distribution mode

## Dashboard Imports

When importing or updating the bundled dashboards:

- Check the cluster filters before import.
- Replace stale cluster names instead of importing them unchanged.
- Keep the dashboard scope aligned with the collector's exported metrics.

## Troubleshooting Focus

When the collector is not ingesting the expected metrics:

1. Inspect `helm status splunk-otel-collector -n otel-splunk` and the rendered collector ConfigMaps.
2. If Helm reports `STATUS: failed`, verify whether the existing collector, gateway, agent, operator, and webhook pods are still healthy before reinstalling anything.
3. If the upgrade failed on server-side apply ownership conflicts for webhook configurations, verify the chart-managed release should own those resources and retry with `--force-conflicts` if appropriate.
4. Verify the target pods expose the expected metrics on the expected ports.
5. Verify label selectors in relabeling still match the running pods.
6. Check collector and operator logs for scrape failures, TLS issues, webhook certificate errors, or rejected configs.
7. Right after an operator rollout, treat TLS handshake or `instrumentation-upgrade` errors as possibly transient until the webhook certificates reload. Re-run the server-side dry-run annotation before rollback.
8. Confirm the filter still includes the metric names you expect and that annotation targets still resolve to real `Instrumentation` objects.

If the underlying Isovalent components are missing or misconfigured, switch to `deploy-isovalent-lab` before widening or restructuring the telemetry pipeline.

## External Anchors

- Splunk Helm configuration: `https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-kubernetes/configure-with-helm`
- Splunk YAML templating for OpenShift-aware installs: `https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-kubernetes/install-with-yaml-manifests`
- Splunk advanced configuration note on OpenShift and non-root log collection: `https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-kubernetes/advanced-configuration`
- OpenTelemetry Operator annotation semantics: `https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/`
