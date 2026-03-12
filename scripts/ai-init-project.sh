#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)

log() {
  printf '%s\n' "$1"
}

relpath() {
  local path="$1"
  printf '%s\n' "${path#"${REPO_ROOT}/"}"
}

ensure_dir() {
  mkdir -p "$1"
}

ensure_gitkeep() {
  local dir="$1"
  ensure_dir "$dir"
  : > "${dir}/.gitkeep"
}

copy_if_missing() {
  local source="$1"
  local target="$2"

  ensure_dir "$(dirname "$target")"

  if [[ ! -f "$source" ]]; then
    log "missing template: $(relpath "$source")"
    return 1
  fi

  if [[ -f "$target" ]]; then
    log "kept existing $(relpath "$target")"
    return 0
  fi

  cp "$source" "$target"
  log "created $(relpath "$target") from $(relpath "$source")"
}

copy_template_family_if_missing() {
  local dir="$1"
  local template

  shopt -s nullglob
  for template in "${dir}"/*.template.md; do
    copy_if_missing "$template" "${template%.template.md}.md"
  done
  shopt -u nullglob
}

main() {
  ensure_dir "${REPO_ROOT}/ai/context-compressed"
  ensure_dir "${REPO_ROOT}/docs/specs"
  ensure_dir "${REPO_ROOT}/tasks"
  ensure_gitkeep "${REPO_ROOT}/runtime/state"
  ensure_gitkeep "${REPO_ROOT}/runtime/logs"
  ensure_gitkeep "${REPO_ROOT}/runtime/graphs"
  ensure_gitkeep "${REPO_ROOT}/runtime/context-cache"

  copy_if_missing \
    "${REPO_ROOT}/docs/prd.template.md" \
    "${REPO_ROOT}/docs/prd.md"
  copy_if_missing \
    "${REPO_ROOT}/tasks/tasks.template.md" \
    "${REPO_ROOT}/tasks/tasks.md"
  copy_if_missing \
    "${REPO_ROOT}/tasks/backlog.template.md" \
    "${REPO_ROOT}/tasks/backlog.md"
  copy_if_missing \
    "${REPO_ROOT}/ai/system/state.template.md" \
    "${REPO_ROOT}/runtime/state/agent-state.md"

  copy_template_family_if_missing "${REPO_ROOT}/docs/adr"
  copy_template_family_if_missing "${REPO_ROOT}/docs/api"
  copy_template_family_if_missing "${REPO_ROOT}/docs/architecture"
  copy_template_family_if_missing "${REPO_ROOT}/docs/audit"
  copy_template_family_if_missing "${REPO_ROOT}/docs/database"
  copy_template_family_if_missing "${REPO_ROOT}/docs/domain"
  copy_template_family_if_missing "${REPO_ROOT}/docs/testing"

  if [[ -x "${SCRIPT_DIR}/ai-refresh-context.sh" ]]; then
    "${SCRIPT_DIR}/ai-refresh-context.sh"
  else
    bash "${SCRIPT_DIR}/ai-refresh-context.sh"
  fi

  log "project initialization complete"
}

main "$@"
