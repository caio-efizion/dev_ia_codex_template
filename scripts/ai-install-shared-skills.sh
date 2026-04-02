#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
SOURCE_ROOT="${REPO_ROOT}/skills"
CODEX_ROOT="${CODEX_HOME:-${HOME}/.codex}"
TARGET_ROOT="${CODEX_ROOT}/skills"

log() {
  printf '%s\n' "$1"
}

fail() {
  printf 'ai-install-shared-skills: %s\n' "$1" >&2
  exit 1
}

[[ -d "$SOURCE_ROOT" ]] || fail "missing skills directory: ${SOURCE_ROOT}"
mkdir -p "$TARGET_ROOT"

installed=0
for skill_dir in "$SOURCE_ROOT"/*; do
  [[ -d "$skill_dir" ]] || continue
  [[ -f "$skill_dir/SKILL.md" ]] || continue

  skill_name=$(basename "$skill_dir")
  target_dir="${TARGET_ROOT}/${skill_name}"
  rm -rf "$target_dir"
  cp -R "$skill_dir" "$target_dir"
  log "installed ${skill_name} -> ${target_dir}"
  installed=$((installed + 1))
done

if [[ "$installed" -eq 0 ]]; then
  fail "no versioned skills with SKILL.md were found under ${SOURCE_ROOT}"
fi

log "shared skill installation complete"
