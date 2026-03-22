# OpenShift Path

## First Principles

Do not treat OpenShift as a drop-in replacement for the EKS path in this repo.

Apply these rules first:

- Do not reuse `examples/cluster.yaml` or `examples/nodegroup.yaml`.
- Do not reuse EKS ENI and AWS IPAM settings.
- Prefer `oc` for cluster interaction.
- Expect SecurityContextConstraints and CRI-O behavior to matter.

## Discovery

Confirm the platform before making changes:

- `helm repo update`
- `oc version`
- `oc api-resources | grep route.openshift.io`
- `oc get scc`
- `helm list -A`
- `helm status cilium -n kube-system`
- `helm status cilium-dnsproxy -n kube-system`
- `helm status tetragon -n tetragon`
- `helm search repo isovalent/cilium --versions | head -n 3`
- `helm search repo isovalent/cilium-dnsproxy --versions | head -n 3`
- `helm search repo isovalent/tetragon --versions | head -n 3`
- `oc get pods,ds,deploy,svc -A | egrep 'cilium|hubble|tetragon'`

If Isovalent components already exist, adapt to the installed layout instead of forcing the EKS file set.
Prefer the live release state over older doc names or versions when they disagree, especially for DNS proxy HA.
If the user wants the latest versions, resolve them from `helm search repo` at runtime before upgrading.

## Isovalent On OpenShift

Use the repo's observability intent, but not the EKS bootstrap path.

Assume this until proven otherwise:

- Cilium on OpenShift is platform-specific and must be discovered before you change it.
- Existing namespaces, labels, service names, or operators may differ from the EKS examples.

When adapting the repo:

- Reuse the Hubble and Tetragon observability requirements.
- Rebuild any platform-specific values against the actual OpenShift deployment layout.
- Avoid reinstalling Cilium with the EKS values file.

## Hubble, Envoy, And Tetragon

When enabling or validating observability on OpenShift:

- Keep the metrics ports and scrape intent unless the platform packaging changes them.
- Confirm the namespace and label layout before reusing Kubernetes selectors unchanged.
- Treat Tetragon namespace differences as normal and validate them explicitly.

## Validation

Validate with:

- `helm status cilium -n kube-system`
- `helm status cilium-dnsproxy -n kube-system`
- `helm status tetragon -n tetragon`
- `oc get pods,ds,deploy,svc -A | egrep 'cilium|hubble|tetragon'`
- `oc get scc`
- `oc logs -n kube-system -l k8s-app=cilium --tail=200`
- `oc logs -n tetragon -l app.kubernetes.io/name=tetragon --tail=200`

If the OpenShift layout changes the labels or namespaces that the Splunk collector expects, keep the Isovalent install correct first and then update the collector via `deploy-splunk-o11y-lab`.

## External Anchors

- Cilium OpenShift install guidance: `https://docs.cilium.io/en/latest/installation/k8s-install-openshift-okd.html`
