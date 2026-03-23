#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    fail "missing file: $path"
  fi
}

require_text() {
  local path="$1"
  local text="$2"
  if ! rg -F -q -- "$text" "$path"; then
    fail "expected text not found in $path: $text"
  fi
}

forbid_text() {
  local path="$1"
  local text="$2"
  if rg -F -q -- "$text" "$path"; then
    fail "unexpected text found in $path: $text"
  fi
}

require_file ".codex/skills/deploy-isovalent-lab/SKILL.md"
require_file ".codex/skills/deploy-isovalent-lab/references/kubernetes.md"
require_file ".codex/skills/deploy-isovalent-lab/references/openshift.md"
require_file ".codex/skills/deploy-splunk-o11y-lab/SKILL.md"
require_file ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md"
require_file ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md"
require_file ".codex/skills/deploy-splunk-o11y-lab/references/collector.md"
require_file ".codex/skills/deploy-splunk-o11y-lab/references/repo-map.md"

require_text ".codex/skills/deploy-isovalent-lab/SKILL.md" 'Do not pull Splunk collector settings such as `distribution` or `cloudProvider` into Isovalent chart values.'
require_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" "helm get values cilium -n kube-system -a -o yaml"
require_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" "helm get values cilium-dnsproxy -n kube-system -a -o yaml"
require_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" "helm search repo isovalent/cilium --versions | awk 'NR==2 {print \$2}'"
require_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" "Do not pull Splunk collector settings such as \`distribution: eks\` or \`cloudProvider: aws\` into Isovalent values."
require_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" "If a release does not exist yet, skip \`helm status\` and \`helm get values\` for that release and treat the task as a fresh install path."
require_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" "kubectl get --raw '/api/v1/namespaces/tetragon/services/http:tetragon:metrics/proxy/metrics' | grep '^tetragon_' | head"
require_text ".codex/skills/deploy-isovalent-lab/references/openshift.md" "helm get values cilium -n kube-system -a -o yaml"
require_text ".codex/skills/deploy-isovalent-lab/references/openshift.md" "If the target release is Helm-managed and already exists, prefer \`helm upgrade\` over reinstall"
require_text ".codex/skills/deploy-isovalent-lab/references/openshift.md" "If a release does not exist yet, skip \`helm status\` and \`helm get values\` for that release and treat the task as a fresh install path."
require_text ".codex/skills/deploy-isovalent-lab/references/openshift.md" "oc get ds cilium -n kube-system -o jsonpath='{range .spec.template.spec.containers[*]}{.name}={.image}{\"\\n\"}{end}'"
require_text ".codex/skills/deploy-isovalent-lab/references/openshift.md" '`hubble-relay` can briefly report `NOT_SERVING`'
forbid_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" '- `distribution: eks`'
forbid_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" '- `cloudProvider: aws`'
forbid_text ".codex/skills/deploy-isovalent-lab/references/kubernetes.md" "kubectl exec -n tetragon ds/tetragon -- curl -s localhost:2112/metrics | head"

require_text ".codex/skills/deploy-splunk-o11y-lab/SKILL.md" "Capture live Helm values for existing releases before upgrading"
require_text ".codex/skills/deploy-splunk-o11y-lab/SKILL.md" "Start from \`helm get values splunk-otel-collector -n otel-splunk -o yaml\`"
require_text ".codex/skills/deploy-splunk-o11y-lab/SKILL.md" "--force-conflicts"
require_text ".codex/skills/deploy-splunk-o11y-lab/SKILL.md" "Determine whether live \`Instrumentation\` resources are Helm-managed, operator-upgraded, or separately applied."
require_text ".codex/skills/deploy-splunk-o11y-lab/SKILL.md" "Do not assume the Splunk chart owns \`Instrumentation\` resources just because Helm values include an \`instrumentation.spec\` block."
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "helm get values splunk-otel-collector -n otel-splunk -o yaml"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "manifest=\"\$(helm get manifest splunk-otel-collector -n otel-splunk)\" && if printf '%s\\n' \"\$manifest\" | rg -q '^kind: Instrumentation$'; then echo 'Helm renders Instrumentation'; else echo 'Helm does not render Instrumentation'; fi"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "kubectl get instrumentation -A -o json | jq -r '.items[] | [.metadata.namespace,.metadata.name"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "kubectl get deploy,sts,ds,job,cronjob -A -o custom-columns='KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "kubectl get ns -o custom-columns='NAME:.metadata.name"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "For upgrades on an existing cluster, merge the repo's receiver, filter, and distribution intent into the live values"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "--force-conflicts"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "If the release does not exist yet, skip \`helm status\` and \`helm get values\` for \`splunk-otel-collector\` and treat the task as a fresh install path."
require_text ".codex/skills/deploy-splunk-o11y-lab/references/kubernetes.md" "Use Helm \`instrumentation.spec\` as chart-default context, not authoritative live state"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "helm get values splunk-otel-collector -n otel-splunk -o yaml"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "manifest=\"\$(helm get manifest splunk-otel-collector -n otel-splunk)\" && if printf '%s\\n' \"\$manifest\" | rg -q '^kind: Instrumentation$'; then echo 'Helm renders Instrumentation'; else echo 'Helm does not render Instrumentation'; fi"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "oc get instrumentation -A -o json | jq -r '.items[] | [.metadata.namespace,.metadata.name"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "oc get deploy,sts,ds,job,cronjob -A -o custom-columns='KIND:.kind,NAMESPACE:.metadata.namespace,NAME:.metadata.name"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "oc get ns -o custom-columns='NAME:.metadata.name"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "oc annotate instrumentation -n \"\$NS\" \"\$INSTRUMENTATION\" skill-probe=\$(date +%s) --overwrite --dry-run=server -o yaml"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "--force-conflicts"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "If the release does not exist yet, skip \`helm status\` and \`helm get values\` for \`splunk-otel-collector\` and treat the task as a fresh install path."
require_text ".codex/skills/deploy-splunk-o11y-lab/references/openshift.md" "Use Helm \`instrumentation.spec\` as chart-default context, not authoritative live state"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/collector.md" "Do not blindly reapply \`examples/splunk-otel-isovalent.yaml\` over an existing release"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/collector.md" 'instrumentation.opentelemetry.io/*'
require_text ".codex/skills/deploy-splunk-o11y-lab/references/collector.md" "It is also valid for the Helm chart to expose \`instrumentation.spec\` defaults without rendering or owning any \`Instrumentation\` resources"
require_text ".codex/skills/deploy-splunk-o11y-lab/references/collector.md" "Determine ownership before comparing intent."
require_text ".codex/skills/deploy-splunk-o11y-lab/references/repo-map.md" "On an existing release, do not overwrite live values with these placeholders."
require_text ".codex/skills/deploy-splunk-o11y-lab/references/repo-map.md" "The chart can expose \`instrumentation.spec\` defaults without rendering or owning any \`Instrumentation\` resources in the release manifest."
forbid_text ".codex/skills/deploy-splunk-o11y-lab/references/collector.md" 'instrumentation.opentelemetry.io/*}'

while IFS= read -r path; do
  forbid_text "$path" 'head -n 3'
done < <(find .codex/skills/deploy-isovalent-lab .codex/skills/deploy-splunk-o11y-lab -type f)

if (( failures > 0 )); then
  printf 'Skill validation failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'Skill validation passed.\n'
