#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=security/validators/common.sh
source "${SCRIPT_DIR}/common.sh"

CONFIG_FILE=""
FINDINGS_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --findings)
      FINDINGS_FILE="$2"
      shift 2
      ;;
    *)
      log_err "unsupported argument: $1"
      exit 1
      ;;
  esac
done

[[ -n "$CONFIG_FILE" ]] || { log_err "missing --config"; exit 1; }
[[ -n "$FINDINGS_FILE" ]] || { log_err "missing --findings"; exit 1; }
: > "$FINDINGS_FILE"

node - "$CONFIG_FILE" <<'NODE' > /tmp/dependency-scan-config.$$
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const scan = (config.security && config.security.dependencyScan) || {};
process.stdout.write(JSON.stringify(scan));
NODE

scan_json=$(cat /tmp/dependency-scan-config.$$)
rm -f /tmp/dependency-scan-config.$$
required=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(String(Boolean(x.required)))' "$scan_json")
command=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.command || "")' "$scan_json")
cwd=$(node -e 'const x=JSON.parse(process.argv[1]); process.stdout.write(x.cwd || ".")' "$scan_json")

if [[ -z "$command" || "$command" == "replace-me" ]]; then
  if [[ "$required" == "true" ]]; then
    append_finding "$FINDINGS_FILE" MEDIUM DEP_SCAN_MISSING "$CONFIG_FILE" "dependency scan command is required but not configured"
  fi
  exit 0
fi

set +e
output=$(cd "$cwd" && bash -lc "$command" 2>&1)
status=$?
set -e

if (( status != 0 )); then
  append_finding "$FINDINGS_FILE" HIGH DEP_SCAN_FAILED "$cwd" "dependency scan failed: ${output//$'\n'/ | }"
fi
