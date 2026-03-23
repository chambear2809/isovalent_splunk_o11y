# OpenShift Path

## First Principles

Do not treat OpenShift as a drop-in replacement for the EKS collector path in this repo.

Apply these rules first:

- Set `distribution: openshift`.
- Remove `cloudProvider: aws`.
- Prefer `oc` for cluster interaction and `Route` objects for external exposure.
- Expect SecurityContextConstraints and CRI-O behavior to matter.

## Discovery

Confirm the platform before making changes:

- `helm repo update`
- `oc version`
- `oc api-resources | grep route.openshift.io`
- `oc get scc`
- `helm list -A`
- `helm status splunk-otel-collector -n otel-splunk`
- `helm get values splunk-otel-collector -n otel-splunk -o yaml`
- `helm get values splunk-otel-collector -n otel-splunk -a -o yaml`
- `manifest="$(helm get manifest splunk-otel-collector -n otel-splunk)" && if printf '%s\n' "$manifest" | rg -q '^kind: Instrumentation$'; then echo 'Helm renders Instrumentation'; else echo 'Helm does not render Instrumentation'; fi`
- `helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | awk 'NR==2 {print $2}'`
- `oc get pods,ds,deploy,svc,cm -n otel-splunk`
- `oc get instrumentation -A`
- `oc get instrumentation -A -o json | jq -r '.items[] | [.metadata.namespace,.metadata.name,(.metadata.annotations["meta.helm.sh/release-name"] // ""),(.metadata.labels["app.kubernetes.io/managed-by"] // ""),(.metadata.ownerReferences // [] | length | tostring),(if .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"] then "yes" else "no" end),(.spec.exporter.endpoint // ""),(.spec.java.image // ""),(.spec.nodejs.image // ""),(.spec.python.image // "")] | @tsv'`
- `oc get deploy,sts,ds,job,cronjob -A -o custom-columns='KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,JAVA:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python,CONTAINERS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/container-names'`
- `oc get ns -o custom-columns='NAME:.metadata.name,JAVA:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python'`

If the release does not exist yet, skip `helm status` and `helm get values` for `splunk-otel-collector` and treat the task as a fresh install path.
If collector components already exist, adapt to the installed layout instead of forcing the EKS values unchanged.
If the Helm release is `failed`, distinguish an upgrade failure from a runtime outage before reinstalling the chart.
If the user wants the latest version, resolve it from `helm search repo` at runtime before upgrading.
If the release already exists, start from `helm get values splunk-otel-collector -n otel-splunk -o yaml` instead of blindly reapplying `examples/splunk-otel-isovalent.yaml`. The repo example carries placeholders and may not reflect live realm, token, or chart drift.
If namespace or workload annotations reference missing `Instrumentation` objects, clear or correct those defaults before blaming the Operator.
When webhook health is in doubt, run a server-side dry-run annotation against a real `Instrumentation` object before and after the upgrade.
First determine ownership. If `helm get manifest` does not render any `Instrumentation` resources, or the live CRs lack Helm ownership metadata, treat them as separately applied cluster resources even if Helm values include an `instrumentation.spec` block.
Use Helm `instrumentation.spec` as chart-default context, not authoritative live state, unless the release actually renders or owns those `Instrumentation` resources.

## Splunk Collector Changes

For OpenShift, adapt `examples/splunk-otel-isovalent.yaml` like this:

- Set `distribution: openshift`.
- Remove `cloudProvider: aws`.
- Keep `clusterName`, `environment`, `gateway.enabled`, and the custom `prometheus/isovalent_*` receivers.
- Keep the strict include filter unless the user explicitly asks to widen it.
- Rebuild collector relabel selectors against the actual OpenShift deployment labels if they differ from the repo assumptions.

For fresh installs, the example file is the correct base.
For upgrades on an existing cluster, merge the repo's receiver, filter, and distribution intent into the live values from `helm get values ... -o yaml` instead of overwriting the release with the example file verbatim.

If the chart or rendered manifests need OpenShift security handling:

- Expect SecurityContextConstraints to be part of the deployment story.
- Avoid forcing non-root log collection settings on OpenShift if logs are required.

