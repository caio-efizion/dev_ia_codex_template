#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ-template-validate')
EVALUATOR_FILE="${REPO_ROOT}/scripts/ai-evaluate-template.mjs"
OUTPUT_FILE="${REPO_ROOT}/runtime/logs/template-validation.md"

fail() {
  printf 'ai-validate-template: %s\n' "$1" >&2
  exit 1
}

main() {
  [[ -f "$EVALUATOR_FILE" ]] || fail "missing evaluator file: ${EVALUATOR_FILE}"
  command -v node >/dev/null 2>&1 || fail "node binary not found in PATH"

  node "$EVALUATOR_FILE" \
    --mode validate \
    --repo-root "$REPO_ROOT" \
    --run-id "$RUN_ID" \
    --output "$OUTPUT_FILE"
}

main "$@"
