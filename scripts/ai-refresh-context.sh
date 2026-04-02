#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
SOURCE_DIR="${REPO_ROOT}/docs"
TARGET_DIR="${REPO_ROOT}/ai/context-compressed"
GENERATED_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

fail() {
  printf 'ai-refresh-context: %s\n' "$1" >&2
  exit 1
}

ensure_dir() {
  mkdir -p "$1"
}

relpath() {
  local path="$1"
  printf '%s\n' "${path#"${REPO_ROOT}/"}"
}

select_doc() {
  local primary="$1"
  local fallback="$2"

  if [[ -f "$primary" ]]; then
    printf '%s\n' "$primary"
  elif [[ -f "$fallback" ]]; then
    printf '%s\n' "$fallback"
  else
    fail "missing source document: $(relpath "$primary") or $(relpath "$fallback")"
  fi
}

markdown_title() {
  local file="$1"
  awk '/^# / { sub(/^# /, ""); print; exit }' "$file"
}

markdown_sections() {
  local file="$1"
  awk '
    /^## / {
      sub(/^## /, "- ");
      print;
      count++;
      if (count == 4) {
        exit;
      }
    }
  ' "$file"
}

file_count() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f -name '*.md' ! -name '*.template.md' | wc -l | tr -d ' '
}

project_summary() {
  local prd_file tasks_file backlog_file

  prd_file=$(select_doc "${SOURCE_DIR}/prd.md" "${SOURCE_DIR}/prd.template.md")
  tasks_file=$(select_doc "${REPO_ROOT}/tasks/tasks.md" "${REPO_ROOT}/tasks/tasks.template.md")
  backlog_file=$(select_doc "${REPO_ROOT}/tasks/backlog.md" "${REPO_ROOT}/tasks/backlog.template.md")

  cat > "${TARGET_DIR}/project.summary.md" <<EOF
# Project Summary

- generated_at: ${GENERATED_AT}
- source_prd: $(relpath "$prd_file")
- source_task_plan: $(relpath "$tasks_file")
- source_backlog: $(relpath "$backlog_file")
- docs_markdown_files: $(file_count "${SOURCE_DIR}")

## Highlights

- PRD title: $(markdown_title "$prd_file")
- Task plan title: $(markdown_title "$tasks_file")
- Backlog title: $(markdown_title "$backlog_file")

## PRD Sections

$(markdown_sections "$prd_file")
EOF
}

architecture_summary() {
  local adr_file architecture_file module_map_file structure_rules_file

  adr_file=$(select_doc \
    "${SOURCE_DIR}/adr/0001-system-architecture.md" \
    "${SOURCE_DIR}/adr/0001-system-architecture.template.md")
  architecture_file=$(select_doc \
    "${SOURCE_DIR}/architecture/architecture.md" \
    "${SOURCE_DIR}/architecture/architecture.template.md")
  module_map_file=$(select_doc \
    "${SOURCE_DIR}/architecture/module-map.md" \
    "${SOURCE_DIR}/architecture/module-map.template.md")
  structure_rules_file=$(select_doc \
    "${SOURCE_DIR}/architecture/STRUCTURE_RULES.md" \
    "${SOURCE_DIR}/architecture/STRUCTURE_RULES.template.md")

  cat > "${TARGET_DIR}/architecture.summary.md" <<EOF
# Architecture Summary

- generated_at: ${GENERATED_AT}
- adr: $(relpath "$adr_file")
- architecture: $(relpath "$architecture_file")
- module_map: $(relpath "$module_map_file")
- structure_rules: $(relpath "$structure_rules_file")

## Architecture Sections

$(markdown_sections "$architecture_file")

## Module Map Sections

$(markdown_sections "$module_map_file")
EOF
}

