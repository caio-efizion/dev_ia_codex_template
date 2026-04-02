#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=security/validators/common.sh
source "${SCRIPT_DIR}/common.sh"

FINDINGS_FILE=""
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --findings)
      FINDINGS_FILE="$2"
      shift 2
      ;;
    --files)
      shift
      while [[ $# -gt 0 && "$1" != --* ]]; do
        FILES+=("$1")
        shift
      done
      ;;
    *)
      log_err "unsupported argument: $1"
      exit 1
      ;;
  esac
done

[[ -n "$FINDINGS_FILE" ]] || { log_err "missing --findings"; exit 1; }
: > "$FINDINGS_FILE"

for file in "${FILES[@]}"; do
  [[ -f "$file" ]] || continue

  if grep -EInq '\beval\s*\(|new Function\s*\(|document\.write\s*\(|child_process\.exec\s*\(|execSync\s*\(' "$file"; then
    append_finding "$FINDINGS_FILE" HIGH DANGEROUS_SINK "$file" "dangerous dynamic execution or shell execution pattern detected"
  fi

  if grep -EInq 'dangerouslySetInnerHTML|\.innerHTML\s*=|insertAdjacentHTML\s*\(' "$file"; then
    append_finding "$FINDINGS_FILE" HIGH UNSAFE_HTML "$file" "unsafe HTML injection pattern detected"
  fi

  if grep -EInq 'localStorage\.(setItem|getItem).*token|sessionStorage\.(setItem|getItem).*token' "$file"; then
    append_finding "$FINDINGS_FILE" HIGH TOKEN_STORAGE "$file" "token-like data stored in web storage"
  fi

  if grep -EIn 'http://' "$file" | grep -Ev 'http://(localhost|127\.0\.0\.1)' >/dev/null; then
    append_finding "$FINDINGS_FILE" MEDIUM INSECURE_ENDPOINT "$file" "non-localhost HTTP endpoint detected"
  fi
done
