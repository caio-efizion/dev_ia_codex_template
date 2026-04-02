#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DRY_RUN=0
MODE=""

fail() {
  printf 'ai-workflow: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ai-workflow.sh <define|build|prove|flow|flow-strict> [--dry-run]

Modes:
  define      bootstrap the repo and prepare the project PRD gate
  build       execute planner -> spec-generator -> ux-ui-designer -> builder
  prove       execute reviewer -> tester -> frontend-auditor -> security
  flow        run define -> build -> prove
  flow-strict run define -> build -> prove with strict PRD enforcement on execution phases

Options:
  --dry-run   print the commands without executing them
EOF
}

parse_args() {
  [[ $# -gt 0 ]] || {
    usage
    exit 1
  }

  MODE="$1"
  shift

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=1
        ;;
      -h|--help|help)
        usage
        exit 0
        ;;
      *)
        fail "unsupported argument: $1"
        ;;
    esac
    shift
  done

  case "$MODE" in
    define|build|prove|flow|flow-strict)
      ;;
    *)
      fail "unsupported mode: ${MODE}"
      ;;
  esac
}

run_step() {
  local description="$1"
  shift

  printf '%s\n' "==> ${description}"
  printf '%s' '    '
  printf '%q ' "$@"
  printf '\n'

  if [[ "$DRY_RUN" == "1" ]]; then
    return 0
  fi

  (
    cd "$REPO_ROOT"
    "$@"
  )
}

run_define() {
  run_step "Initialize minimal PRD-first scaffolding" ./scripts/ai-init-project.sh
  run_step "Build or refine the project PRD" ./scripts/ai-build-prd.sh
  run_step "Review the project PRD quality" ./scripts/ai-review-prd.sh
  run_step "Score the project PRD gate" ./scripts/ai-score-prd.sh
}

run_build() {
  local strict="${1:-0}"

  if [[ "$strict" == "1" ]]; then
    run_step "Build the active slice with strict PRD enforcement" env AI_ENFORCE_PRD_QUALITY=1 ./scripts/ai-run-graph.sh builder
    return 0
  fi

  run_step "Build the active slice" ./scripts/ai-run-graph.sh builder
}

run_prove() {
  local strict="${1:-0}"

  if [[ "$strict" == "1" ]]; then
    run_step "Prove the active slice with review, test, frontend audit, and security under strict PRD enforcement" env AI_ENFORCE_PRD_QUALITY=1 ./scripts/ai-run-graph.sh reviewer tester frontend-auditor security
    return 0
  fi

  run_step "Prove the active slice with review, test, frontend audit, and security" ./scripts/ai-run-graph.sh reviewer tester frontend-auditor security
}

main() {
  parse_args "$@"

  case "$MODE" in
    define)
      run_define
      ;;
    build)
      run_build 0
      ;;
    prove)
      run_prove 0
      ;;
    flow)
      run_define
      run_build 0
      run_prove 0
      ;;
    flow-strict)
      run_define
      run_build 1
      run_prove 1
      ;;
  esac
}

main "$@"
