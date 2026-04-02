#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=security/validators/common.sh
source "${SCRIPT_DIR}/common.sh"

REPO_ROOT=""
FINDINGS_FILE=""
ALLOWED_EXAMPLES=".env.example,.env.template,.env.sample,.env.test.example"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --findings)
      FINDINGS_FILE="$2"
      shift 2
      ;;
    --allowed)
      ALLOWED_EXAMPLES="$2"
      shift 2
      ;;
    *)
      log_err "unsupported argument: $1"
      exit 1
      ;;
  esac
done

[[ -n "$REPO_ROOT" ]] || { log_err "missing --repo-root"; exit 1; }
[[ -n "$FINDINGS_FILE" ]] || { log_err "missing --findings"; exit 1; }
: > "$FINDINGS_FILE"

IFS=',' read -r -a allowed <<< "$ALLOWED_EXAMPLES"

while IFS= read -r path; do
  [[ -n "$path" ]] || continue
  local_allowed=0
  base=$(basename "$path")
  for allowed_name in "${allowed[@]}"; do
    if [[ "$base" == "$allowed_name" ]]; then
      local_allowed=1
      break
    fi
  done
  if (( local_allowed == 0 )); then
    append_finding "$FINDINGS_FILE" CRITICAL TRACKED_ENV "$path" "tracked environment file is not allowed"
  fi
done < <(find "$REPO_ROOT" -type f \( -name '.env' -o -name '.env.*' \) ! -path '*/node_modules/*' | sed "s#^${REPO_ROOT}/##")
