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

for path in README.md QUICK_REFERENCE.md INDEX.md ARCHITECTURE.md examples/README.md; do
  require_file "$path"
done

require_text "README.md" "helm get values splunk-otel-collector -n otel-splunk -o yaml > splunk-otel-live-values.yaml"
require_text "README.md" "Helm can expose \`instrumentation.spec\` defaults without rendering or owning any live \`Instrumentation\` resources."
require_text "README.md" "kubectl get --raw '/api/v1/namespaces/tetragon/services/http:tetragon:metrics/proxy/metrics' | grep '^tetragon_' | head -20"
require_text "README.md" "The number of nodes requested in your node group config are in \`Ready\` state"
forbid_text "README.md" "kubectl exec -n tetragon ds/tetragon -- curl -s localhost:2112/metrics | head -20"

require_text "QUICK_REFERENCE.md" "helm get values splunk-otel-collector -n otel-splunk -o yaml > splunk-otel-live-values.yaml"
require_text "QUICK_REFERENCE.md" "kubectl get --raw '/api/v1/namespaces/tetragon/services/http:tetragon:metrics/proxy/metrics' | grep '^tetragon_' | head -20"
require_text "QUICK_REFERENCE.md" "export CILIUM_CHART_VERSION=\"\$(helm search repo isovalent/cilium --versions | awk 'NR==2 {print \$2}')\""
forbid_text "QUICK_REFERENCE.md" "head -n 3"
forbid_text "QUICK_REFERENCE.md" "kubectl exec -n tetragon ds/tetragon -- curl -s localhost:2112/metrics | head -20"

require_text "examples/README.md" "On an existing \`splunk-otel-collector\` release, start from \`helm get values splunk-otel-collector -n otel-splunk -o yaml\`"
require_text "examples/README.md" "Helm can expose \`instrumentation.spec\` defaults without rendering or owning live \`Instrumentation\` resources."
require_text "examples/README.md" "kubectl get --raw '/api/v1/namespaces/tetragon/services/http:tetragon:metrics/proxy/metrics' | grep \"^tetragon_\""
forbid_text "examples/README.md" "kubectl exec -n tetragon ds/tetragon -- curl -s localhost:2112/metrics | grep \"^tetragon_\""

require_text "INDEX.md" "| Cilium | 1.18.8 | CNI + Networking |"
require_text "INDEX.md" "| Tetragon | 1.18.1 | Runtime security |"
require_text "INDEX.md" "| Splunk OTel Collector chart | 0.147.1 | Metrics collection |"
require_text "INDEX.md" "Sample EC2 Nodes (2x m5.xlarge from \`examples/nodegroup.yaml\`)"
forbid_text "INDEX.md" "| Cilium | 1.18.4 | CNI + Networking |"
forbid_text "INDEX.md" "| Tetragon | 1.18.0 | Runtime security |"
forbid_text "INDEX.md" "| Splunk OTel Collector | 0.140.0 | Metrics collection |"

require_text "ARCHITECTURE.md" "Example node group uses 2x m5.xlarge instances in private subnets; live clusters may scale beyond this sample"

if (( failures > 0 )); then
  printf 'Project doc validation failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'Project doc validation passed.\n'
