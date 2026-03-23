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
- `helm get values splunk-otel-collector -n otel-splunk -o yaml`
- `helm get values splunk-otel-collector -n otel-splunk -a -o yaml`
- `manifest="$(helm get manifest splunk-otel-collector -n otel-splunk)" && if printf '%s\n' "$manifest" | rg -q '^kind: Instrumentation$'; then echo 'Helm renders Instrumentation'; else echo 'Helm does not render Instrumentation'; fi`
- `helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | awk 'NR==2 {print $2}'`
- `kubectl get pods,ds,deploy,svc,cm -n otel-splunk`
- `kubectl get crd | egrep 'instrumentations.opentelemetry.io|opentelemetrycollectors.opentelemetry.io'`
- `kubectl get instrumentation -A`
- `kubectl get instrumentation -A -o json | jq -r '.items[] | [.metadata.namespace,.metadata.name,(.metadata.annotations["meta.helm.sh/release-name"] // ""),(.metadata.labels["app.kubernetes.io/managed-by"] // ""),(.metadata.ownerReferences // [] | length | tostring),(if .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"] then "yes" else "no" end),(.spec.exporter.endpoint // ""),(.spec.java.image // ""),(.spec.nodejs.image // ""),(.spec.python.image // "")] | @tsv'`
- `kubectl get deploy,sts,ds,job,cronjob -A -o custom-columns='KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,JAVA:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python,CONTAINERS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/container-names'`
- `kubectl get ns -o custom-columns='NAME:.metadata.name,JAVA:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python'`

If the release does not exist yet, skip `helm status` and `helm get values` for `splunk-otel-collector` and treat the task as a fresh install path.
If the collector or Operator already exists, prefer `helm upgrade` or rendered-config reuse over reinstall.
If the Helm release is `failed`, distinguish an upgrade failure from a runtime outage. Operator webhook or certificate problems can block upgrades while the old collector pods keep running.
If the user wants the latest version, resolve it from `helm search repo` at runtime before upgrading instead of pinning an old chart version in the command.
If the release already exists, start from `helm get values splunk-otel-collector -n otel-splunk -o yaml` instead of blindly reapplying `examples/splunk-otel-isovalent.yaml`. The repo example carries placeholders and may not reflect live realm, token, or chart drift.
If namespace or workload annotations reference missing `Instrumentation` objects, clear or correct those defaults before blaming the Operator. Namespace-level defaults can block unrelated pods.
When webhook health is in doubt, run a server-side dry-run annotation against a real `Instrumentation` object before and after the upgrade.
First determine ownership. If `helm get manifest` does not render any `Instrumentation` resources, or the live CRs lack Helm ownership metadata, treat them as separately applied cluster resources even if Helm values include an `instrumentation.spec` block.
Use Helm `instrumentation.spec` as chart-default context, not authoritative live state, unless the release actually renders or owns those `Instrumentation` resources.

## EKS Workflow

For EKS, reuse the repo artifact directly:

- `examples/splunk-otel-isovalent.yaml`

For fresh installs, the example file is the correct base.
For upgrades on an existing cluster, merge the repo's receiver, filter, and distribution intent into the live values from `helm get values ... -o yaml` instead of overwriting the release with the example file verbatim.

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
- A passing dry-run annotation only proves webhook admission is healthy now. After any `instrumentation-upgrade` error, re-check the stored `Instrumentation` specs and ownership. If those CRs are separately managed, record the drift and reconcile them deliberately instead of forcing Helm values over them.

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
- `manifest="$(helm get manifest splunk-otel-collector -n otel-splunk)" && if printf '%s\n' "$manifest" | rg -q '^kind: Instrumentation$'; then echo 'Helm renders Instrumentation'; else echo 'Helm does not render Instrumentation'; fi`
- `kubectl get instrumentation -A -o json | jq -r '.items[] | [.metadata.namespace,.metadata.name,(.metadata.annotations["meta.helm.sh/release-name"] // ""),(.metadata.labels["app.kubernetes.io/managed-by"] // ""),(.metadata.ownerReferences // [] | length | tostring),(if .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"] then "yes" else "no" end),(.spec.exporter.endpoint // ""),(.spec.java.image // ""),(.spec.nodejs.image // ""),(.spec.python.image // "")] | @tsv'`
- `kubectl get deploy,sts,ds,job,cronjob -A -o custom-columns='KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,JAVA:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python,CONTAINERS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/container-names'`
- `kubectl get ns -o custom-columns='NAME:.metadata.name,JAVA:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python'`
- `kubectl annotate instrumentation -n "$NS" "$INSTRUMENTATION" skill-probe=$(date +%s) --overwrite --dry-run=server -o yaml`

It is valid for `kubectl get opentelemetrycollectors -A` to return no resources if the chart is managing the collector directly.
Treat dry-run success and `Instrumentation` ownership as separate checks. A recovered webhook does not guarantee the stored resources were reconciled during an earlier failed rollout, and Helm values alone do not prove ownership.
If the collector is not scraping the expected targets, inspect the relabel selectors before changing the whole pipeline. If the targets themselves are missing, hand off to `deploy-isovalent-lab`.
