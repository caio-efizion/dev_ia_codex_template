#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
MODE=""
STEP=""
RUN_ID=""
BRIEF_FILE=""
CONTEXT_MANIFEST_FILE=""
CHANGED_LIST_FILE=""
GUARD_FILE=""
CONFIG_FILE=""
REPORT_DIR=""
THRESHOLD="${AI_SECURITY_RISK_THRESHOLD:-MEDIUM}"

fail() {
  printf 'ai-run-stage-validators: %s\n' "$1" >&2
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

extract_inputs() {
  local output_file="$1"

  node - "$BRIEF_FILE" "$CONTEXT_MANIFEST_FILE" <<'NODE' > "$output_file"
const fs = require('fs');
const path = require('path');

const briefFile = process.argv[2];
const manifestFile = process.argv[3];
const seen = new Set();
const collected = [];

function pushPath(value) {
  if (!value) return;
  let cleaned = value.trim();
  cleaned = cleaned.replace(/^[`]+|[`]+$/g, '');
  cleaned = cleaned.replace(/\s+\|.*$/, '');
  cleaned = cleaned.replace(/\s+\(missing\)$/, '');
  cleaned = cleaned.replace(/^[-*]\s+/, '');
  if (!cleaned || cleaned === 'none' || cleaned === 'null') return;
  if (cleaned.startsWith('runtime/')) return;
  if (cleaned.startsWith('http://') || cleaned.startsWith('https://')) return;
  if (cleaned.includes(' ')) return;
  if (!seen.has(cleaned)) {
    seen.add(cleaned);
    collected.push(cleaned);
  }
}

function parseMarkdownFile(file) {
  if (!file || !fs.existsSync(file)) return;
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  for (const line of lines) {
    const direct = line.match(/^[-*]\s+`?([^`|]+)`?(?:\s*\|.*)?$/);
    if (direct) {
      pushPath(direct[1]);
      continue;
    }
    const mdLink = line.match(/\[([^\]]+)\]\(([^)]+)\)/);
    if (mdLink) {
      pushPath(mdLink[2]);
    }
  }
}

parseMarkdownFile(briefFile);
parseMarkdownFile(manifestFile);
process.stdout.write(`${collected.join('\n')}\n`);
NODE
}

write_stage_summary() {
  local summary_file="$REPORT_DIR/${STEP}-summary.md"
  local input_status="missing"
  local output_status="missing"

  [[ -f "$REPORT_DIR/${STEP}-input.json" ]] && input_status=$(node -e 'const fs=require("fs"); const x=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(x.status);' "$REPORT_DIR/${STEP}-input.json")
  [[ -f "$REPORT_DIR/${STEP}-output.json" ]] && output_status=$(node -e 'const fs=require("fs"); const x=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(x.status);' "$REPORT_DIR/${STEP}-output.json")

  {
    printf '# %s Security Summary\n\n' "$STEP"
    printf -- '- run_id: `%s`\n' "$RUN_ID"
    printf -- '- input_validation: `%s`\n' "$input_status"
    printf -- '- output_validation: `%s`\n' "$output_status"
    printf -- '- guard: `%s`\n\n' "${GUARD_FILE#${REPO_ROOT}/}"
    printf '## Reports\n\n'
    [[ -f "$REPORT_DIR/${STEP}-input.md" ]] && printf -- '- `%s`\n' "${REPORT_DIR#${REPO_ROOT}/}/${STEP}-input.md"
    [[ -f "$REPORT_DIR/${STEP}-output.md" ]] && printf -- '- `%s`\n' "${REPORT_DIR#${REPO_ROOT}/}/${STEP}-output.md"
  } > "$summary_file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="$2"; shift 2 ;;
    --step) STEP="$2"; shift 2 ;;
    --run-id) RUN_ID="$2"; shift 2 ;;
    --brief) BRIEF_FILE="$2"; shift 2 ;;
    --context-manifest) CONTEXT_MANIFEST_FILE="$2"; shift 2 ;;
    --changed) CHANGED_LIST_FILE="$2"; shift 2 ;;
    --guard) GUARD_FILE="$2"; shift 2 ;;
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --report-dir) REPORT_DIR="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    *) fail "unsupported argument: $1" ;;
  esac
done

[[ -n "$MODE" && -n "$STEP" && -n "$RUN_ID" && -n "$GUARD_FILE" && -n "$REPORT_DIR" ]] || fail "missing required arguments"
mkdir -p "$REPORT_DIR"
CONFIG_FILE=$(resolve_config_file)

case "$MODE" in
  pre)
    [[ -n "$BRIEF_FILE" ]] || fail "pre mode requires --brief"
    input_list=$(mktemp)
    extract_inputs "$input_list"
    "${REPO_ROOT}/security/validators/input-validator.sh" \
      --step "$STEP" \
      --run-id "$RUN_ID" \
      --repo-root "$REPO_ROOT" \
      --guard "$GUARD_FILE" \
      --inputs "$input_list" \
      --report-dir "$REPORT_DIR" \
      --threshold "$THRESHOLD"
    rm -f "$input_list"
    ;;
  post)
    [[ -n "$CHANGED_LIST_FILE" ]] || fail "post mode requires --changed"
    "${REPO_ROOT}/security/validators/output-validator.sh" \
      --step "$STEP" \
      --run-id "$RUN_ID" \
      --repo-root "$REPO_ROOT" \
      --guard "$GUARD_FILE" \
      --changed "$CHANGED_LIST_FILE" \
      --report-dir "$REPORT_DIR" \
      --config "$CONFIG_FILE" \
      --threshold "$THRESHOLD"
    ;;
  *)
    fail "unsupported mode: ${MODE}"
    ;;
esac

write_stage_summary
