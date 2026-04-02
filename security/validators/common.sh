#!/usr/bin/env bash
set -euo pipefail

SEVERITY_ORDER_LOW=1
SEVERITY_ORDER_MEDIUM=2
SEVERITY_ORDER_HIGH=3
SEVERITY_ORDER_CRITICAL=4

log_err() {
  printf 'security-validator: %s\n' "$1" >&2
}

severity_rank() {
  case "$1" in
    LOW) printf '%s\n' "$SEVERITY_ORDER_LOW" ;;
    MEDIUM) printf '%s\n' "$SEVERITY_ORDER_MEDIUM" ;;
    HIGH) printf '%s\n' "$SEVERITY_ORDER_HIGH" ;;
    CRITICAL) printf '%s\n' "$SEVERITY_ORDER_CRITICAL" ;;
    *) printf '%s\n' 0 ;;
  esac
}

ensure_guard_shape() {
  local guard_file="$1"
  [[ -f "$guard_file" ]] || { log_err "missing guard file: ${guard_file}"; return 1; }
  grep -q '^## Input Rules$' "$guard_file" || { log_err "guard missing Input Rules: ${guard_file}"; return 1; }
  grep -q '^## Output Rules$' "$guard_file" || { log_err "guard missing Output Rules: ${guard_file}"; return 1; }
  grep -q '^## Failure Mode$' "$guard_file" || { log_err "guard missing Failure Mode: ${guard_file}"; return 1; }
}

json_escape() {
  node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1"
}

write_json_report() {
  local report_file="$1"
  local status="$2"
  local max_severity="$3"
  local stage="$4"
  local phase="$5"
  local findings_file="$6"

  node - "$report_file" "$status" "$max_severity" "$stage" "$phase" "$findings_file" <<'NODE'
const fs = require('fs');
const [, , reportFile, status, maxSeverity, stage, phase, findingsFile] = process.argv;
const findings = fs.existsSync(findingsFile)
  ? fs.readFileSync(findingsFile, 'utf8').split('\n').filter(Boolean).map((line) => JSON.parse(line))
  : [];
const report = {
  generated_at: new Date().toISOString(),
  stage,
  phase,
  status,
  max_severity: maxSeverity,
  findings
};
fs.writeFileSync(reportFile, `${JSON.stringify(report, null, 2)}\n`);
NODE
}

write_markdown_report() {
  local report_file="$1"
  local title="$2"
  local status="$3"
  local max_severity="$4"
  local findings_file="$5"

  {
    printf '# %s\n\n' "$title"
    printf -- '- status: `%s`\n' "$status"
    printf -- '- max_severity: `%s`\n\n' "$max_severity"
    printf '## Findings\n\n'
    if [[ ! -s "$findings_file" ]]; then
      printf -- '- none\n'
    else
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        local severity file code message
        severity=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.severity)' "$line")
        file=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.file || "n/a")' "$line")
        code=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.code || "n/a")' "$line")
        message=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.message)' "$line")
        printf -- '- [%s] `%s` `%s`: %s\n' "$severity" "$file" "$code" "$message"
      done < "$findings_file"
    fi
  } > "$report_file"
}

append_finding() {
  local findings_file="$1"
  local severity="$2"
  local code="$3"
  local file="$4"
  local message="$5"
  node -e 'const finding={severity:process.argv[1],code:process.argv[2],file:process.argv[3],message:process.argv[4]}; process.stdout.write(JSON.stringify(finding)+"\n")' \
    "$severity" "$code" "$file" "$message" >> "$findings_file"
}

max_severity_from_findings() {
  local findings_file="$1"
  local max="LOW"
  local current_rank max_rank
  max_rank=$(severity_rank "$max")

  if [[ ! -s "$findings_file" ]]; then
    printf '%s\n' "$max"
    return 0
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local severity
    severity=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.severity)' "$line")
    current_rank=$(severity_rank "$severity")
    if (( current_rank > max_rank )); then
      max="$severity"
      max_rank=$current_rank
    fi
  done < "$findings_file"

  printf '%s\n' "$max"
}

should_block() {
  local severity="$1"
  local threshold="${2:-MEDIUM}"
  local severity_value threshold_value
  severity_value=$(severity_rank "$severity")
  threshold_value=$(severity_rank "$threshold")
  (( severity_value >= threshold_value ))
}
