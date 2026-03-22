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
- `helm search repo splunk-otel-collector-chart/splunk-otel-collector --versions | head -n 3`
- `oc get pods,ds,deploy,svc,cm -n otel-splunk`
- `oc get instrumentation -A`

If collector components already exist, adapt to the installed layout instead of forcing the EKS values unchanged.
If the Helm release is `failed`, distinguish an upgrade failure from a runtime outage before reinstalling the chart.
If the user wants the latest version, resolve it from `helm search repo` at runtime before upgrading.

## Splunk Collector Changes

For OpenShift, adapt `examples/splunk-otel-isovalent.yaml` like this:

- Set `distribution: openshift`.
- Remove `cloudProvider: aws`.
- Keep `clusterName`, `environment`, `gateway.enabled`, and the custom `prometheus/isovalent_*` receivers.
- Keep the strict include filter unless the user explicitly asks to widen it.
- Rebuild collector relabel selectors against the actual OpenShift deployment labels if they differ from the repo assumptions.

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

## Validation

Validate with:

- `helm status splunk-otel-collector -n otel-splunk`
- `oc get pods,ds,deploy,svc,cm -n otel-splunk`
- `oc get route -A`
- `oc get scc`
- `oc get configmap -n otel-splunk splunk-otel-collector-otel-agent -o yaml`
- `oc logs -n otel-splunk -l app=splunk-otel-collector --tail=200`
- `oc get instrumentation -A`

If the collector is not scraping Isovalent targets because those workloads are absent or named differently, use `deploy-isovalent-lab` to correct the platform-side install first.

## External Anchors

- Splunk collector install and templating: `https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-kubernetes/install-with-yaml-manifests`
- OpenTelemetry Operator auto-instrumentation: `https://opentelemetry.io/docs/platforms/kubernetes/operator/automatic/`
- OpenShift route basics: `https://docs.redhat.com/en/documentation/openshift_container_platform/4.14/html/building_applications/creating-applications`
