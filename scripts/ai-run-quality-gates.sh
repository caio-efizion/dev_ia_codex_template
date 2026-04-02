#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
SLICE_ID=""
CONFIG_FILE="${AI_QUALITY_CONFIG:-}"
REPORT_DIR=""

fail() {
  printf 'ai-run-quality-gates: %s\n' "$1" >&2
  exit 1
}

resolve_config_file() {
  if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
    printf '%s\n' "$CONFIG_FILE"
    return 0
  fi
  if [[ -f "${REPO_ROOT}/quality/pipeline.config.json" ]]; then
    printf '%s\n' "${REPO_ROOT}/quality/pipeline.config.json"
    return 0
  fi
  printf '%s\n' "${REPO_ROOT}/quality/pipeline.config.template.json"
}

json_field() {
  local config="$1"
  local path_expr="$2"
  node - "$config" "$path_expr" <<'NODE'
const fs = require('fs');
const [, , file, expr] = process.argv;
const config = JSON.parse(fs.readFileSync(file, 'utf8'));
const value = expr.split('.').reduce((acc, key) => acc == null ? undefined : acc[key], config);
if (value == null) process.stdout.write('');
else if (typeof value === 'object') process.stdout.write(JSON.stringify(value));
else process.stdout.write(String(value));
NODE
}

run_command_gate() {
  local name="$1"
  local config="$2"
  local log_file="$REPORT_DIR/quality/${name}.log"
  local status_file="$REPORT_DIR/quality/${name}.status"
  local required cwd command gate_status

  required=$(json_field "$config" "commands.${name}.required")
  cwd=$(json_field "$config" "commands.${name}.cwd")
  command=$(json_field "$config" "commands.${name}.command")

  if [[ "$required" != "true" && -z "$command" ]]; then
    printf 'skipped\n' > "$log_file"
    printf 'skipped\n' > "$status_file"
    return 0
  fi

  if [[ -z "$command" || "$command" == "replace-me" ]]; then
    printf 'missing command configuration for %s\n' "$name" > "$log_file"
    printf 'failed\n' > "$status_file"
    return 1
  fi

  mkdir -p "$(dirname "$log_file")"
  set +e
  (
    cd "$REPO_ROOT/${cwd:-.}"
    bash -lc "$command"
  ) >"$log_file" 2>&1
  gate_status=$?
  set -e
  if (( gate_status == 0 )); then
    printf 'passed\n' > "$status_file"
  else
    printf 'failed\n' > "$status_file"
  fi
  return "$gate_status"
}

check_coverage_thresholds() {
  local config="$1"
  local summary_rel minimum_json cwd
  local summary_file

  cwd=$(json_field "$config" "commands.coverage.cwd")
  summary_rel=$(json_field "$config" "commands.coverage.summaryFile")
  minimum_json=$(json_field "$config" "commands.coverage.minimum")
  summary_file="$REPO_ROOT/${cwd:-.}/${summary_rel}"

  [[ -f "$summary_file" ]] || fail "coverage summary file not found: ${summary_file#${REPO_ROOT}/}"

  node - "$summary_file" "$minimum_json" "$REPORT_DIR/quality/coverage-thresholds.json" <<'NODE'
const fs = require('fs');
const [, , summaryFile, minimumJson, reportFile] = process.argv;
const summary = JSON.parse(fs.readFileSync(summaryFile, 'utf8'));
const minimum = JSON.parse(minimumJson || '{}');
const total = summary.total || summary;
const results = {};
let failed = false;
for (const metric of ['lines', 'functions', 'branches', 'statements']) {
  const actual = Number(total[metric]?.pct ?? 0);
  const expected = Number(minimum[metric] ?? 0);
  const passed = actual >= expected;
  results[metric] = { actual, expected, passed };
  if (!passed) failed = true;
}
fs.writeFileSync(reportFile, `${JSON.stringify(results, null, 2)}\n`);
if (failed) process.exit(1);
NODE
}

