#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
RUN_ID="security-audit-$(date -u '+%Y%m%dT%H%M%SZ')"
THRESHOLD="${AI_SECURITY_RISK_THRESHOLD:-MEDIUM}"
DRY_RUN=0

fail() {
  printf 'ai-audit-security: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ai-audit-security.sh [--dry-run]

Purpose:
  Run the template security validators against the current repository as a whole-repo audit.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      fail "unsupported argument: $1"
      ;;
  esac
done

CONFIG_FILE="${REPO_ROOT}/quality/pipeline.config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  CONFIG_FILE="${REPO_ROOT}/quality/pipeline.config.template.json"
fi

GUARD_FILE="${REPO_ROOT}/security/agent-guards/security.guard.md"
REPORT_DIR="${REPO_ROOT}/reports/security/${RUN_ID}"
DOC_REPORT_FILE="${REPO_ROOT}/docs/audit/security-report.md"
VALIDATOR_FILE="${REPO_ROOT}/security/validators/output-validator.sh"

[[ -f "$VALIDATOR_FILE" ]] || fail "missing validator file: ${VALIDATOR_FILE}"
[[ -f "$GUARD_FILE" ]] || fail "missing guard file: ${GUARD_FILE}"

changed_list=$(mktemp)
trap 'rm -f "$changed_list"' EXIT

find "$REPO_ROOT" \
  \( -path "$REPO_ROOT/.git" -o -path "$REPO_ROOT/node_modules" -o -path "$REPO_ROOT/runtime" -o -path "$REPO_ROOT/reports" -o -path "$REPO_ROOT/dist" -o -path "$REPO_ROOT/coverage" -o -path "$REPO_ROOT/test-results" -o -path "$REPO_ROOT/playwright-report" -o -path "$REPO_ROOT/.next" \) -prune -o \
  -type f -print \
  | sed "s#^${REPO_ROOT}/##" \
  | sort > "$changed_list"

if [[ "$DRY_RUN" == "1" ]]; then
  printf '%s\n' "ai-audit-security dry-run"
  printf '%s\n' "- threshold: ${THRESHOLD}"
  printf '%s\n' "- config: ${CONFIG_FILE#${REPO_ROOT}/}"
  printf '%s\n' "- guard: ${GUARD_FILE#${REPO_ROOT}/}"
  printf '%s\n' "- report dir: ${REPORT_DIR#${REPO_ROOT}/}"
  printf '%s\n' "- doc report: ${DOC_REPORT_FILE#${REPO_ROOT}/}"
  printf '%s\n' "- files to scan: $(grep -c '.' "$changed_list" || true)"
  exit 0
fi

mkdir -p "$REPORT_DIR" "$(dirname "$DOC_REPORT_FILE")"

set +e
"$VALIDATOR_FILE" \
  --step security-audit \
  --run-id "$RUN_ID" \
  --repo-root "$REPO_ROOT" \
  --guard "$GUARD_FILE" \
  --changed "$changed_list" \
  --report-dir "$REPORT_DIR" \
  --config "$CONFIG_FILE" \
  --threshold "$THRESHOLD"
validator_status=$?
set -e

node - "$REPORT_DIR/security-audit-output.json" "$DOC_REPORT_FILE" "$RUN_ID" "$CONFIG_FILE" "$THRESHOLD" <<'NODE'
const fs = require('fs');
const path = require('path');

const [, , jsonReportFile, docReportFile, runId, configFile, threshold] = process.argv;
const report = JSON.parse(fs.readFileSync(jsonReportFile, 'utf8'));
const findings = Array.isArray(report.findings) ? report.findings : [];
const counts = { LOW: 0, MEDIUM: 0, HIGH: 0, CRITICAL: 0 };

for (const finding of findings) {
  counts[finding.severity] = (counts[finding.severity] || 0) + 1;
}

function recommendedAction(code) {
  switch (code) {
    case 'SECRET_FILE':
    case 'SECRET_PATTERN':
    case 'ENV_FILE':
      return 'remove secret material from the repository and rotate exposed credentials immediately';
    case 'DANGEROUS_SINK':
    case 'UNSAFE_HTML':
    case 'TOKEN_STORAGE':
      return 'refactor unsafe execution or frontend trust patterns behind reviewed server-side controls';
    case 'INSECURE_ENDPOINT':
      return 'replace non-localhost HTTP endpoints with HTTPS or environment-driven configuration';
    case 'DEP_SCAN_FAILED':
    case 'DEP_SCAN_MISSING':
      return 'configure and run the dependency audit command in quality/pipeline.config.json';
    default:
      return 'review the finding and open a remediation slice with an explicit acceptance criterion';
  }
}

const actions = [...new Set(findings.map((finding) => recommendedAction(finding.code)))];

const lines = [
  '# Security Audit',
  '',
  `- run_id: \`${runId}\``,
  `- status: \`${report.status}\``,
  `- max_severity: \`${report.max_severity}\``,
  `- threshold: \`${threshold}\``,
  `- config_file: \`${path.relative(process.cwd(), configFile)}\``,
  `- report_dir: \`${path.relative(process.cwd(), path.dirname(jsonReportFile))}\``,
  '',
  '## Summary',
  '',
  `- total_findings: ${findings.length}`,
  `- critical: ${counts.CRITICAL || 0}`,
  `- high: ${counts.HIGH || 0}`,
  `- medium: ${counts.MEDIUM || 0}`,
  `- low: ${counts.LOW || 0}`,
  '',
  '## Findings',
  '',
];

if (findings.length === 0) {
  lines.push('- none');
} else {
  for (const finding of findings) {
    lines.push(`- [${finding.severity}] \`${finding.file || 'n/a'}\` \`${finding.code}\`: ${finding.message}`);
  }
}

lines.push('', '## Required Actions', '');
if (actions.length === 0) {
  lines.push('- none');
} else {
  for (const action of actions) {
    lines.push(`- ${action}`);
  }
}

fs.writeFileSync(docReportFile, `${lines.join('\n')}\n`);
NODE

if (( validator_status != 0 )); then
  printf '%s\n' "security audit completed with blocking findings"
  exit "$validator_status"
fi

printf '%s\n' "security audit passed"