domain_summary() {
  local domain_file module_map_file

  domain_file=$(select_doc \
    "${SOURCE_DIR}/domain/domain-model.md" \
    "${SOURCE_DIR}/domain/domain-model.template.md")
  module_map_file=$(select_doc \
    "${SOURCE_DIR}/architecture/module-map.md" \
    "${SOURCE_DIR}/architecture/module-map.template.md")

  cat > "${TARGET_DIR}/domain.summary.md" <<EOF
# Domain Summary

- generated_at: ${GENERATED_AT}
- domain_model: $(relpath "$domain_file")
- module_map: $(relpath "$module_map_file")

## Domain Sections

$(markdown_sections "$domain_file")

## Module Inventory Reference

$(markdown_sections "$module_map_file")
EOF
}

api_summary() {
  local api_file interface_spec_file

  api_file=$(select_doc \
    "${SOURCE_DIR}/api/api-contracts.md" \
    "${SOURCE_DIR}/api/api-contracts.template.md")
  interface_spec_file=$(select_doc \
    "${SOURCE_DIR}/specs/api-and-ui-interface.md" \
    "${SOURCE_DIR}/specs/api-and-ui-interface.template.md")

  cat > "${TARGET_DIR}/api.summary.md" <<EOF
# API Summary

- generated_at: ${GENERATED_AT}
- api_contracts: $(relpath "$api_file")
- interface_spec: $(relpath "$interface_spec_file")

## API Contract Sections

$(markdown_sections "$api_file")

## Interface Spec Sections

$(markdown_sections "$interface_spec_file")
EOF
}

frontend_summary() {
  local frontend_architecture_file design_system_file quality_gates_file journeys_file

  frontend_architecture_file=$(select_doc \
    "${SOURCE_DIR}/architecture/frontend-architecture.md" \
    "${SOURCE_DIR}/architecture/frontend-architecture.template.md")
  design_system_file=$(select_doc \
    "${SOURCE_DIR}/specs/design-system.md" \
    "${SOURCE_DIR}/specs/design-system.template.md")
  quality_gates_file=$(select_doc \
    "${SOURCE_DIR}/specs/frontend-quality-gates.md" \
    "${SOURCE_DIR}/specs/frontend-quality-gates.template.md")
  journeys_file=$(select_doc \
    "${SOURCE_DIR}/specs/ux-research-and-journeys.md" \
    "${SOURCE_DIR}/specs/ux-research-and-journeys.template.md")

  cat > "${TARGET_DIR}/frontend.summary.md" <<EOF
# Frontend Summary

- generated_at: ${GENERATED_AT}
- frontend_architecture: $(relpath "$frontend_architecture_file")
- design_system: $(relpath "$design_system_file")
- frontend_quality_gates: $(relpath "$quality_gates_file")
- ux_journeys: $(relpath "$journeys_file")

## Frontend Architecture Sections

$(markdown_sections "$frontend_architecture_file")

## Design System Sections

$(markdown_sections "$design_system_file")
EOF
}

specs_summary() {
  local spec_total
  spec_total=$(find "${SOURCE_DIR}/specs" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' ! -name '*.template.md' | wc -l | tr -d ' ')

  {
    cat <<EOF
# Specs Summary

- generated_at: ${GENERATED_AT}
- spec_files: ${spec_total}
- specs_directory: docs/specs

## Spec Inventory

EOF

    find "${SOURCE_DIR}/specs" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' ! -name '*.template.md' | sort | while read -r spec_file; do
      printf -- "- %s: %s\n" "$(relpath "$spec_file")" "$(markdown_title "$spec_file")"
    done
  } > "${TARGET_DIR}/specs.summary.md"
}

main() {
  [[ -d "$SOURCE_DIR" ]] || fail "missing docs directory: $(relpath "$SOURCE_DIR")"
  [[ -d "${SOURCE_DIR}/specs" ]] || fail "missing specs directory: docs/specs"

  ensure_dir "$TARGET_DIR"

  project_summary
  architecture_summary
  domain_summary
  api_summary
  frontend_summary
  specs_summary

  printf '%s\n' "refreshed ai/context-compressed summaries"
}

main "$@"
