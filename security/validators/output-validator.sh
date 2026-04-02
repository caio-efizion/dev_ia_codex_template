#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=security/validators/common.sh
source "${SCRIPT_DIR}/common.sh"

STEP=""
RUN_ID=""
REPO_ROOT=""
GUARD_FILE=""
CHANGED_LIST_FILE=""
REPORT_DIR=""
CONFIG_FILE=""
THRESHOLD="MEDIUM"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) STEP="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --guard) GUARD_FILE="$2"; shift 2 ;;
    --changed) CHANGED_LIST_FILE="$2"; shift 2 ;;
    --report-dir) REPORT_DIR="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    *) log_err "unsupported argument: $1"; exit 1 ;;
  esac
done

[[ -n "$STEP" && -n "$RUN_ID" && -n "$REPO_ROOT" && -n "$GUARD_FILE" && -n "$CHANGED_LIST_FILE" && -n "$REPORT_DIR" ]] || { log_err "missing required arguments"; exit 1; }
ensure_guard_shape "$GUARD_FILE"
mkdir -p "$REPORT_DIR"
findings_file=$(mktemp)
secret_findings=$(mktemp)
sast_findings=$(mktemp)
env_findings=$(mktemp)
dep_findings=$(mktemp)
: > "$findings_file"

mapfile -t files < <(grep -v '^$' "$CHANGED_LIST_FILE" | sed "s#^#${REPO_ROOT}/#" | sed 's#//*#/#g' | while read -r p; do [[ -f "$p" ]] && printf '%s\n' "$p"; done)

if (( ${#files[@]} > 0 )); then
  "${SCRIPT_DIR}/secret-scan.sh" --findings "$secret_findings" --files "${files[@]}"
  "${SCRIPT_DIR}/sast-scan.sh" --findings "$sast_findings" --files "${files[@]}"
  cat "$secret_findings" >> "$findings_file"
  cat "$sast_findings" >> "$findings_file"
fi

node - "$CONFIG_FILE" <<'NODE' > /tmp/env-allowed.$$
const fs = require('fs');
const configPath = process.argv[2];
if (!configPath || !fs.existsSync(configPath)) {
  process.stdout.write('.env.example,.env.template,.env.sample,.env.test.example');
  process.exit(0);
}
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const allowed = (((config.security || {}).env || {}).allowedExampleFiles || ['.env.example','.env.template','.env.sample','.env.test.example']);
process.stdout.write(allowed.join(','));
NODE
allowed_env=$(cat /tmp/env-allowed.$$)
rm -f /tmp/env-allowed.$$
"${SCRIPT_DIR}/env-validator.sh" --repo-root "$REPO_ROOT" --findings "$env_findings" --allowed "$allowed_env"
cat "$env_findings" >> "$findings_file"

if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
  "${SCRIPT_DIR}/dependency-scan.sh" --config "$CONFIG_FILE" --findings "$dep_findings"
  cat "$dep_findings" >> "$findings_file"
fi

max_severity=$(max_severity_from_findings "$findings_file")
status=pass
if should_block "$max_severity" "$THRESHOLD"; then
  status=blocked
fi

write_json_report "$REPORT_DIR/${STEP}-output.json" "$status" "$max_severity" "$STEP" output "$findings_file"
write_markdown_report "$REPORT_DIR/${STEP}-output.md" "${STEP} Output Validation" "$status" "$max_severity" "$findings_file"
rm -f "$findings_file" "$secret_findings" "$sast_findings" "$env_findings" "$dep_findings"

if [[ "$status" != pass ]]; then
  exit 1
fi
