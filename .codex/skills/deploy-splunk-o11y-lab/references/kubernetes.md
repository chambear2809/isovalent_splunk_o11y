# Kubernetes Path

## Platform Split

Use this path for:

- Amazon EKS.
- Standard Kubernetes clusters that are not OpenShift.

Within this branch, split again:

- If the target is EKS, reuse the repo's collector values directly.
- If the target is generic Kubernetes, keep the receiver and filter logic but remove AWS-only or EKS-only settings.

## Discovery

Before changing anything, check:

- `helm repo update`
- `kubectl version`
- `kubectl get ns`
- `helm list -A`
- `helm status splunk-otel-collector -n otel-splunk`
- `helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | head -n 3`
- `kubectl get pods,ds,deploy,svc,cm -n otel-splunk`
- `kubectl get crd | egrep 'instrumentations.opentelemetry.io|opentelemetrycollectors.opentelemetry.io'`
- `kubectl get instrumentation -A`
- `kubectl get deploy -A -o yaml | egrep 'instrumentation.opentelemetry.io/'`
- `kubectl get ns -o yaml | egrep 'instrumentation.opentelemetry.io/'`

If the collector or Operator already exists, prefer `helm upgrade` or rendered-config reuse over reinstall.
If the Helm release is `failed`, distinguish an upgrade failure from a runtime outage. Operator webhook or certificate problems can block upgrades while the old collector pods keep running.
If the user wants the latest version, resolve it from `helm search repo` at runtime before upgrading instead of pinning an old chart version in the command.
If namespace or workload annotations reference missing `Instrumentation` objects, clear or correct those defaults before blaming the Operator. Namespace-level defaults can block unrelated pods.
When webhook health is in doubt, run a server-side dry-run annotation against a real `Instrumentation` object before and after the upgrade.

## EKS Workflow

For EKS, reuse the repo artifact directly:

- `examples/splunk-otel-isovalent.yaml`

Key EKS-only settings to preserve:

- `distribution: eks`
- `cloudProvider: aws`
- The explicit `prometheus/isovalent_*` receivers
- The strict `filter/includemetrics` processor

## Generic Kubernetes Adaptation

If the cluster is not EKS:

- Remove `distribution: eks` and `cloudProvider: aws` unless the target platform explicitly matches them.
- Keep the explicit receiver split intact.
- Keep the include filter intact unless the user explicitly changes the cost and coverage tradeoff.
- Update relabel selectors only when namespaces or pod labels differ from the repo assumptions.

For a generic cluster, the safest move is usually:

1. Discover how the collector is already installed.
2. Preserve the existing receiver and filter shape.
3. Update only the platform-specific values that no longer apply.

## Upgrade Caveats

When upgrading the Splunk chart:

- Newer chart versions can add `DaemonSet/splunk-otel-collector-obi`; do not treat it as drift if the rendered chart includes it.
- Chart version, collector image, operator image, and OBI image may not numerically match. Validate against rendered manifests or chart defaults instead of raw version equality.
- If Helm fails on server-side apply field-manager conflicts for mutating or validating webhook configurations, and the chart-managed release should own those resources, retry with `--force-conflicts` instead of deleting the webhook resources blindly.
- Immediately after operator rollout, transient TLS handshake or `instrumentation-upgrade` errors can clear once webhook certificates reload. Re-test admission before rollback.

## Validation

Validate with:

- `helm status splunk-otel-collector -n otel-splunk`
- `kubectl get pods,ds,deploy,svc,cm -n otel-splunk`
- `kubectl get deploy splunk-otel-collector splunk-otel-collector-operator -n otel-splunk -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}{end}'`
- `kubectl get ds -n otel-splunk`
- `kubectl get configmap -n otel-splunk splunk-otel-collector-otel-agent -o yaml`
- `kubectl logs -n otel-splunk -l app=splunk-otel-collector --tail=200`
- `kubectl logs -n otel-splunk deploy/splunk-otel-collector-operator -c manager --tail=200`
- `kubectl get instrumentation -A`
- `kubectl get deploy -A -o yaml | egrep 'instrumentation.opentelemetry.io/'`
- `kubectl get ns -o yaml | egrep 'instrumentation.opentelemetry.io/'`
- `kubectl annotate instrumentation -n "$NS" "$INSTRUMENTATION" skill-probe=$(date +%s) --overwrite --dry-run=server -o yaml`

It is valid for `kubectl get opentelemetrycollectors -A` to return no resources if the chart is managing the collector directly.
If the collector is not scraping the expected targets, inspect the relabel selectors before changing the whole pipeline. If the targets themselves are missing, hand off to `deploy-isovalent-lab`.
