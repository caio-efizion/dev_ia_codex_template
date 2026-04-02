#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
PRD_FILE="${REPO_ROOT}/docs/prd.md"
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ-prd-auditor')
EVALUATOR_FILE="${REPO_ROOT}/scripts/ai-evaluate-prd.mjs"

fail() {
  printf 'ai-score-prd: %s\n' "$1" >&2
  exit 1
}

main() {
  [[ -f "$PRD_FILE" ]] || fail "missing PRD file: ${PRD_FILE}"
  [[ -f "$EVALUATOR_FILE" ]] || fail "missing evaluator file: ${EVALUATOR_FILE}"
  command -v node >/dev/null 2>&1 || fail "node binary not found in PATH"

  node "$EVALUATOR_FILE" \
    --mode score \
    --repo-root "$REPO_ROOT" \
    --run-id "$RUN_ID"
}

main "$@"
