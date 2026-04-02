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
  case "$(basename "$file")" in
    *.pem|*.p12|*.key|id_rsa|id_ed25519|*.jks|*.kdbx)
      append_finding "$FINDINGS_FILE" CRITICAL SECRET_FILE "$file" "private key or credential container committed to the repository"
      ;;
    .env|.env.local|.env.production|.env.staging|.env.development)
      append_finding "$FINDINGS_FILE" CRITICAL ENV_FILE "$file" "runtime environment file committed to the repository"
      ;;
  esac

  if grep -EInq '(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN (RSA|EC|OPENSSH|DSA|PGP) PRIVATE KEY-----)' "$file"; then
    append_finding "$FINDINGS_FILE" CRITICAL SECRET_PATTERN "$file" "secret-like token or private key marker detected"
  fi

done
