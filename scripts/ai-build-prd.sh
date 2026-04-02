#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
GRAPH_FILE="${REPO_ROOT}/tasks/task-graph.json"
AGENT_FILE="${REPO_ROOT}/ai/agents/prd-writer.md"
PROMPT_FILE="${REPO_ROOT}/ai/prompts/prd-writer.prompt.md"
QUESTIONNAIRE_TEMPLATE="${REPO_ROOT}/docs/prd-questionnaire.template.md"
QUESTIONNAIRE_FILE="${REPO_ROOT}/docs/prd-questionnaire.md"
PRD_TEMPLATE_FILE="${REPO_ROOT}/docs/prd.template.md"
PRD_FILE="${REPO_ROOT}/docs/prd.md"
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ-prd-writer')
BRIEF_FILE="${REPO_ROOT}/runtime/context-cache/${RUN_ID}.brief.md"

fail() {
  printf 'ai-build-prd: %s\n' "$1" >&2
  exit 1
}

ensure_file_from_template() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "$target")"

  if [[ -f "$target" ]]; then
    return 0
  fi

  [[ -f "$source" ]] || fail "missing template file: ${source}"
  cp "$source" "$target"
}

main() {
  [[ -f "$GRAPH_FILE" ]] || fail "missing graph file: ${GRAPH_FILE}"
  [[ -f "$AGENT_FILE" ]] || fail "missing agent file: ${AGENT_FILE}"
  [[ -f "$PROMPT_FILE" ]] || fail "missing prompt file: ${PROMPT_FILE}"
  [[ -n "${AI_STEP_RUNNER_BIN:-}" ]] || fail "AI_STEP_RUNNER_BIN is not configured"

  mkdir -p "${REPO_ROOT}/runtime/context-cache" "${REPO_ROOT}/runtime/logs"

  ensure_file_from_template "$QUESTIONNAIRE_TEMPLATE" "$QUESTIONNAIRE_FILE"
  ensure_file_from_template "$PRD_TEMPLATE_FILE" "$PRD_FILE"

  cat > "$BRIEF_FILE" <<EOF
# Step Brief

- run_id: ${RUN_ID}
- step: prd-writer
- mode: guided-prd-authoring
- source_of_truth: docs/prd.md

## Active Slice

- task_id: prd-authoring
- module: product-definition
- linked_spec: none
- description: Build or refine a detailed PRD from the guided questionnaire and existing repository context.

## Primary Sources

- docs/prd-questionnaire.md
- docs/prd.md
- docs/prd.template.md
- AGENTS.md
- ai/agents/AGENT_RULES.md
- ai/system/operating-model.md
- ai/system/workflow.md
- docs/architecture/architecture.md
- docs/architecture/architecture.template.md
- docs/architecture/module-map.md
- docs/architecture/module-map.template.md
- docs/architecture/STRUCTURE_RULES.md
- docs/architecture/STRUCTURE_RULES.template.md

## Context Accelerators

- ai/context-compressed/project.summary.md
- ai/context-compressed/architecture.summary.md
- ai/context-compressed/specs.summary.md

## Active Module Sources

- docs/prd-questionnaire.md
- docs/prd.md
- docs/architecture/
- ai/context-index/context-map.json
- ai/spec-registry/specs.yaml

## Active Module Code Hints

- docs/
- ai/
EOF

  "${AI_STEP_RUNNER_BIN}" \
    --step prd-writer \
    --agent "$AGENT_FILE" \
    --prompt "$PROMPT_FILE" \
    --repo-root "$REPO_ROOT" \
    --brief "$BRIEF_FILE" \
    --graph "$GRAPH_FILE"
}

main "$@"
