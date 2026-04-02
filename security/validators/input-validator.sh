#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=security/validators/common.sh
source "${SCRIPT_DIR}/common.sh"

STEP=""
RUN_ID=""
REPO_ROOT=""
GUARD_FILE=""
INPUT_LIST_FILE=""
REPORT_DIR=""
THRESHOLD="MEDIUM"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step) STEP="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --guard) GUARD_FILE="$2"; shift 2 ;;
    --inputs) INPUT_LIST_FILE="$2"; shift 2 ;;
    --report-dir) REPORT_DIR="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    *) log_err "unsupported argument: $1"; exit 1 ;;
  esac
done

[[ -n "$STEP" && -n "$RUN_ID" && -n "$REPO_ROOT" && -n "$GUARD_FILE" && -n "$INPUT_LIST_FILE" && -n "$REPORT_DIR" ]] || { log_err "missing required arguments"; exit 1; }
ensure_guard_shape "$GUARD_FILE"
mkdir -p "$REPORT_DIR"
findings_file=$(mktemp)
secret_findings=$(mktemp)
: > "$findings_file"

mapfile -t files < <(grep -v '^$' "$INPUT_LIST_FILE" | sed "s#^#${REPO_ROOT}/#" | sed 's#//*#/#g' | while read -r p; do [[ -f "$p" ]] && printf '%s\n' "$p"; done)

"${SCRIPT_DIR}/secret-scan.sh" --findings "$secret_findings" --files "${files[@]}"
cat "$secret_findings" >> "$findings_file"

for file in "${files[@]}"; do
  case "$file" in
    */ai/*|*/security/*|*/runtime/*)
      continue
      ;;
  esac
  if grep -EInq '(ignore (all|previous|prior) instructions|system prompt|developer message|tool instructions|bypass approvals|disable security)' "$file"; then
    append_finding "$findings_file" MEDIUM PROMPT_INJECTION "$file" "prompt-injection marker detected in untrusted input"
  fi
done

max_severity=$(max_severity_from_findings "$findings_file")
status=pass
if should_block "$max_severity" "$THRESHOLD"; then
  status=blocked
fi

write_json_report "$REPORT_DIR/${STEP}-input.json" "$status" "$max_severity" "$STEP" input "$findings_file"
write_markdown_report "$REPORT_DIR/${STEP}-input.md" "${STEP} Input Validation" "$status" "$max_severity" "$findings_file"
rm -f "$findings_file" "$secret_findings"

if [[ "$status" != pass ]]; then
  exit 1
fi
