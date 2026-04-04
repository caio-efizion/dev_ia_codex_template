#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
STRICT_MODE=0
PLACEHOLDER_PATTERN='\{\{[^}]+\}\}'

fail() {
  printf 'ai-placeholder-audit: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ai-placeholder-audit.sh [--strict]

Options:
  --strict  enforce convergence checks for critical architecture/spec artifacts
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict)
        STRICT_MODE=1
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
}

contains_placeholders() {
  local file_path="$1"
  grep -Eq "$PLACEHOLDER_PATTERN" "$file_path"
}

validate_required_files() {
  local files=("$@")
  local missing=()
  local unresolved=()
  local file_path

  for file_path in "${files[@]}"; do
    if [[ ! -f "${REPO_ROOT}/${file_path}" ]]; then
      missing+=("$file_path")
      continue
    fi

    if contains_placeholders "${REPO_ROOT}/${file_path}"; then
      unresolved+=("$file_path")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    printf '%s\n' "missing critical convergence files:" >&2
    printf '  - %s\n' "${missing[@]}" >&2
    return 1
  fi

  if (( ${#unresolved[@]} > 0 )); then
    printf '%s\n' "critical files still contain template placeholders:" >&2
    printf '  - %s\n' "${unresolved[@]}" >&2
    return 1
  fi

  return 0
}

validate_no_template_references() {
  local files=("$@")
  local invalid=()
  local file_path

  for file_path in "${files[@]}"; do
    if [[ ! -f "${REPO_ROOT}/${file_path}" ]]; then
      continue
    fi

    if grep -Eq '\.template\.md' "${REPO_ROOT}/${file_path}"; then
      invalid+=("$file_path")
    fi
  done

  if (( ${#invalid[@]} > 0 )); then
    printf '%s\n' "critical indexes still point to template specs:" >&2
    printf '  - %s\n' "${invalid[@]}" >&2
    return 1
  fi

  return 0
}

validate_docs_surface() {
  local docs_dirs=(
    "docs/architecture"
    "docs/adr"
    "docs/api"
    "docs/database"
    "docs/domain"
    "docs/testing"
  )
  local unresolved=()
  local scan_dir file_path

  for scan_dir in "${docs_dirs[@]}"; do
    [[ -d "${REPO_ROOT}/${scan_dir}" ]] || continue

    while IFS= read -r file_path; do
      if contains_placeholders "${REPO_ROOT}/${file_path}"; then
        unresolved+=("$file_path")
      fi
    done < <(
      cd "$REPO_ROOT" && find "$scan_dir" -type f -name '*.md' ! -name '*.template.md' | sort
    )
  done

  if (( ${#unresolved[@]} > 0 )); then
    printf '%s\n' "non-template docs still contain placeholders:" >&2
    printf '  - %s\n' "${unresolved[@]}" >&2
    return 1
  fi

  return 0
}

main() {
  local critical_files=(
    "docs/architecture/architecture.md"
    "docs/architecture/module-map.md"
    "docs/adr/0001-system-architecture.md"
    "docs/architecture/security-model.md"
    "docs/architecture/tenant-isolation.md"
    "docs/api/api-contracts.md"
    "docs/database/database-schema.md"
    "docs/domain/domain-model.md"
    "docs/testing/test-plan.md"
    "ai/context-index/context-map.json"
    "ai/spec-registry/specs.yaml"
    "tasks/tasks.md"
    "tasks/backlog.md"
  )
  local template_reference_sensitive=(
    "ai/context-index/context-map.json"
    "ai/spec-registry/specs.yaml"
    "tasks/backlog.md"
  )

  parse_args "$@"

  validate_required_files "${critical_files[@]}" || fail "critical convergence audit failed"

  if (( STRICT_MODE == 1 )); then
    validate_docs_surface || fail "strict placeholder audit failed for non-template docs"
    validate_no_template_references "${template_reference_sensitive[@]}" || fail "strict convergence still references template specs"
  fi

  printf '%s\n' "placeholder audit: pass"
}

main "$@"