## Routes Instead Of Ingress

When a service needs external access on OpenShift:

- Prefer `oc expose service <name> --hostname=<host>` or an explicit `Route`.
- Do not add a Kubernetes `Ingress` unless the cluster is intentionally configured to use one.

## Auto-Instrumentation

If the user wants zero-code instrumentation:

- Keep `operator.enabled: true`.
- Add `operatorcrds.install: true` if the CRDs are not already present.
- Create the `Instrumentation` resources before deploying or restarting annotated workloads.
- Match the annotation values to real `Instrumentation` objects.

The repo uses:

- `instrumentation.opentelemetry.io/inject-java`
- `instrumentation.opentelemetry.io/inject-nodejs`
- `instrumentation.opentelemetry.io/inject-python`

Those annotations can point at:

- `true`
- A same-namespace instrumentation name
- A cross-namespace reference in `namespace/name` form

Also inspect namespace annotations, not only workload annotations. Namespace defaults can be overridden by pod-template annotations.
A stale namespace annotation can block unrelated pod admissions even if the workload itself is not annotated.
When webhook or certificate health is in doubt, set `NS` and `INSTRUMENTATION` to a real object and probe admission with `oc annotate instrumentation -n "$NS" "$INSTRUMENTATION" skill-probe=$(date +%s) --overwrite --dry-run=server -o yaml`.

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
- `oc get pods,ds,deploy,svc,cm -n otel-splunk`
- `oc get route -A`
- `oc get scc`
- `oc get deploy splunk-otel-collector splunk-otel-collector-operator -n otel-splunk -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*]}{.name}={.image}{"\n"}{end}{end}'`
- `oc get ds -n otel-splunk`
- `oc get configmap -n otel-splunk splunk-otel-collector-otel-agent -o yaml`
- `oc logs -n otel-splunk -l app=splunk-otel-collector --tail=200`
- `oc logs -n otel-splunk deploy/splunk-otel-collector-operator -c manager --tail=200`
- `oc get instrumentation -A`
- `manifest="$(helm get manifest splunk-otel-collector -n otel-splunk)" && if printf '%s\n' "$manifest" | rg -q '^kind: Instrumentation$'; then echo 'Helm renders Instrumentation'; else echo 'Helm does not render Instrumentation'; fi`
- `oc get instrumentation -A -o json | jq -r '.items[] | [.metadata.namespace,.metadata.name,(.metadata.annotations["meta.helm.sh/release-name"] // ""),(.metadata.labels["app.kubernetes.io/managed-by"] // ""),(.metadata.ownerReferences // [] | length | tostring),(if .metadata.annotations["kubectl.kubernetes.io/last-applied-configuration"] then "yes" else "no" end),(.spec.exporter.endpoint // ""),(.spec.java.image // ""),(.spec.nodejs.image // ""),(.spec.python.image // "")] | @tsv'`
- `oc get deploy,sts,ds,job,cronjob -A -o custom-columns='KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name,JAVA:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python,CONTAINERS:.spec.template.metadata.annotations.instrumentation\\.opentelemetry\\.io/container-names'`
- `oc get ns -o custom-columns='NAME:.metadata.name,JAVA:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-java,NODEJS:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-nodejs,PYTHON:.metadata.annotations.instrumentation\\.opentelemetry\\.io/inject-python'`
- `oc annotate instrumentation -n "$NS" "$INSTRUMENTATION" skill-probe=$(date +%s) --overwrite --dry-run=server -o yaml`

Treat dry-run success and `Instrumentation` ownership as separate checks. A recovered webhook does not guarantee the stored resources were reconciled during an earlier failed rollout, and Helm values alone do not prove ownership.
If the collector is not scraping Isovalent targets because those workloads are absent or named differently, use `deploy-isovalent-lab` to correct the platform-side install first.

## External Anchors

- Splunk collector install and templating: `https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-kubernetes/install-with-yaml-manifests`
- OpenTelemetry Operator auto-instrumentation: `https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/`
- OpenShift route basics: `https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html/building_applications/creating-applications`