write_summary() {
  local status="$1"
  local config="$2"
  node - "$REPORT_DIR" "$status" "$config" <<'NODE'
const fs = require('fs');
const path = require('path');
const [, , reportDir, status, configFile] = process.argv;
const qualityDir = path.join(reportDir, 'quality');
const config = JSON.parse(fs.readFileSync(configFile, 'utf8'));
const gates = ['lint', 'typecheck', 'unit', 'e2e', 'coverage'];
const summary = {
  generated_at: new Date().toISOString(),
  status,
  config_file: path.relative(process.cwd(), configFile),
  gates: {},
  frontend_evidence_enabled: Boolean((config.frontendEvidence || {}).enabled)
};
for (const gate of gates) {
  const logFile = path.join(qualityDir, `${gate}.log`);
  const statusFile = path.join(qualityDir, `${gate}.status`);
  const gateStatus = fs.existsSync(statusFile) ? fs.readFileSync(statusFile, 'utf8').trim() : 'missing';
  summary.gates[gate] = {
    required: Boolean(config.commands?.[gate]?.required),
    log: fs.existsSync(logFile) ? path.relative(process.cwd(), logFile) : null,
    status: gateStatus,
    passed: gateStatus === 'passed' || gateStatus === 'skipped'
  };
}
const evidenceSummary = path.join(reportDir, 'frontend-evidence-summary.json');
if (fs.existsSync(evidenceSummary)) {
  summary.frontend_evidence = JSON.parse(fs.readFileSync(evidenceSummary, 'utf8'));
}
fs.writeFileSync(path.join(reportDir, 'quality-gates.json'), `${JSON.stringify(summary, null, 2)}\n`);
const lines = [
  '# Quality Gates',
  '',
  `- status: \`${status}\``,
  `- config_file: \`${summary.config_file}\``,
  '',
  '## Gates',
  ''
];
for (const gate of gates) {
  const gateSummary = summary.gates[gate];
  lines.push(`- ${gate}: ${gateSummary.passed ? 'pass' : 'fail'}${gateSummary.required ? ' (required)' : ''}`);
}
if (summary.frontend_evidence) {
  lines.push('', '## Frontend Evidence', '');
  lines.push(`- screenshots: ${summary.frontend_evidence.screenshot_count}`);
  lines.push(`- accessibility_passed: ${summary.frontend_evidence.accessibility_passed}`);
  lines.push(`- performance_passed: ${summary.frontend_evidence.performance_passed}`);
  lines.push(`- visual_regression_passed: ${summary.frontend_evidence.visual_regression_passed}`);
}
fs.writeFileSync(path.join(reportDir, 'quality-gates.md'), `${lines.join('\n')}\n`);
NODE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --slice) SLICE_ID="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --report-dir) REPORT_DIR="$2"; shift 2 ;;
    *) fail "unsupported argument: $1" ;;
  esac
done

[[ -n "$SLICE_ID" ]] || fail "missing --slice"
CONFIG_FILE=$(resolve_config_file)
REPORT_DIR=${REPORT_DIR:-"$REPO_ROOT/reports/slices/$SLICE_ID"}
mkdir -p "$REPORT_DIR/quality"

status=pass
for gate in lint typecheck unit e2e coverage; do
  if ! run_command_gate "$gate" "$CONFIG_FILE"; then
    status=fail
  fi
done

if [[ "$status" == pass ]]; then
  if ! check_coverage_thresholds "$CONFIG_FILE"; then
    printf 'failed-threshold\n' > "$REPORT_DIR/quality/coverage.status"
    status=fail
  fi
fi

frontend_enabled=$(json_field "$CONFIG_FILE" "frontendEvidence.enabled")
if [[ "$frontend_enabled" == "true" ]]; then
  if ! node "$REPO_ROOT/scripts/ai-collect-slice-evidence.mjs" --config "$CONFIG_FILE" --slice "$SLICE_ID" --report-dir "$REPORT_DIR"; then
    status=fail
  fi
fi

write_summary "$status" "$CONFIG_FILE"
[[ "$status" == pass ]]
