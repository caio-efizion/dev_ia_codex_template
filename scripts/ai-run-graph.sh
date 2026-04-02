#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
GRAPH_FILE="${REPO_ROOT}/tasks/task-graph.json"
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ')
RUNNER_BIN="${AI_STEP_RUNNER_BIN:-${SCRIPT_DIR}/ai-step-runner-codex.sh}"
ENFORCE_PRD_QUALITY="${AI_ENFORCE_PRD_QUALITY:-0}"
PRD_QUALITY_SCORE_FILE="${REPO_ROOT}/docs/audit/prd-score.md"
PRD_MIN_SCORE="${AI_PRD_MIN_SCORE:-80}"
PRD_MIN_READINESS_LEVEL="${AI_PRD_MIN_READINESS_LEVEL:-L4}"
AGENT_STATE_FILE="${REPO_ROOT}/runtime/state/agent-state.md"
PIPELINE_STATUS_FILE="${REPO_ROOT}/runtime/state/pipeline-status.md"
FINGERPRINT_FILE="${REPO_ROOT}/runtime/state/execution-fingerprints.json"
PIPELINE_EVENTS_FILE="${REPO_ROOT}/runtime/logs/pipeline-events.jsonl"
SECURITY_REPORT_ROOT="${REPO_ROOT}/reports/security"
SLICE_REPORT_ROOT="${REPO_ROOT}/reports/slices"
QUALITY_CONFIG_FILE="${AI_QUALITY_CONFIG:-}"
STAGE_MAX_RETRIES="${AI_STAGE_MAX_RETRIES:-2}"
STAGE_RETRY_DELAY_SECONDS="${AI_STAGE_RETRY_DELAY_SECONDS:-1}"
RESUME_FROM_STEP="${AI_RESUME_FROM_STEP:-}"

REQUESTED_STEPS=()
PIPELINE_STEPS=()
EXECUTION_PLAN=()
COMPLETED_STEPS=()
BLOCKERS=()
ACTIVE_AGENTS=()

RUN_STATE="not_started"
CURRENT_STEP="not_started"
EXECUTION_MODE="continuous"
LAST_TASK_ID="null"
LAST_SPEC="null"
LAST_TASK_MODULE="null"
LAST_TASK_FEATURE="null"
LAST_TASK_DESCRIPTION="null"
LAST_TASK_DEPENDENCIES="none"
LAST_TASK_STATUS="null"
RUN_SUMMARY="not_started"
REVIEW_CHECKPOINTS=()
CURRENT_PLANNER_INPUT_FINGERPRINT=""
CURRENT_SPEC_INPUT_FINGERPRINT=""
CURRENT_SPEC_CONTENT_FINGERPRINT=""
CURRENT_CONTEXT_REFRESH_FINGERPRINT=""

fail() {
  printf 'ai-run-graph: %s\n' "$1" >&2
  exit 1
}

timestamp_utc() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

relpath() {
  local path="$1"
  printf '%s\n' "${path#"${REPO_ROOT}/"}"
}

resolve_quality_config() {
  if [[ -n "$QUALITY_CONFIG_FILE" && -f "$QUALITY_CONFIG_FILE" ]]; then
    printf '%s\n' "$QUALITY_CONFIG_FILE"
    return 0
  fi

  if [[ -f "${REPO_ROOT}/quality/pipeline.config.json" ]]; then
    printf '%s\n' "${REPO_ROOT}/quality/pipeline.config.json"
    return 0
  fi

  printf '%s\n' "${REPO_ROOT}/quality/pipeline.config.template.json"
}

security_report_dir() {
  printf '%s\n' "${SECURITY_REPORT_ROOT}/${RUN_ID}"
}

slice_report_dir() {
  local slice_id="$1"
  printf '%s\n' "${SLICE_REPORT_ROOT}/${slice_id}"
}

append_pipeline_event() {
  local step="$1"
  local phase="$2"
  local status="$3"
  local detail="${4:-}"
  local attempt="${5:-1}"

  mkdir -p "$(dirname "$PIPELINE_EVENTS_FILE")"

  node - "$PIPELINE_EVENTS_FILE" "$RUN_ID" "$step" "$phase" "$status" "$detail" "$attempt" "$(timestamp_utc)" <<'NODE'
const fs = require('fs');

const [, , file, runId, step, phase, status, detail, attempt, timestamp] = process.argv;
const event = {
  timestamp,
  run_id: runId,
  step,
  phase,
  status,
  attempt: Number.parseInt(attempt, 10) || 1,
  detail
};

fs.appendFileSync(file, `${JSON.stringify(event)}\n`);
NODE
}

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

readiness_level_rank() {
  case "$1" in
    L4) printf '%s\n' 4 ;;
    L3) printf '%s\n' 3 ;;
    L2) printf '%s\n' 2 ;;
    L1) printf '%s\n' 1 ;;
    *) printf '%s\n' 0 ;;
  esac
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    fail "required command not found in PATH: ${command_name}"
  fi
}

require_file() {
  local path="$1"
  local description="$2"

  if [[ ! -f "$path" ]]; then
    fail "missing ${description}: $(relpath "$path")"
  fi
}

validate_runner_bin() {
  if [[ -z "$RUNNER_BIN" ]]; then
    fail "runner binary is not configured; set AI_STEP_RUNNER_BIN or keep scripts/ai-step-runner-codex.sh available"
  fi

  if [[ "$RUNNER_BIN" == */* ]]; then
    [[ -f "$RUNNER_BIN" ]] || fail "runner binary does not exist: ${RUNNER_BIN}"
    [[ -x "$RUNNER_BIN" ]] || fail "runner binary is not executable: ${RUNNER_BIN}"
    return 0
  fi

  command -v "$RUNNER_BIN" >/dev/null 2>&1 || fail "runner binary not found in PATH: ${RUNNER_BIN}"
}

select_repo_file() {
  local primary="$1"
  local fallback="${2:-}"

  if [[ -f "${REPO_ROOT}/${primary}" ]]; then
    printf '%s\n' "$primary"
  elif [[ -n "$fallback" && -f "${REPO_ROOT}/${fallback}" ]]; then
    printf '%s\n' "$fallback"
  fi
}

repo_file_path() {
  local relative_path="$1"

  if [[ -z "$relative_path" ]]; then
    return 0
  fi

  printf '%s\n' "${REPO_ROOT}/${relative_path}"
}

compute_fingerprint() {
  node - "$@" <<'NODE'
const fs = require('fs');
const crypto = require('crypto');

const args = process.argv.slice(2);
const hash = crypto.createHash('sha256');

for (const arg of args) {
  if (arg.startsWith('text:')) {
    hash.update('text\0');
    hash.update(arg.slice(5));
    hash.update('\0');
    continue;
  }

  hash.update('file\0');
  hash.update(arg);
  hash.update('\0');

  if (fs.existsSync(arg) && fs.statSync(arg).isFile()) {
    hash.update(fs.readFileSync(arg));
  } else {
    hash.update('__missing__');
  }

  hash.update('\0');
}

process.stdout.write(`${hash.digest('hex')}\n`);
NODE
}

contains_step() {
  local needle="$1"
  local item

  for item in "${COMPLETED_STEPS[@]}"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done

  return 1
}

resolve_active_task_id() {
  local backlog_file="${REPO_ROOT}/tasks/backlog.md"
  local task_id=""

  if [[ -f "$backlog_file" ]]; then
    task_id=$(awk -F'`' '/Active task:/ { print $2; exit }' "$backlog_file")
  fi

  printf '%s\n' "${task_id:-null}"
}

resolve_task_spec() {
  local task_id="$1"
  local backlog_file="${REPO_ROOT}/tasks/backlog.md"

  if [[ "$task_id" == "null" || ! -f "$backlog_file" ]]; then
    printf '%s\n' "null"
    return
  fi

  awk -F'|' -v task_id="\`$task_id\`" '
    $2 ~ task_id {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $10)
      gsub(/`/, "", $10)
      print $10
      found = 1
      exit
    }
    END {
      if (!found) {
        print "null"
      }
    }
  ' "$backlog_file"
}

resolve_task_metadata() {
  local task_id="$1"
  local backlog_file="${REPO_ROOT}/tasks/backlog.md"

  if [[ "$task_id" == "null" || "$task_id" == "none" || ! -f "$backlog_file" ]]; then
    printf '%s\n' $'null\tnull\tnull\tnone\tnull\tnull\tnull\tnull'
    return
  fi

  node - "$backlog_file" "$task_id" <<'NODE'
const fs = require('fs');

const [, , backlogFile, taskId] = process.argv;
const lines = fs.readFileSync(backlogFile, 'utf8').split('\n');

for (const line of lines) {
  if (!line.startsWith('|')) {
    continue;
  }

  const columns = line.split('|').slice(1, -1).map((column) => column.trim());
  if (columns.length !== 10 || !/^`.+`$/.test(columns[0])) {
    continue;
  }

  if (columns[0].replace(/`/g, '') !== taskId) {
    continue;
  }

  const normalize = (value) => value.trim().replace(/`/g, '');
  process.stdout.write([
    normalize(columns[2]),
    normalize(columns[3]),
    normalize(columns[4]),
    normalize(columns[5]),
    normalize(columns[6]),
    normalize(columns[7]),
    normalize(columns[8]),
    normalize(columns[9])
  ].join('\t') + '\n');
  process.exit(0);
}

process.stdout.write('null\tnull\tnull\tnone\tnull\tnull\tnull\tnull\n');
NODE
}

resolve_ready_task_id() {
  local backlog_file="${REPO_ROOT}/tasks/backlog.md"

  if [[ ! -f "$backlog_file" ]]; then
    printf '%s\n' "null"
    return
  fi

  node - "$backlog_file" <<'NODE'
const fs = require('fs');

const [, , backlogFile] = process.argv;
const lines = fs.readFileSync(backlogFile, 'utf8').split('\n');
const ready = [];

for (const line of lines) {
  if (!line.startsWith('|')) {
    continue;
  }

  const columns = line.split('|').slice(1, -1).map((column) => column.trim());
  if (columns.length !== 10 || !/^`.+`$/.test(columns[0])) {
    continue;
  }

  if (columns[9] === '`ready`') {
    ready.push(columns[0].replace(/`/g, ''));
  }
}

if (ready.length > 1) {
  console.error(`backlog has more than one ready task: ${ready.join(', ')}`);
  process.exit(1);
}

process.stdout.write(`${ready[0] ?? 'null'}\n`);
NODE
}

resolve_backlog_health() {
  local backlog_file="${REPO_ROOT}/tasks/backlog.md"

  if [[ ! -f "$backlog_file" ]]; then
    printf '%s\n' $'0\t0\t0\tnone'
    return
  fi

  node - "$backlog_file" <<'NODE'
const fs = require('fs');

const [, , backlogFile] = process.argv;
const lines = fs.readFileSync(backlogFile, 'utf8').split('\n');
let readyCount = 0;
let todoCount = 0;
let blockedCount = 0;
let activeTask = 'none';

for (const line of lines) {
  const activeMatch = line.match(/^- Active task:\s+`([^`]+)`/);
  if (activeMatch) {
    activeTask = activeMatch[1];
    continue;
  }

  if (!line.startsWith('|')) {
    continue;
  }

  const columns = line.split('|').slice(1, -1).map((column) => column.trim());
  if (columns.length !== 10 || !/^`.+`$/.test(columns[0])) {
    continue;
  }

  const status = columns[9].replace(/`/g, '');
  if (status === 'ready') {
    readyCount += 1;
  } else if (status === 'todo') {
    todoCount += 1;
  } else if (status === 'blocked') {
    blockedCount += 1;
  }
}

process.stdout.write([readyCount, todoCount, blockedCount, activeTask].join('\t') + '\n');
NODE
}

refresh_task_context() {
  local task_complexity task_type

  LAST_TASK_ID=$(resolve_active_task_id)
  if [[ "$LAST_TASK_ID" == "null" ]]; then
    LAST_TASK_ID=$(resolve_ready_task_id)
  fi

  IFS=$'\t' read -r \
    LAST_TASK_MODULE \
    LAST_TASK_FEATURE \
    LAST_TASK_DESCRIPTION \
    LAST_TASK_DEPENDENCIES \
    task_complexity \
    task_type \
    LAST_SPEC \
    LAST_TASK_STATUS < <(resolve_task_metadata "$LAST_TASK_ID")
}

active_or_ready_slice_exists() {
  local ready_count todo_count blocked_count active_task

  if [[ ! -f "${REPO_ROOT}/tasks/backlog.md" ]]; then
    return 1
  fi

  IFS=$'\t' read -r ready_count todo_count blocked_count active_task < <(resolve_backlog_health)

  if [[ "$active_task" != "none" && "$active_task" != "null" ]]; then
    return 0
  fi

  if (( ready_count > 0 )); then
    return 0
  fi

  return 1
}

active_task_fingerprint_text() {
  cat <<EOF
task_id=${LAST_TASK_ID}
module=${LAST_TASK_MODULE}
feature=${LAST_TASK_FEATURE}
description=${LAST_TASK_DESCRIPTION}
dependencies=${LAST_TASK_DEPENDENCIES}
status=${LAST_TASK_STATUS}
linked_spec=${LAST_SPEC}
EOF
}

planner_input_fingerprint() {
  local prd_file adr_file structure_rules_file architecture_file module_map_file coding_standards_file
  local frontend_architecture_file design_system_file frontend_quality_gates_file ux_journeys_file

  prd_file=$(select_repo_file "docs/prd.md" "docs/prd.template.md")
  adr_file=$(select_repo_file "docs/adr/0001-system-architecture.md" "docs/adr/0001-system-architecture.template.md")
  structure_rules_file=$(select_repo_file "docs/architecture/STRUCTURE_RULES.md" "docs/architecture/STRUCTURE_RULES.template.md")
  architecture_file=$(select_repo_file "docs/architecture/architecture.md" "docs/architecture/architecture.template.md")
  module_map_file=$(select_repo_file "docs/architecture/module-map.md" "docs/architecture/module-map.template.md")
  coding_standards_file=$(select_repo_file "docs/specs/coding-standards.md" "docs/specs/coding-standards.template.md")
  frontend_architecture_file=$(select_repo_file "docs/architecture/frontend-architecture.md" "docs/architecture/frontend-architecture.template.md")
  design_system_file=$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")
  frontend_quality_gates_file=$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")
  ux_journeys_file=$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")

  compute_fingerprint \
    "$(repo_file_path "AGENTS.md")" \
    "$(repo_file_path "ai/agents/AGENT_RULES.md")" \
    "$(repo_file_path "ai/system/operating-model.md")" \
    "$(repo_file_path "ai/system/workflow.md")" \
    "$(repo_file_path "$prd_file")" \
    "$(repo_file_path "$adr_file")" \
    "$(repo_file_path "$structure_rules_file")" \
    "$(repo_file_path "$architecture_file")" \
    "$(repo_file_path "$module_map_file")" \
    "$(repo_file_path "$coding_standards_file")" \
    "$(repo_file_path "$frontend_architecture_file")" \
    "$(repo_file_path "$design_system_file")" \
    "$(repo_file_path "$frontend_quality_gates_file")" \
    "$(repo_file_path "$ux_journeys_file")" \
    "$(repo_file_path "ai/context-index/context-map.json")" \
    "$(repo_file_path "ai/spec-registry/specs.yaml")"
}

spec_input_fingerprint() {
  local prd_file architecture_file module_map_file
  local frontend_architecture_file design_system_file frontend_quality_gates_file ux_journeys_file

  prd_file=$(select_repo_file "docs/prd.md" "docs/prd.template.md")
  architecture_file=$(select_repo_file "docs/architecture/architecture.md" "docs/architecture/architecture.template.md")
  module_map_file=$(select_repo_file "docs/architecture/module-map.md" "docs/architecture/module-map.template.md")
  frontend_architecture_file=$(select_repo_file "docs/architecture/frontend-architecture.md" "docs/architecture/frontend-architecture.template.md")
  design_system_file=$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")
  frontend_quality_gates_file=$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")
  ux_journeys_file=$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")

  compute_fingerprint \
    "text:$(active_task_fingerprint_text)" \
    "$(repo_file_path "$(select_repo_file "tasks/tasks.md" "tasks/tasks.template.md")")" \
    "$(repo_file_path "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")")" \
    "$(repo_file_path "$prd_file")" \
    "$(repo_file_path "$architecture_file")" \
    "$(repo_file_path "$module_map_file")" \
    "$(repo_file_path "$frontend_architecture_file")" \
    "$(repo_file_path "$design_system_file")" \
    "$(repo_file_path "$frontend_quality_gates_file")" \
    "$(repo_file_path "$ux_journeys_file")" \
    "$(repo_file_path "ai/context-index/context-map.json")" \
    "$(repo_file_path "ai/spec-registry/specs.yaml")"
}

spec_content_fingerprint() {
  if [[ "$LAST_SPEC" == "null" || "$LAST_SPEC" == "none" ]]; then
    printf '%s\n' "none"
    return 0
  fi

  compute_fingerprint \
    "text:linked_spec=${LAST_SPEC}" \
    "$(repo_file_path "$LAST_SPEC")"
}

context_refresh_fingerprint() {
  local prd_file adr_file architecture_file module_map_file domain_file api_file interface_spec_file
  local frontend_architecture_file design_system_file frontend_quality_gates_file ux_journeys_file

  prd_file=$(select_repo_file "docs/prd.md" "docs/prd.template.md")
  adr_file=$(select_repo_file "docs/adr/0001-system-architecture.md" "docs/adr/0001-system-architecture.template.md")
  architecture_file=$(select_repo_file "docs/architecture/architecture.md" "docs/architecture/architecture.template.md")
  module_map_file=$(select_repo_file "docs/architecture/module-map.md" "docs/architecture/module-map.template.md")
  domain_file=$(select_repo_file "docs/domain/domain-model.md" "docs/domain/domain-model.template.md")
  api_file=$(select_repo_file "docs/api/api-contracts.md" "docs/api/api-contracts.template.md")
  interface_spec_file=$(select_repo_file "docs/specs/api-and-ui-interface.md" "docs/specs/api-and-ui-interface.template.md")
  frontend_architecture_file=$(select_repo_file "docs/architecture/frontend-architecture.md" "docs/architecture/frontend-architecture.template.md")
  design_system_file=$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")
  frontend_quality_gates_file=$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")
  ux_journeys_file=$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")

  compute_fingerprint \
    "$(repo_file_path "$prd_file")" \
    "$(repo_file_path "$adr_file")" \
    "$(repo_file_path "$architecture_file")" \
    "$(repo_file_path "$module_map_file")" \
    "$(repo_file_path "$domain_file")" \
    "$(repo_file_path "$api_file")" \
    "$(repo_file_path "$interface_spec_file")" \
    "$(repo_file_path "$frontend_architecture_file")" \
    "$(repo_file_path "$design_system_file")" \
    "$(repo_file_path "$frontend_quality_gates_file")" \
    "$(repo_file_path "$ux_journeys_file")" \
    "$(repo_file_path "$(select_repo_file "tasks/tasks.md" "tasks/tasks.template.md")")" \
    "$(repo_file_path "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")")" \
    "$(repo_file_path "ai/context-index/context-map.json")" \
    "$(repo_file_path "ai/spec-registry/specs.yaml")"
}

bootstrap_is_required() {
  local required_path

  for required_path in \
    "docs/prd.md" \
    "tasks/tasks.md" \
    "tasks/backlog.md" \
    "runtime/state/agent-state.md" \
    "ai/context-compressed/project.summary.md" \
    "ai/context-compressed/architecture.summary.md" \
    "ai/context-compressed/domain.summary.md" \
    "ai/context-compressed/api.summary.md" \
    "ai/context-compressed/frontend.summary.md" \
    "ai/context-compressed/specs.summary.md"; do
    if [[ ! -f "${REPO_ROOT}/${required_path}" ]]; then
      return 0
    fi
  done

  return 1
}

context_refresh_is_required() {
  local stored_input_fingerprint=""

  CURRENT_CONTEXT_REFRESH_FINGERPRINT=$(context_refresh_fingerprint)
  stored_input_fingerprint=$(read_step_fingerprint_field "context-refresh" "input_fingerprint")

  if [[ ! -f "${REPO_ROOT}/ai/context-compressed/project.summary.md" ]]; then
    return 0
  fi

  if [[ ! -f "${REPO_ROOT}/ai/context-compressed/frontend.summary.md" ]]; then
    return 0
  fi

  if [[ -z "$stored_input_fingerprint" || "$stored_input_fingerprint" != "$CURRENT_CONTEXT_REFRESH_FINGERPRINT" ]]; then
    return 0
  fi

  return 1
}

ensure_fingerprint_store() {
  mkdir -p "$(dirname "$FINGERPRINT_FILE")"

  if [[ ! -f "$FINGERPRINT_FILE" ]]; then
    printf '%s\n' '{}' > "$FINGERPRINT_FILE"
  fi
}

read_step_fingerprint_field() {
  local step="$1"
  local field="$2"

  ensure_fingerprint_store

  node - "$FINGERPRINT_FILE" "$step" "$field" <<'NODE'
const fs = require('fs');

const [, , file, step, field] = process.argv;
const source = fs.readFileSync(file, 'utf8').trim() || '{}';
const data = JSON.parse(source);
const stepData = data[step];
const value = stepData && Object.prototype.hasOwnProperty.call(stepData, field)
  ? stepData[field]
  : '';

process.stdout.write(`${value}\n`);
NODE
}

short_fingerprint() {
  local value="$1"

  if [[ -z "$value" || "$value" == "none" ]]; then
    printf '%s\n' "$value"
    return 0
  fi

  printf '%.12s\n' "$value"
}

write_step_fingerprint_record() {
  local step="$1"
  local input_fingerprint="$2"
  local spec_fingerprint="$3"
  local status="$4"
  local note="$5"

  ensure_fingerprint_store

  node - "$FINGERPRINT_FILE" "$step" "$input_fingerprint" "$spec_fingerprint" "$status" "$note" "$LAST_TASK_ID" "$LAST_SPEC" "$(timestamp_utc)" <<'NODE'
const fs = require('fs');

const [, , file, step, inputFingerprint, specFingerprint, status, note, taskId, linkedSpec, updatedAt] = process.argv;
const source = fs.readFileSync(file, 'utf8').trim() || '{}';
const data = JSON.parse(source);

data[step] = {
  task_id: taskId,
  linked_spec: linkedSpec,
  input_fingerprint: inputFingerprint,
  spec_fingerprint: specFingerprint,
  status,
  note,
  updated_at: updatedAt
};

fs.writeFileSync(file, `${JSON.stringify(data, null, 2)}\n`);
NODE
}

sync_step_fingerprint_baseline() {
  local step="$1"
  local stored_input_fingerprint="" stored_spec_fingerprint="" note=""

  case "$step" in
    planner)
      if [[ -z "$CURRENT_PLANNER_INPUT_FINGERPRINT" ]]; then
        CURRENT_PLANNER_INPUT_FINGERPRINT=$(planner_input_fingerprint)
      fi

      stored_input_fingerprint=$(read_step_fingerprint_field "planner" "input_fingerprint")

      if [[ -z "$stored_input_fingerprint" ]]; then
        note="initialized planner baseline from current repository state (input $(short_fingerprint "$CURRENT_PLANNER_INPUT_FINGERPRINT"))"
      else
        note="confirmed planner baseline for current repository state (input $(short_fingerprint "$CURRENT_PLANNER_INPUT_FINGERPRINT"))"
      fi

      write_step_fingerprint_record "planner" "$CURRENT_PLANNER_INPUT_FINGERPRINT" "none" "skipped" "$note"
      ;;
    spec-generator)
      if [[ -z "$CURRENT_SPEC_INPUT_FINGERPRINT" ]]; then
        CURRENT_SPEC_INPUT_FINGERPRINT=$(spec_input_fingerprint)
      fi

      if [[ -z "$CURRENT_SPEC_CONTENT_FINGERPRINT" ]]; then
        CURRENT_SPEC_CONTENT_FINGERPRINT=$(spec_content_fingerprint)
      fi

      stored_input_fingerprint=$(read_step_fingerprint_field "spec-generator" "input_fingerprint")
      stored_spec_fingerprint=$(read_step_fingerprint_field "spec-generator" "spec_fingerprint")

      if [[ -z "$stored_input_fingerprint" ]]; then
        note="initialized spec baseline from current working spec (input $(short_fingerprint "$CURRENT_SPEC_INPUT_FINGERPRINT"), spec $(short_fingerprint "$CURRENT_SPEC_CONTENT_FINGERPRINT"))"
      elif [[ "$stored_spec_fingerprint" != "$CURRENT_SPEC_CONTENT_FINGERPRINT" ]]; then
        note="refreshed stored spec fingerprint from current working spec ($(short_fingerprint "$stored_spec_fingerprint") -> $(short_fingerprint "$CURRENT_SPEC_CONTENT_FINGERPRINT"))"
      else
        note="confirmed spec baseline for current active slice (input $(short_fingerprint "$CURRENT_SPEC_INPUT_FINGERPRINT"), spec $(short_fingerprint "$CURRENT_SPEC_CONTENT_FINGERPRINT"))"
      fi

      write_step_fingerprint_record "spec-generator" "$CURRENT_SPEC_INPUT_FINGERPRINT" "$CURRENT_SPEC_CONTENT_FINGERPRINT" "skipped" "$note"
      ;;
  esac
}

record_step_fingerprint_execution() {
  local step="$1"
  local previous_input_fingerprint="" previous_spec_fingerprint=""

  refresh_task_context

  case "$step" in
    planner)
      previous_input_fingerprint=$(read_step_fingerprint_field "planner" "input_fingerprint")
      CURRENT_PLANNER_INPUT_FINGERPRINT=$(planner_input_fingerprint)
      if [[ -n "$previous_input_fingerprint" && "$previous_input_fingerprint" != "$CURRENT_PLANNER_INPUT_FINGERPRINT" ]]; then
        write_step_fingerprint_record "planner" "$CURRENT_PLANNER_INPUT_FINGERPRINT" "none" "executed" "planner reran after planning inputs changed ($(short_fingerprint "$previous_input_fingerprint") -> $(short_fingerprint "$CURRENT_PLANNER_INPUT_FINGERPRINT"))"
      else
        write_step_fingerprint_record "planner" "$CURRENT_PLANNER_INPUT_FINGERPRINT" "none" "executed" "planner updated or confirmed the planning baseline (input $(short_fingerprint "$CURRENT_PLANNER_INPUT_FINGERPRINT"))"
      fi
      ;;
    spec-generator)
      previous_input_fingerprint=$(read_step_fingerprint_field "spec-generator" "input_fingerprint")
      previous_spec_fingerprint=$(read_step_fingerprint_field "spec-generator" "spec_fingerprint")
      CURRENT_SPEC_INPUT_FINGERPRINT=$(spec_input_fingerprint)
      CURRENT_SPEC_CONTENT_FINGERPRINT=$(spec_content_fingerprint)
      if [[ -n "$previous_input_fingerprint" && "$previous_input_fingerprint" != "$CURRENT_SPEC_INPUT_FINGERPRINT" ]]; then
        write_step_fingerprint_record "spec-generator" "$CURRENT_SPEC_INPUT_FINGERPRINT" "$CURRENT_SPEC_CONTENT_FINGERPRINT" "executed" "spec-generator reran after active-slice inputs changed ($(short_fingerprint "$previous_input_fingerprint") -> $(short_fingerprint "$CURRENT_SPEC_INPUT_FINGERPRINT"))"
      elif [[ -n "$previous_spec_fingerprint" && "$previous_spec_fingerprint" != "$CURRENT_SPEC_CONTENT_FINGERPRINT" ]]; then
        write_step_fingerprint_record "spec-generator" "$CURRENT_SPEC_INPUT_FINGERPRINT" "$CURRENT_SPEC_CONTENT_FINGERPRINT" "executed" "spec-generator reran after linked spec content changed ($(short_fingerprint "$previous_spec_fingerprint") -> $(short_fingerprint "$CURRENT_SPEC_CONTENT_FINGERPRINT"))"
      else
        write_step_fingerprint_record "spec-generator" "$CURRENT_SPEC_INPUT_FINGERPRINT" "$CURRENT_SPEC_CONTENT_FINGERPRINT" "executed" "spec-generator updated or confirmed the linked working spec (input $(short_fingerprint "$CURRENT_SPEC_INPUT_FINGERPRINT"), spec $(short_fingerprint "$CURRENT_SPEC_CONTENT_FINGERPRINT"))"
      fi
      ;;
  esac
}

record_context_refresh_fingerprint() {
  local previous_input_fingerprint=""

  if [[ -z "$CURRENT_CONTEXT_REFRESH_FINGERPRINT" ]]; then
    CURRENT_CONTEXT_REFRESH_FINGERPRINT=$(context_refresh_fingerprint)
  fi

  previous_input_fingerprint=$(read_step_fingerprint_field "context-refresh" "input_fingerprint")

  if [[ -n "$previous_input_fingerprint" && "$previous_input_fingerprint" != "$CURRENT_CONTEXT_REFRESH_FINGERPRINT" ]]; then
    write_step_fingerprint_record "context-refresh" "$CURRENT_CONTEXT_REFRESH_FINGERPRINT" "none" "executed" "compressed context summaries were refreshed after source drift ($(short_fingerprint "$previous_input_fingerprint") -> $(short_fingerprint "$CURRENT_CONTEXT_REFRESH_FINGERPRINT"))"
  else
    write_step_fingerprint_record "context-refresh" "$CURRENT_CONTEXT_REFRESH_FINGERPRINT" "none" "executed" "compressed context summaries were refreshed from current durable sources (input $(short_fingerprint "$CURRENT_CONTEXT_REFRESH_FINGERPRINT"))"
  fi
}

record_bootstrap_fingerprint() {
  write_step_fingerprint_record "bootstrap" "not_applicable" "none" "executed" "project bootstrap repaired missing working files or runtime scaffolding"
}

run_bootstrap_and_context_setup() {
  if bootstrap_is_required; then
    bash "${SCRIPT_DIR}/ai-init-project.sh"
    record_bootstrap_fingerprint
    CURRENT_CONTEXT_REFRESH_FINGERPRINT=$(context_refresh_fingerprint)
    record_context_refresh_fingerprint
    return 0
  fi

  if execution_plan_requires_bootstrap; then
    if context_refresh_is_required; then
      bash "${SCRIPT_DIR}/ai-refresh-context.sh"
      record_context_refresh_fingerprint
    fi
  fi

  return 0
}

append_fingerprint_note_to_step_result() {
  local step="$1"
  local note=""
  local log_file="${REPO_ROOT}/runtime/logs/${RUN_ID}-${step}.result.md"

  if [[ ! -f "$log_file" ]]; then
    return 0
  fi

  note=$(read_step_fingerprint_field "$step" "note")

  if [[ -z "$note" ]]; then
    return 0
  fi

  {
    printf '\n## Fingerprint Note\n\n'
    printf -- '- %s\n' "$note"
  } >> "$log_file"
}

spec_file_has_placeholders() {
  local spec_file="$1"
  grep -Eq '\{\{[^}]+\}\}' "$spec_file"
}

source_file_has_placeholders() {
  local source_file="$1"

  if [[ ! -f "$source_file" ]]; then
    return 1
  fi

  grep -Eq '\{\{[^}]+\}\}' "$source_file"
}

read_prd_quality_field() {
  local field="$1"

  if [[ ! -f "$PRD_QUALITY_SCORE_FILE" ]]; then
    printf '%s\n' ""
    return 0
  fi

  node - "$PRD_QUALITY_SCORE_FILE" "$field" <<'NODE'
const fs = require('fs');

const [, , file, field] = process.argv;
const lines = fs.readFileSync(file, 'utf8').split('\n');
const pattern = new RegExp(`^-\\s+${field}:\\s*(.+)$`);

for (const line of lines) {
  const match = line.match(pattern);
  if (!match) {
    continue;
  }

  process.stdout.write(`${match[1].trim().replace(/^`|`$/g, '')}\n`);
  process.exit(0);
}

process.stdout.write('\n');
NODE
}

execution_requires_prd_quality_gate() {
  local step

  if ! is_truthy "$ENFORCE_PRD_QUALITY"; then
    return 1
  fi

  if [[ ${#REQUESTED_STEPS[@]} -eq 0 ]]; then
    return 0
  fi

  for step in "${REQUESTED_STEPS[@]}"; do
    case "$step" in
      planner|spec-generator|prd-writer|prd-reviewer|prd-auditor)
        ;;
      *)
        return 0
        ;;
    esac
  done

  return 1
}

enforce_prd_quality_gate() {
  local readiness_level overall_score ready_for_pipeline readiness_rank minimum_rank

  if ! execution_requires_prd_quality_gate; then
    return 0
  fi

  [[ -f "${REPO_ROOT}/docs/prd.md" ]] || fail "strict PRD quality gate requires docs/prd.md; run make ai-init and build the PRD first"
  [[ -f "$PRD_QUALITY_SCORE_FILE" ]] || fail "strict PRD quality gate requires docs/audit/prd-score.md; run make ai-prd-score first"

  readiness_level=$(read_prd_quality_field "readiness_level")
  overall_score=$(read_prd_quality_field "overall_score")
  ready_for_pipeline=$(read_prd_quality_field "ready_for_pipeline")

  [[ -n "$readiness_level" ]] || fail "strict PRD quality gate could not find readiness_level in $(relpath "$PRD_QUALITY_SCORE_FILE")"
  [[ -n "$overall_score" ]] || fail "strict PRD quality gate could not find overall_score in $(relpath "$PRD_QUALITY_SCORE_FILE")"
  [[ "$overall_score" =~ ^[0-9]+$ ]] || fail "strict PRD quality gate requires overall_score to be an integer in $(relpath "$PRD_QUALITY_SCORE_FILE")"

  readiness_rank=$(readiness_level_rank "$readiness_level")
  minimum_rank=$(readiness_level_rank "$PRD_MIN_READINESS_LEVEL")

  if (( readiness_rank < minimum_rank )); then
    fail "strict PRD quality gate blocked execution: readiness ${readiness_level} is below required ${PRD_MIN_READINESS_LEVEL}; run make ai-prd-review and make ai-prd-score"
  fi

  if (( overall_score < PRD_MIN_SCORE )); then
    fail "strict PRD quality gate blocked execution: PRD score ${overall_score} is below required ${PRD_MIN_SCORE}; improve the PRD and rerun make ai-prd-score"
  fi

  if [[ "$ready_for_pipeline" != "yes" ]]; then
    fail "strict PRD quality gate blocked execution: ready_for_pipeline is '${ready_for_pipeline:-missing}'; review $(relpath "$PRD_QUALITY_SCORE_FILE")"
  fi
}

planner_is_required() {
  local ready_count todo_count blocked_count active_task stored_input_fingerprint

  if [[ ! -f "${REPO_ROOT}/tasks/tasks.md" || ! -f "${REPO_ROOT}/tasks/backlog.md" ]]; then
    return 0
  fi

  if source_file_has_placeholders "${REPO_ROOT}/tasks/tasks.md"; then
    return 0
  fi

  if source_file_has_placeholders "${REPO_ROOT}/tasks/backlog.md"; then
    return 0
  fi

  if source_file_has_placeholders "${REPO_ROOT}/ai/context-index/context-map.json"; then
    return 0
  fi

  if source_file_has_placeholders "${REPO_ROOT}/ai/spec-registry/specs.yaml"; then
    return 0
  fi

  IFS=$'\t' read -r ready_count todo_count blocked_count active_task < <(resolve_backlog_health)

  if (( ready_count > 1 )); then
    return 0
  fi

  if [[ "$LAST_TASK_ID" == "null" || "$LAST_TASK_ID" == "none" ]]; then
    if (( todo_count > 0 )); then
      return 0
    fi

    return 1
  fi

  if [[ "$LAST_TASK_STATUS" == "null" ]]; then
    return 0
  fi

  CURRENT_PLANNER_INPUT_FINGERPRINT=$(planner_input_fingerprint)
  stored_input_fingerprint=$(read_step_fingerprint_field "planner" "input_fingerprint")

  if [[ -n "$stored_input_fingerprint" && "$stored_input_fingerprint" != "$CURRENT_PLANNER_INPUT_FINGERPRINT" ]]; then
    return 0
  fi

  return 1
}

spec_is_required() {
  local spec_path="" stored_task_id="" stored_input_fingerprint=""

  if [[ "$LAST_TASK_ID" == "null" || "$LAST_TASK_ID" == "none" ]]; then
    return 1
  fi

  if [[ "$LAST_SPEC" == "null" || "$LAST_SPEC" == "none" ]]; then
    return 0
  fi

  spec_path="${REPO_ROOT}/${LAST_SPEC}"

  if [[ "$LAST_SPEC" == *.template.md || ! -f "$spec_path" || ! -s "$spec_path" ]]; then
    return 0
  fi

  if spec_file_has_placeholders "$spec_path"; then
    return 0
  fi

  CURRENT_SPEC_INPUT_FINGERPRINT=$(spec_input_fingerprint)
  CURRENT_SPEC_CONTENT_FINGERPRINT=$(spec_content_fingerprint)

  stored_task_id=$(read_step_fingerprint_field "spec-generator" "task_id")
  stored_input_fingerprint=$(read_step_fingerprint_field "spec-generator" "input_fingerprint")

  if [[ -n "$stored_task_id" && "$stored_task_id" != "$LAST_TASK_ID" ]]; then
    return 0
  fi

  if [[ -n "$stored_input_fingerprint" && "$stored_input_fingerprint" != "$CURRENT_SPEC_INPUT_FINGERPRINT" ]]; then
    return 0
  fi

  return 1
}

step_should_run() {
  case "$1" in
    planner)
      planner_is_required
      ;;
    spec-generator)
      spec_is_required
      ;;
    ux-ui-designer|builder|reviewer|tester|frontend-auditor|security)
      active_or_ready_slice_exists
      ;;
    *)
      return 0
      ;;
  esac
}

step_skip_reason() {
  case "$1" in
    planner)
      if source_file_has_placeholders "${REPO_ROOT}/tasks/tasks.md" \
        || source_file_has_placeholders "${REPO_ROOT}/tasks/backlog.md" \
        || source_file_has_placeholders "${REPO_ROOT}/ai/context-index/context-map.json" \
        || source_file_has_placeholders "${REPO_ROOT}/ai/spec-registry/specs.yaml"; then
        printf '%s\n' "planner artifacts still contain template placeholders and must be regenerated from the PRD."
      elif [[ "$LAST_TASK_ID" == "null" || "$LAST_TASK_ID" == "none" ]]; then
        printf '%s\n' "planner artifacts already exist and no additional dependency-safe todo slice remains."
      else
        printf '%s\n' "tasks and backlog artifacts already exist and expose a dependency-safe active slice."
      fi
      ;;
    spec-generator)
      if [[ "$LAST_TASK_ID" == "null" || "$LAST_TASK_ID" == "none" ]]; then
        printf '%s\n' "no active or ready slice remains for specification work."
      else
        printf '%s\n' "linked spec ${LAST_SPEC} already exists for active slice ${LAST_TASK_ID} without unresolved template placeholders."
      fi
      ;;
    ux-ui-designer)
      printf '%s\n' "no active or ready slice remains for UX/UI refinement."
      ;;
    builder)
      printf '%s\n' "no active or ready slice remains for implementation work."
      ;;
    reviewer)
      printf '%s\n' "no active or ready slice remains for review work."
      ;;
    tester)
      printf '%s\n' "no active or ready slice remains for test execution."
      ;;
    frontend-auditor)
      printf '%s\n' "no active or ready slice remains for frontend audit work."
      ;;
    security)
      printf '%s\n' "no active or ready slice remains for final security audit work."
      ;;
    *)
      printf '%s\n' "step already satisfied by current repository state."
      ;;
  esac
}

advance_backlog_state() {
  local backlog_file="${REPO_ROOT}/tasks/backlog.md"

  if [[ ! -f "$backlog_file" ]]; then
    printf '%s\n' "skipped backlog advancement because tasks/backlog.md is missing"
    return 0
  fi

  node - "$backlog_file" <<'NODE'
const fs = require('fs');

const [, , backlogFile] = process.argv;
const source = fs.readFileSync(backlogFile, 'utf8');
const lines = source.split('\n');
const taskRows = [];
let activeTaskLine = -1;
let reasonLine = -1;
let explicitActiveTask = null;

const parseDeps = (raw) => {
  if (raw === 'none') {
    return [];
  }

  return raw
    .split(',')
    .map((entry) => entry.trim().replace(/`/g, ''))
    .filter(Boolean);
};

const formatRow = (columns) => `| ${columns.join(' | ')} |`;

for (let index = 0; index < lines.length; index += 1) {
  const line = lines[index];

  const activeMatch = line.match(/^- Active task:\s+`([^`]+)`/);
  if (activeMatch) {
    activeTaskLine = index;
    explicitActiveTask = activeMatch[1];
    continue;
  }

  if (/^- Reason:/.test(line)) {
    reasonLine = index;
  }

  if (!line.startsWith('|')) {
    continue;
  }

  const columns = line.split('|').slice(1, -1).map((column) => column.trim());
  if (columns.length !== 10 || !/^`.+`$/.test(columns[0])) {
    continue;
  }

  taskRows.push({
    index,
    columns,
    id: columns[0].replace(/`/g, ''),
    dependencies: parseDeps(columns[5]),
    status: columns[9].replace(/`/g, ''),
    module: columns[2]
  });
}

const readyTasks = taskRows.filter((task) => task.status === 'ready');
if (readyTasks.length > 1) {
  console.error(`backlog has more than one ready task: ${readyTasks.map((task) => task.id).join(', ')}`);
  process.exit(1);
}

let currentTask = null;
if (explicitActiveTask) {
  currentTask = taskRows.find((task) => task.id === explicitActiveTask) ?? null;
}

if (!currentTask && readyTasks.length === 1) {
  currentTask = readyTasks[0];
}

if (!currentTask) {
  console.error('cannot advance backlog because there is no active or ready task');
  process.exit(1);
}

currentTask.columns[9] = '`done`';
currentTask.status = 'done';
lines[currentTask.index] = formatRow(currentTask.columns);

const doneTaskIds = new Set(
  taskRows
    .filter((task) => task.status === 'done')
    .map((task) => task.id)
);

let nextTask = null;
for (const task of taskRows) {
  if (task.id === currentTask.id) {
    continue;
  }

  if (task.status !== 'todo') {
    continue;
  }

  const dependenciesSatisfied = task.dependencies.every((dependency) => doneTaskIds.has(dependency));
  if (dependenciesSatisfied) {
    nextTask = task;
    break;
  }
}

if (nextTask) {
  nextTask.columns[9] = '`ready`';
  nextTask.status = 'ready';
  lines[nextTask.index] = formatRow(nextTask.columns);
}

const moduleStates = new Map();
for (const task of taskRows) {
  const state = moduleStates.get(task.module) ?? [];
  state.push(task.status);
  moduleStates.set(task.module, state);
}

for (let index = 0; index < lines.length; index += 1) {
  const line = lines[index];
  if (!line.startsWith('|')) {
    continue;
  }

  const columns = line.split('|').slice(1, -1).map((column) => column.trim());
  if (columns.length !== 2 || columns[0] === 'Module' || /^---+$/.test(columns[0].replace(/ /g, ''))) {
    continue;
  }

  const states = moduleStates.get(columns[0]);
  if (!states || states.length === 0) {
    continue;
  }

  let moduleStatus = 'planned';
  if (states.every((state) => state === 'done')) {
    moduleStatus = 'done';
  } else if (states.includes('ready')) {
    moduleStatus = 'ready';
  } else if (states.includes('blocked')) {
    moduleStatus = 'blocked';
  }

  lines[index] = `| ${columns[0]} | ${moduleStatus} |`;
}

if (activeTaskLine >= 0) {
  lines[activeTaskLine] = nextTask
    ? `- Active task: \`${nextTask.id}\``
    : '- Active task: `none`';
}

if (reasonLine >= 0) {
  lines[reasonLine] = nextTask
    ? `- Reason: task \`${currentTask.id}\` completed and \`${nextTask.id}\` is now the next dependency-safe slice.`
    : `- Reason: task \`${currentTask.id}\` completed and no additional dependency-safe \`todo\` slice remains.`;
}

fs.writeFileSync(backlogFile, lines.join('\n'));
process.stdout.write(`${currentTask.id}->${nextTask ? nextTask.id : 'none'}\n`);
NODE
}

write_list() {
  local label="$1"
  shift

  if [[ $# -eq 0 ]]; then
    printf '%s: []\n' "$label"
    return 0
  fi

  printf '%s:\n' "$label"

  local item
  for item in "$@"; do
    printf '  - %s\n' "$item"
  done
}

write_inline_list() {
  if [[ $# -eq 0 ]]; then
    printf '[]'
    return 0
  fi

  local first=1
  local item

  for item in "$@"; do
    if [[ $first -eq 1 ]]; then
      printf '%s' "$item"
      first=0
    else
      printf ' %s' "$item"
    fi
  done
}

normalize_step() {
  case "$1" in
    planner|plan)
      printf '%s\n' "planner"
      ;;
    spec|spec-generator|specs)
      printf '%s\n' "spec-generator"
      ;;
    ux|ux-ui|ux-ui-designer|designer)
      printf '%s\n' "ux-ui-designer"
      ;;
    builder|build)
      printf '%s\n' "builder"
      ;;
    reviewer|review)
      printf '%s\n' "reviewer"
      ;;
    tester|test)
      printf '%s\n' "tester"
      ;;
    frontend|frontend-auditor|audit-ui)
      printf '%s\n' "frontend-auditor"
      ;;
    security|secure)
      printf '%s\n' "security"
      ;;
    *)
      printf '%s\n' "unsupported graph target: $1" >&2
      exit 1
      ;;
  esac
}

step_requires_mutable_bootstrap() {
  case "$1" in
    planner|spec-generator|ux-ui-designer|builder)
      return 0
      ;;
    reviewer|tester|security)
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

execution_plan_requires_bootstrap() {
  local entry step

  for entry in "${EXECUTION_PLAN[@]}"; do
    IFS=$'\t' read -r step _ <<<"$entry"
    if step_requires_mutable_bootstrap "$step"; then
      return 0
    fi
  done

  return 1
}

inputs_for_step() {
  case "$1" in
    planner)
      cat <<'EOF'
- docs/prd.md
- docs/architecture/
- docs/architecture/frontend-architecture.md
- docs/specs/design-system.md
- docs/specs/frontend-quality-gates.md
- docs/specs/ux-research-and-journeys.md
- ai/context/
- ai/context-index/context-map.json
- ai/spec-registry/specs.yaml
EOF
      ;;
    spec-generator)
      cat <<'EOF'
- tasks/tasks.md
- tasks/backlog.md
- docs/specs/*.template.md
- docs/architecture/frontend-architecture.md
- ai/context-index/context-map.json
EOF
      ;;
    ux-ui-designer)
      cat <<'EOF'
- tasks/backlog.md
- linked spec in docs/specs/
- docs/architecture/frontend-architecture.md
- docs/specs/design-system.md
- docs/specs/frontend-quality-gates.md
- docs/specs/ux-research-and-journeys.md
EOF
      ;;
    builder)
      cat <<'EOF'
- tasks/backlog.md
- docs/specs/
- docs/specs/design-system.md
- docs/specs/frontend-quality-gates.md
- ai/contracts/builder.contract.md
- ai/context-compressed/
EOF
      ;;
    reviewer)
      cat <<'EOF'
- changed implementation files
- ai/prompts/reviewer.prompt.md
- ai/context-index/context-map.json
- ai/spec-registry/specs.yaml
- docs/specs/design-system.md
- docs/specs/frontend-quality-gates.md
EOF
      ;;
    tester)
      cat <<'EOF'
- changed implementation files
- docs/testing/test-plan.md
- docs/specs/frontend-quality-gates.md
- quality/pipeline.config.json
- ai/prompts/tester.prompt.md
- ai/context-compressed/
EOF
      ;;
    frontend-auditor)
      cat <<'EOF'
- changed implementation files
- linked spec in docs/specs/
- docs/architecture/frontend-architecture.md
- docs/specs/design-system.md
- docs/specs/frontend-quality-gates.md
- docs/specs/ux-research-and-journeys.md
- docs/testing/test-plan.md
- runtime/logs/test-report.md
- reports/slices/<slice-id>/
EOF
      ;;
    security)
      cat <<'EOF'
- changed implementation files
- ai/context/security-context.md
- ai/context/tenancy-context.md
- security/security-policy.md
- ai/prompts/security.prompt.md
EOF
      ;;
  esac
}

outputs_for_step() {
  case "$1" in
    planner)
      cat <<'EOF'
- tasks/tasks.md
- tasks/backlog.md
EOF
      ;;
    spec-generator)
      cat <<'EOF'
- docs/specs/
- ai/spec-registry/specs.yaml
- ai/context-index/context-map.json
EOF
      ;;
    ux-ui-designer)
      cat <<'EOF'
- linked spec with refined UI/UX requirements
- runtime/logs/ux-ui-designer-report.md
EOF
      ;;
    builder)
      cat <<'EOF'
- source implementation
- tests
- updated docs when contracts, APIs, or schemas change
EOF
      ;;
    reviewer)
      cat <<'EOF'
- runtime/logs/reviewer-report.md
EOF
      ;;
    tester)
      cat <<'EOF'
- runtime/logs/test-report.md
- reports/slices/<slice-id>/quality-gates.md
- reports/slices/<slice-id>/frontend-evidence.md
EOF
      ;;
    frontend-auditor)
      cat <<'EOF'
- runtime/logs/frontend-auditor-report.md
- reports/slices/<slice-id>/frontend-evidence-summary.json
EOF
      ;;
    security)
      cat <<'EOF'
- runtime/logs/security-report.md
- reports/security/<run-id>/
EOF
      ;;
  esac
}

resolve_execution_plan() {
  node - "$GRAPH_FILE" "$REPO_ROOT" "${REQUESTED_STEPS[@]}" <<'NODE'
const fs = require('fs');
const path = require('path');

const [, , graphFile, repoRoot, ...targets] = process.argv;
const raw = fs.readFileSync(graphFile, 'utf8');
let graph;

try {
  graph = JSON.parse(raw);
} catch (error) {
  console.error(`invalid graph json: ${error.message}`);
  process.exit(1);
}

if (!graph || !Array.isArray(graph.nodes) || !Array.isArray(graph.edges)) {
  console.error('graph must contain nodes[] and edges[]');
  process.exit(1);
}

const nodes = graph.nodes;
const edges = graph.edges;
const nodeMap = new Map();
const nodeOrder = new Map();

for (const [index, node] of nodes.entries()) {
  if (!node || typeof node.id !== 'string' || node.id.length === 0) {
    console.error('every node must have a non-empty string id');
    process.exit(1);
  }

  if (nodeMap.has(node.id)) {
    console.error(`duplicate node id: ${node.id}`);
    process.exit(1);
  }

  if (typeof node.agent !== 'string' || node.agent.length === 0) {
    console.error(`node ${node.id} must define agent`);
    process.exit(1);
  }

  if (typeof node.prompt !== 'string' || node.prompt.length === 0) {
    console.error(`node ${node.id} must define prompt`);
    process.exit(1);
  }

  const agentPath = path.join(repoRoot, 'ai', 'agents', `${node.agent}.md`);
  const promptPath = path.join(repoRoot, node.prompt);

  if (!fs.existsSync(agentPath)) {
    console.error(`node ${node.id} references missing agent file: ${path.relative(repoRoot, agentPath)}`);
    process.exit(1);
  }

  if (!fs.existsSync(promptPath)) {
    console.error(`node ${node.id} references missing prompt file: ${path.relative(repoRoot, promptPath)}`);
    process.exit(1);
  }

  nodeMap.set(node.id, {
    id: node.id,
    agent: node.agent,
    prompt: node.prompt,
    agentPath,
    promptPath
  });
  nodeOrder.set(node.id, index);
}

const adjacency = new Map();
const reverseAdjacency = new Map();
const indegree = new Map();

for (const nodeId of nodeMap.keys()) {
  adjacency.set(nodeId, []);
  reverseAdjacency.set(nodeId, []);
  indegree.set(nodeId, 0);
}

for (const edge of edges) {
  if (!edge || typeof edge.from !== 'string' || typeof edge.to !== 'string') {
    console.error('every edge must define string from and to fields');
    process.exit(1);
  }

  if (!nodeMap.has(edge.from) || !nodeMap.has(edge.to)) {
    console.error(`edge references unknown node: ${edge.from} -> ${edge.to}`);
    process.exit(1);
  }

  if (edge.from === edge.to) {
    console.error(`self-cycle is not allowed: ${edge.from}`);
    process.exit(1);
  }

  adjacency.get(edge.from).push(edge.to);
  reverseAdjacency.get(edge.to).push(edge.from);
  indegree.set(edge.to, indegree.get(edge.to) + 1);
}

const available = [];
for (const nodeId of nodeMap.keys()) {
  if (indegree.get(nodeId) === 0) {
    available.push(nodeId);
  }
}

available.sort((a, b) => nodeOrder.get(a) - nodeOrder.get(b));

const topo = [];
while (available.length > 0) {
  const current = available.shift();
  topo.push(current);

  for (const next of adjacency.get(current)) {
    indegree.set(next, indegree.get(next) - 1);
    if (indegree.get(next) === 0) {
      available.push(next);
      available.sort((a, b) => nodeOrder.get(a) - nodeOrder.get(b));
    }
  }
}

if (topo.length !== nodes.length) {
  console.error('task graph contains a cycle and cannot be executed');
  process.exit(1);
}

const selected = new Set();
const auditOnlyTargets = new Set(['reviewer', 'tester', 'frontend-auditor', 'security']);

if (targets.length === 0) {
  for (const nodeId of topo) {
    selected.add(nodeId);
  }
} else {
  for (const target of targets) {
    if (!nodeMap.has(target)) {
      console.error(`requested node is not in the graph: ${target}`);
      process.exit(1);
    }
  }

  const useExactTargets = targets.every((target) => auditOnlyTargets.has(target));

  if (useExactTargets) {
    for (const target of targets) {
      selected.add(target);
    }
  } else {
    const stack = [...targets];
    while (stack.length > 0) {
      const current = stack.pop();
      if (selected.has(current)) {
        continue;
      }

      selected.add(current);
      for (const dependency of reverseAdjacency.get(current)) {
        stack.push(dependency);
      }
    }
  }
}

for (const nodeId of topo) {
  if (selected.has(nodeId)) {
    const node = nodeMap.get(nodeId);
    process.stdout.write(
      `${node.id}\t${node.agent}\t${path.relative(repoRoot, node.agentPath)}\t${path.relative(repoRoot, node.promptPath)}\n`
    );
  }
}
NODE
}

write_status() {
  local pending_steps=()
  local step

  refresh_task_context

  for step in "${PIPELINE_STEPS[@]}"; do
    if ! contains_step "$step"; then
      pending_steps+=("$step")
    fi
  done

  {
    printf 'run_id: %s\n' "$RUN_ID"
    printf 'run_state: %s\n' "$RUN_STATE"
    printf 'current_step: %s\n' "$CURRENT_STEP"
    printf 'graph_file: %s\n' "tasks/task-graph.json"
    printf 'execution_mode: %s\n' "$EXECUTION_MODE"
    printf 'resume_from_step: %s\n' "${RESUME_FROM_STEP:-none}"
    printf 'stage_max_retries: %s\n' "$STAGE_MAX_RETRIES"
    printf 'runner_bin: %s\n' "${RUNNER_BIN:-not_configured}"
    printf 'agent_state_file: %s\n' "runtime/state/agent-state.md"
    printf 'fingerprint_file: %s\n' "runtime/state/execution-fingerprints.json"
    printf 'last_task_id: %s\n' "$LAST_TASK_ID"
    printf 'last_spec: %s\n' "$LAST_SPEC"
    printf 'steps: %s\n' "${PIPELINE_STEPS[*]}"
    printf 'completed_steps: '
    write_inline_list "${COMPLETED_STEPS[@]}"
    printf '\n'
    printf 'pending_steps: '
    write_inline_list "${pending_steps[@]}"
    printf '\n'
    printf 'last_updated: %s\n' "$(timestamp_utc)"
  } > "$PIPELINE_STATUS_FILE"
}

write_agent_state() {
  local pending_steps=()
  local step

  refresh_task_context

  for step in "${PIPELINE_STEPS[@]}"; do
    if ! contains_step "$step"; then
      pending_steps+=("$step")
    fi
  done

  {
    printf 'run_id: %s\n' "$RUN_ID"
    printf 'run_state: %s\n' "$RUN_STATE"
    printf 'current_step: %s\n' "$CURRENT_STEP"
    printf 'graph_file: %s\n' "tasks/task-graph.json"
    printf 'execution_mode: %s\n' "$EXECUTION_MODE"
    printf 'resume_from_step: %s\n' "${RESUME_FROM_STEP:-none}"
    printf 'stage_max_retries: %s\n' "$STAGE_MAX_RETRIES"
    printf 'runner_bin: %s\n' "${RUNNER_BIN:-not_configured}"
    printf 'fingerprint_file: %s\n' "runtime/state/execution-fingerprints.json"
    printf 'steps: %s\n' "${PIPELINE_STEPS[*]}"
    write_list "completed_steps" "${COMPLETED_STEPS[@]}"
    write_list "pending_steps" "${pending_steps[@]}"
    write_list "active_agents" "${ACTIVE_AGENTS[@]}"
    printf 'last_task_id: %s\n' "$LAST_TASK_ID"
    printf 'last_spec: %s\n' "$LAST_SPEC"
    write_list "blockers" "${BLOCKERS[@]}"
    printf 'run_summary: %s\n' "$RUN_SUMMARY"
    printf 'last_updated: %s\n' "$(timestamp_utc)"
  } > "$AGENT_STATE_FILE"
}

write_runtime_state() {
  mkdir -p "$(dirname "$AGENT_STATE_FILE")"
  write_agent_state
  write_status
}

write_graph_plan() {
  local plan_file="${REPO_ROOT}/runtime/graphs/execution-plan-${RUN_ID}.md"
  {
    cat <<EOF
# Graph Execution Plan

- run_id: ${RUN_ID}
- graph: tasks/task-graph.json
- runner_bin: ${RUNNER_BIN:-not_configured}
- execution_mode: ${EXECUTION_MODE}
- resume_from_step: ${RESUME_FROM_STEP:-none}
- stage_max_retries: ${STAGE_MAX_RETRIES}

## Ordered Steps

EOF

    local step
    for step in "${PIPELINE_STEPS[@]}"; do
      printf -- "- %s\n" "$step"
    done
  } > "$plan_file"
}

collect_changed_source_files() {
  if ! command -v git >/dev/null 2>&1; then
    return 0
  fi

  git -C "$REPO_ROOT" status --short --untracked-files=no 2>/dev/null | awk '
    {
      path = $NF
      if (path ~ /^runtime\//) {
        next
      }
      print path
    }
  '
}

write_cycle_review() {
  local cycle="$1"
  local transition="$2"
  local current_task="${transition%%->*}"
  local next_task="${transition##*->}"
  local checkpoint_file="${REPO_ROOT}/runtime/logs/review-checkpoint-${RUN_ID}-cycle-${cycle}.md"
  local changed_files=()
  local file

  while IFS= read -r file; do
    if [[ -n "$file" ]]; then
      changed_files+=("$file")
    fi
  done < <(collect_changed_source_files)

  {
    cat <<EOF
# Review Checkpoint

- run_id: ${RUN_ID}
- cycle: ${cycle}
- execution_mode: ${EXECUTION_MODE}
- completed_task: ${current_task}
- next_task: ${next_task}
- reviewer_report: runtime/logs/reviewer-report.md
- tester_report: runtime/logs/test-report.md
- security_report: runtime/logs/security-report.md

## Backlog Transition

- advanced: \`${current_task}\`
EOF

    if [[ "$next_task" == "none" ]]; then
      printf -- '- next_ready: none\n'
    else
      printf -- '- next_ready: `%s`\n' "$next_task"
    fi

    cat <<'EOF'

## Source Changes

EOF

    if [[ ${#changed_files[@]} -eq 0 ]]; then
      printf -- '- no durable source-file changes detected outside runtime/\n'
    else
      for file in "${changed_files[@]}"; do
        printf -- '- %s\n' "$file"
      done
    fi
  } > "$checkpoint_file"

  REVIEW_CHECKPOINTS+=("runtime/logs/$(basename "$checkpoint_file")")
}

compact_review_checkpoints() {
  local max_keep=6
  local archive_file=""
  local archive_relative=""
  local keep_start=0
  local index=0
  local archived=()
  local retained=()
  local live_checkpoints=()
  local checkpoint=""

  archive_file="${REPO_ROOT}/runtime/logs/review-checkpoint-${RUN_ID}-archive.md"
  archive_relative="runtime/logs/$(basename "$archive_file")"

  for checkpoint in "${REVIEW_CHECKPOINTS[@]}"; do
    if [[ "$checkpoint" == "$archive_relative" ]]; then
      continue
    fi

    live_checkpoints+=("$checkpoint")
  done

  if (( ${#live_checkpoints[@]} <= max_keep )); then
    if [[ -f "$archive_file" ]]; then
      REVIEW_CHECKPOINTS=("$archive_relative" "${live_checkpoints[@]}")
    else
      REVIEW_CHECKPOINTS=("${live_checkpoints[@]}")
    fi
    return 0
  fi

  keep_start=$((${#live_checkpoints[@]} - max_keep))

  for ((index = 0; index < ${#live_checkpoints[@]}; index += 1)); do
    if (( index < keep_start )); then
      archived+=("${live_checkpoints[index]}")
    else
      retained+=("${live_checkpoints[index]}")
    fi
  done

  if [[ ! -f "$archive_file" ]]; then
    cat > "$archive_file" <<EOF
# Review Checkpoint Archive

- run_id: ${RUN_ID}

## Archived Entries

EOF
  fi

  {
    printf -- '\n## Archive Update\n\n'
    printf -- '- appended_at: %s\n' "$(timestamp_utc)"
    printf -- '- newly_archived: %d\n' "${#archived[@]}"
    printf -- '- retained_live_checkpoints: %d\n\n' "${#retained[@]}"

    for index in "${!archived[@]}"; do
      printf -- "- %s\n" "${archived[index]}"
    done
  } >> "$archive_file"

  for index in "${!archived[@]}"; do
    rm -f "${REPO_ROOT}/${archived[index]}"
  done

  REVIEW_CHECKPOINTS=("$archive_relative" "${retained[@]}")
}

write_run_log() {
  local log_file="${REPO_ROOT}/runtime/logs/pipeline-${RUN_ID}.md"
  {
    cat <<EOF
# AI Pipeline Run

- run_id: ${RUN_ID}
- graph: tasks/task-graph.json
- run_state: ${RUN_STATE}
- steps: ${PIPELINE_STEPS[*]}
- runner_bin: ${RUNNER_BIN:-not_configured}
- last_task_id: ${LAST_TASK_ID}
- last_spec: ${LAST_SPEC}

## Step Briefs

EOF

    local step
    for step in "${PIPELINE_STEPS[@]}"; do
      printf -- "- runtime/context-cache/%s-%s.brief.md\n" "${RUN_ID}" "${step}"
    done

    cat <<'EOF'

## Review Checkpoints

EOF

    if [[ ${#REVIEW_CHECKPOINTS[@]} -eq 0 ]]; then
      printf -- "- none\n"
    else
      local checkpoint
      for checkpoint in "${REVIEW_CHECKPOINTS[@]}"; do
        printf -- "- %s\n" "$checkpoint"
      done
    fi
  } > "$log_file"
}

write_repo_path_line() {
  local path="$1"

  if [[ -z "$path" || "$path" == "null" || "$path" == "none" ]]; then
    return 0
  fi

  if [[ -f "${REPO_ROOT}/${path}" ]]; then
    printf -- "- %s\n" "$path"
  else
    printf -- "- %s (missing)\n" "$path"
  fi
}

write_changed_file_snapshot() {
  local limit="${1:-12}"
  local total=0
  local displayed=0
  local file

  while IFS= read -r file; do
    if [[ -z "$file" ]]; then
      continue
    fi

    total=$((total + 1))

    if (( displayed < limit )); then
      printf -- "- %s\n" "$file"
      displayed=$((displayed + 1))
    fi
  done < <(collect_changed_source_files)

  if (( total == 0 )); then
    printf -- "- none outside runtime/\n"
  elif (( total > limit )); then
    printf -- "- ... plus %d more changed paths\n" "$((total - limit))"
  fi
}

latest_review_checkpoint() {
  local checkpoints=()
  local latest=""

  shopt -s nullglob
  checkpoints=("${REPO_ROOT}"/runtime/logs/review-checkpoint-*.md)
  shopt -u nullglob

  if (( ${#checkpoints[@]} == 0 )); then
    printf '%s\n' "none"
    return 0
  fi

  latest=$(printf '%s\n' "${checkpoints[@]}" | sort | tail -n 1)
  printf '%s\n' "$(relpath "$latest")"
}

write_active_module_code_hints() {
  if [[ "$LAST_TASK_MODULE" == "null" || ! -f "${REPO_ROOT}/docs/architecture/module-map.md" ]]; then
    printf -- "- none resolved from docs/architecture/module-map.md\n"
    return 0
  fi

  node - "${REPO_ROOT}/docs/architecture/module-map.md" "$LAST_TASK_MODULE" <<'NODE'
const fs = require('fs');

const [, , moduleMapFile, moduleName] = process.argv;
const lines = fs.readFileSync(moduleMapFile, 'utf8').split('\n');
const row = lines.find((line) => line.startsWith('|') && line.includes(`| ${moduleName} |`));

if (!row) {
  process.stdout.write('- none resolved from docs/architecture/module-map.md\n');
  process.exit(0);
}

const columns = row.split('|').slice(1, -1).map((column) => column.trim());
const trustedWritePaths = columns[3] || '';
const hints = trustedWritePaths
  .split(',')
  .map((entry) => entry.trim().replace(/`/g, ''))
  .filter(Boolean);

if (hints.length === 0) {
  process.stdout.write('- none resolved from docs/architecture/module-map.md\n');
  process.exit(0);
}

for (const hint of hints) {
  process.stdout.write(`- ${hint}\n`);
}
NODE
}

write_active_module_sources() {
  if [[ "$LAST_TASK_MODULE" == "null" || ! -f "${REPO_ROOT}/ai/context-index/context-map.json" ]]; then
    printf -- "- none resolved from ai/context-index/context-map.json\n"
    return 0
  fi

  node - "${REPO_ROOT}/ai/context-index/context-map.json" "$LAST_TASK_MODULE" <<'NODE'
const fs = require('fs');

const [, , contextMapFile, moduleName] = process.argv;
const source = fs.readFileSync(contextMapFile, 'utf8');
const data = JSON.parse(source);
const specs = new Map((data.specs || []).map((entry) => [entry.id, entry.path]));
const apis = new Map((data.apis || []).map((entry) => [entry.id, entry.path]));
const schemas = new Map((data.schemas || []).map((entry) => [entry.id, entry.path]));
const moduleEntry = (data.modules || []).find((entry) => entry.name === moduleName);

if (!moduleEntry) {
  process.stdout.write('- none resolved from ai/context-index/context-map.json\n');
  process.exit(0);
}

const ordered = [];
const seen = new Set();

for (const specId of moduleEntry.specs || []) {
  const path = specs.get(specId);
  if (path && !seen.has(path)) {
    seen.add(path);
    ordered.push(path);
  }
}

for (const apiId of moduleEntry.apis || []) {
  const path = apis.get(apiId);
  if (path && !seen.has(path)) {
    seen.add(path);
    ordered.push(path);
  }
}

for (const schemaId of moduleEntry.schemas || []) {
  const path = schemas.get(schemaId);
  if (path && !seen.has(path)) {
    seen.add(path);
    ordered.push(path);
  }
}

if (ordered.length === 0) {
  process.stdout.write('- none resolved from ai/context-index/context-map.json\n');
  process.exit(0);
}

for (const path of ordered) {
  process.stdout.write(`- ${path}\n`);
}
NODE
}

write_step_primary_sources() {
  local step="$1"
  local agent_file="$2"
  local prompt_file="$3"

  write_repo_path_line "$agent_file"
  write_repo_path_line "$prompt_file"
  write_repo_path_line "ai/agents/AGENT_RULES.md"
  write_repo_path_line "security/security-policy.md"
  write_repo_path_line "$(relpath "$(guard_file_for_step "$step")")"
  write_repo_path_line "$(relpath "$(resolve_quality_config)")"

  case "$step" in
    planner)
      write_repo_path_line "ai/contracts/planner.contract.md"
      write_repo_path_line "$(select_repo_file "tasks/tasks.md" "tasks/tasks.template.md")"
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$(select_repo_file "docs/prd.md" "docs/prd.template.md")"
      write_repo_path_line "$(select_repo_file "docs/architecture/architecture.md" "docs/architecture/architecture.template.md")"
      write_repo_path_line "$(select_repo_file "docs/architecture/frontend-architecture.md" "docs/architecture/frontend-architecture.template.md")"
      write_repo_path_line "$(select_repo_file "docs/architecture/module-map.md" "docs/architecture/module-map.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")"
      write_repo_path_line "ai/context-index/context-map.json"
      write_repo_path_line "ai/spec-registry/specs.yaml"
      ;;
    spec-generator)
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$(select_repo_file "tasks/tasks.md" "tasks/tasks.template.md")"
      write_repo_path_line "$(select_repo_file "docs/architecture/frontend-architecture.md" "docs/architecture/frontend-architecture.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")"
      write_repo_path_line "ai/context-index/context-map.json"
      write_repo_path_line "ai/spec-registry/specs.yaml"
      write_repo_path_line "$LAST_SPEC"
      ;;
    ux-ui-designer)
      write_repo_path_line "ai/contracts/ux-ui-designer.contract.md"
      write_repo_path_line "skills/efizion-frontend-excellence/SKILL.md"
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$LAST_SPEC"
      write_repo_path_line "$(select_repo_file "docs/architecture/frontend-architecture.md" "docs/architecture/frontend-architecture.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")"
      ;;
    builder)
      write_repo_path_line "ai/contracts/builder.contract.md"
      write_repo_path_line "skills/efizion-frontend-excellence/SKILL.md"
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$LAST_SPEC"
      write_repo_path_line "$(select_repo_file "docs/specs/coding-standards.md" "docs/specs/coding-standards.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")"
      write_repo_path_line "$(select_repo_file "docs/architecture/module-map.md" "docs/architecture/module-map.template.md")"
      ;;
    reviewer)
      write_repo_path_line "ai/contracts/reviewer.contract.md"
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$LAST_SPEC"
      write_repo_path_line "$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")"
      write_repo_path_line "ai/context-index/context-map.json"
      write_repo_path_line "ai/spec-registry/specs.yaml"
      ;;
    tester)
      write_repo_path_line "ai/contracts/tester.contract.md"
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$LAST_SPEC"
      write_repo_path_line "$(select_repo_file "docs/testing/test-plan.md" "docs/testing/test-plan.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")"
      ;;
    frontend-auditor)
      write_repo_path_line "ai/contracts/frontend-auditor.contract.md"
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$LAST_SPEC"
      write_repo_path_line "$(select_repo_file "docs/architecture/frontend-architecture.md" "docs/architecture/frontend-architecture.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/design-system.md" "docs/specs/design-system.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/frontend-quality-gates.md" "docs/specs/frontend-quality-gates.template.md")"
      write_repo_path_line "$(select_repo_file "docs/specs/ux-research-and-journeys.md" "docs/specs/ux-research-and-journeys.template.md")"
      write_repo_path_line "$(select_repo_file "docs/testing/test-plan.md" "docs/testing/test-plan.template.md")"
      ;;
    security)
      write_repo_path_line "ai/contracts/security.contract.md"
      write_repo_path_line "$(select_repo_file "tasks/backlog.md" "tasks/backlog.template.md")"
      write_repo_path_line "$LAST_SPEC"
      write_repo_path_line "ai/context/security-context.md"
      write_repo_path_line "ai/context/tenancy-context.md"
      ;;
  esac
}

write_step_context_accelerators() {
  local step="$1"

  case "$step" in
    planner)
      write_repo_path_line "ai/context-compressed/project.summary.md"
      write_repo_path_line "ai/context-compressed/architecture.summary.md"
      write_repo_path_line "ai/context-compressed/frontend.summary.md"
      ;;
    spec-generator)
      write_repo_path_line "ai/context-compressed/specs.summary.md"
      write_repo_path_line "ai/context-compressed/architecture.summary.md"
      write_repo_path_line "ai/context-compressed/frontend.summary.md"
      ;;
    ux-ui-designer)
      write_repo_path_line "ai/context-compressed/frontend.summary.md"
      write_repo_path_line "ai/context-compressed/specs.summary.md"
      ;;
    builder)
      write_repo_path_line "ai/context-compressed/project.summary.md"
      write_repo_path_line "ai/context-compressed/architecture.summary.md"
      write_repo_path_line "ai/context-compressed/api.summary.md"
      write_repo_path_line "ai/context-compressed/frontend.summary.md"
      ;;
    reviewer)
      write_repo_path_line "ai/context-compressed/architecture.summary.md"
      write_repo_path_line "ai/context-compressed/specs.summary.md"
      write_repo_path_line "ai/context-compressed/frontend.summary.md"
      ;;
    tester)
      write_repo_path_line "ai/context-compressed/api.summary.md"
      write_repo_path_line "ai/context-compressed/specs.summary.md"
      write_repo_path_line "ai/context-compressed/frontend.summary.md"
      ;;
    frontend-auditor)
      write_repo_path_line "ai/context-compressed/frontend.summary.md"
      write_repo_path_line "ai/context-compressed/specs.summary.md"
      ;;
    security)
      write_repo_path_line "ai/context-compressed/architecture.summary.md"
      write_repo_path_line "ai/context-compressed/domain.summary.md"
      ;;
  esac
}

write_step_brief() {
  local step="$1"
  local agent_file="$2"
  local prompt_file="$3"
  local brief_file="$4"
  local latest_checkpoint

  latest_checkpoint=$(latest_review_checkpoint)

  {
    cat <<EOF
# Pipeline Step Brief

- run_id: ${RUN_ID}
- step: ${step}
- agent: ${agent_file}
- prompt: ${prompt_file}
- graph: tasks/task-graph.json

## Active Slice

- task_id: ${LAST_TASK_ID}
- module: ${LAST_TASK_MODULE}
- feature: ${LAST_TASK_FEATURE}
- status: ${LAST_TASK_STATUS}
- dependencies: ${LAST_TASK_DEPENDENCIES}
- linked_spec: ${LAST_SPEC}
- description: ${LAST_TASK_DESCRIPTION}

## Primary Sources

EOF

    write_step_primary_sources "$step" "$agent_file" "$prompt_file"

    cat <<'EOF'

## Active Module Sources

EOF

    write_active_module_sources

    cat <<'EOF'

## Active Module Code Hints

EOF

    write_active_module_code_hints

    cat <<'EOF'

## Context Accelerators

EOF

    write_step_context_accelerators "$step"

    cat <<EOF

## Resume Context

- runtime/state/agent-state.md
- runtime/state/execution-fingerprints.json
- latest_review_checkpoint: ${latest_checkpoint}

## Inputs

$(inputs_for_step "$step")

## Expected Outputs

$(outputs_for_step "$step")
EOF

    case "$step" in
      reviewer|tester|frontend-auditor|security)
        cat <<'EOF'

## Working Tree Snapshot

EOF
        write_changed_file_snapshot 12
        ;;
    esac
  } > "$brief_file"
}

write_skipped_step_result() {
  local step="$1"
  local brief_file="$2"
  local reason="$3"
  local log_file="${REPO_ROOT}/runtime/logs/${RUN_ID}-${step}.result.md"

  cat > "$log_file" <<EOF
# Pipeline Step Result

- run_id: ${RUN_ID}
- step: ${step}
- status: skipped
- active_task: ${LAST_TASK_ID}
- linked_spec: ${LAST_SPEC}
- brief: $(relpath "$brief_file")

## Reason

- ${reason}
EOF
}

guard_file_for_step() {
  case "$1" in
    planner)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/planner.guard.md"
      ;;
    spec-generator)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/spec-generator.guard.md"
      ;;
    ux-ui-designer)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/ux-ui-designer.guard.md"
      ;;
    builder)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/builder.guard.md"
      ;;
    reviewer)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/reviewer.guard.md"
      ;;
    tester)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/tester.guard.md"
      ;;
    frontend-auditor)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/frontend-auditor.guard.md"
      ;;
    security)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/security.guard.md"
      ;;
    *)
      printf '%s\n' "${REPO_ROOT}/security/agent-guards/orchestrator.guard.md"
      ;;
  esac
}

write_worktree_snapshot() {
  local target_file="$1"

  if command -v git >/dev/null 2>&1; then
    git -C "$REPO_ROOT" status --porcelain=v1 --untracked-files=all > "$target_file"
  else
    : > "$target_file"
  fi
}

diff_worktree_snapshots() {
  local before_file="$1"
  local after_file="$2"
  local output_file="$3"

  node - "$before_file" "$after_file" "$output_file" <<'NODE'
const fs = require('fs');

const [, , beforeFile, afterFile, outputFile] = process.argv;

function parseSnapshot(file) {
  const map = new Map();
  if (!fs.existsSync(file)) {
    return map;
  }

  const lines = fs.readFileSync(file, 'utf8').split('\n').filter(Boolean);
  for (const line of lines) {
    const cleaned = line.trim();
    if (!cleaned) continue;
    const pathPart = cleaned.replace(/^..?\s+/, '').split(' -> ').pop();
    map.set(pathPart, cleaned.slice(0, 2));
  }

  return map;
}

const before = parseSnapshot(beforeFile);
const after = parseSnapshot(afterFile);
const changed = new Set();

for (const [file, status] of after.entries()) {
  if (!before.has(file) || before.get(file) !== status) {
    changed.add(file);
  }
}

for (const file of before.keys()) {
  if (!after.has(file)) {
    changed.add(file);
  }
}

const ordered = [...changed]
  .filter((file) => !file.startsWith('runtime/'))
  .sort((left, right) => left.localeCompare(right));

fs.writeFileSync(outputFile, `${ordered.join('\n')}\n`);
NODE
}

run_stage_validators() {
  local mode="$1"
  local step="$2"
  local brief_file="$3"
  local context_manifest_file="${4:-}"
  local changed_list_file="${5:-}"
  local attempt="${6:-1}"
  local guard_file report_dir quality_config

  guard_file=$(guard_file_for_step "$step")
  report_dir=$(security_report_dir)
  quality_config=$(resolve_quality_config)

  append_pipeline_event "$step" "security-${mode}" "started" "guard $(relpath "$guard_file")" "$attempt"

  if [[ "$mode" == "pre" ]]; then
    "${REPO_ROOT}/scripts/ai-run-stage-validators.sh" \
      --mode pre \
      --step "$step" \
      --run-id "$RUN_ID" \
      --brief "$brief_file" \
      --context-manifest "$context_manifest_file" \
      --guard "$guard_file" \
      --config "$quality_config" \
      --report-dir "$report_dir"
  else
    "${REPO_ROOT}/scripts/ai-run-stage-validators.sh" \
      --mode post \
      --step "$step" \
      --run-id "$RUN_ID" \
      --changed "$changed_list_file" \
      --guard "$guard_file" \
      --config "$quality_config" \
      --report-dir "$report_dir"
  fi

  append_pipeline_event "$step" "security-${mode}" "passed" "reports in $(relpath "$report_dir")" "$attempt"
}

run_step_quality_gates() {
  local step="$1"
  local slice_id="$2"
  local attempt="${3:-1}"
  local report_dir

  if [[ "$step" != "tester" ]]; then
    return 0
  fi

  if [[ "$slice_id" == "null" || "$slice_id" == "none" || -z "$slice_id" ]]; then
    fail "tester step cannot run quality gates without an active slice id"
  fi

  report_dir=$(slice_report_dir "$slice_id")
  append_pipeline_event "$step" "quality-gates" "started" "slice $(relpath "$report_dir")" "$attempt"
  "${REPO_ROOT}/scripts/ai-run-quality-gates.sh" --slice "$slice_id" --report-dir "$report_dir"
  append_pipeline_event "$step" "quality-gates" "passed" "quality evidence in $(relpath "$report_dir")" "$attempt"
}

verify_required_step_outputs() {
  local step="$1"
  local expected_slice_dir

  case "$step" in
    ux-ui-designer)
      [[ -f "${REPO_ROOT}/runtime/logs/ux-ui-designer-report.md" ]] || fail "ux-ui-designer did not produce runtime/logs/ux-ui-designer-report.md"
      ;;
    reviewer)
      [[ -f "${REPO_ROOT}/runtime/logs/reviewer-report.md" ]] || fail "reviewer did not produce runtime/logs/reviewer-report.md"
      ;;
    tester)
      [[ -f "${REPO_ROOT}/runtime/logs/test-report.md" ]] || fail "tester did not produce runtime/logs/test-report.md"
      expected_slice_dir=$(slice_report_dir "$LAST_TASK_ID")
      [[ -f "${expected_slice_dir}/quality-gates.json" ]] || fail "tester did not produce $(relpath "${expected_slice_dir}/quality-gates.json")"
      ;;
    frontend-auditor)
      [[ -f "${REPO_ROOT}/runtime/logs/frontend-auditor-report.md" ]] || fail "frontend-auditor did not produce runtime/logs/frontend-auditor-report.md"
      expected_slice_dir=$(slice_report_dir "$LAST_TASK_ID")
      if [[ "$(node -e 'const fs=require("fs"); const file=process.argv[1]; if(!fs.existsSync(file)){process.stdout.write("false"); process.exit(0);} const c=JSON.parse(fs.readFileSync(file,"utf8")); process.stdout.write(String(Boolean((c.frontendEvidence||{}).enabled)));' "$(resolve_quality_config)")" == "true" ]]; then
        [[ -f "${expected_slice_dir}/frontend-evidence-summary.json" ]] || fail "frontend evidence summary is missing for slice ${LAST_TASK_ID}"
      fi
      ;;
    security)
      [[ -f "${REPO_ROOT}/runtime/logs/security-report.md" ]] || fail "security did not produce runtime/logs/security-report.md"
      [[ -f "$(security_report_dir)/${step}-summary.md" ]] || fail "security validation summary is missing for ${step}"
      ;;
  esac
}

write_security_run_summary() {
  local report_dir summary_file
  local step

  report_dir=$(security_report_dir)
  mkdir -p "$report_dir"
  summary_file="${report_dir}/run-summary.md"

  {
    printf '# Security Run Summary\n\n'
    printf -- '- run_id: `%s`\n' "$RUN_ID"
    printf -- '- run_state: `%s`\n' "$RUN_STATE"
    printf -- '- current_step: `%s`\n' "$CURRENT_STEP"
    printf -- '- blocker_count: `%s`\n\n' "${#BLOCKERS[@]}"
    printf '## Stage Status\n\n'

    for step in "${PIPELINE_STEPS[@]}"; do
      local input_status="missing"
      local output_status="missing"
      local stage_summary="${report_dir}/${step}-summary.md"

      if [[ -f "${report_dir}/${step}-input.json" ]]; then
        input_status=$(node -e 'const fs=require("fs"); const x=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(x.status);' "${report_dir}/${step}-input.json")
      fi

      if [[ -f "${report_dir}/${step}-output.json" ]]; then
        output_status=$(node -e 'const fs=require("fs"); const x=JSON.parse(fs.readFileSync(process.argv[1],"utf8")); process.stdout.write(x.status);' "${report_dir}/${step}-output.json")
      fi

      printf -- '- `%s`: input=%s, output=%s' "$step" "$input_status" "$output_status"
      if [[ -f "$stage_summary" ]]; then
        printf ' (`%s`)' "$(relpath "$stage_summary")"
      fi
      printf '\n'
    done

    printf '\n## Blockers\n\n'
    if [[ ${#BLOCKERS[@]} -eq 0 ]]; then
      printf -- '- none\n'
    else
      for blocker in "${BLOCKERS[@]}"; do
        printf -- '- %s\n' "$blocker"
      done
    fi
  } > "$summary_file"
}

mark_run_failed() {
  local exit_code="$1"
  local line_no="$2"

  trap - ERR
  RUN_STATE="failed"
  ACTIVE_AGENTS=()
  BLOCKERS=("step ${CURRENT_STEP} failed with exit code ${exit_code} at line ${line_no}")
  RUN_SUMMARY="failed during ${CURRENT_STEP}"
  write_runtime_state
  write_security_run_summary
  append_pipeline_event "pipeline" "run" "failed" "failed during ${CURRENT_STEP}" 1
  write_run_log
  exit "$exit_code"
}

execute_step_attempt() {
  local step="$1"
  local agent_file="$2"
  local prompt_file="$3"
  local brief_file="$4"
  local attempt="$5"
  local before_snapshot after_snapshot changed_list context_manifest

  before_snapshot=$(mktemp)
  after_snapshot=$(mktemp)
  changed_list=$(mktemp)
  context_manifest="${REPO_ROOT}/runtime/context-cache/${RUN_ID}-${step}.context.md"

  append_pipeline_event "$step" "attempt" "started" "attempt ${attempt}" "$attempt"
  write_worktree_snapshot "$before_snapshot"
  run_stage_validators "pre" "$step" "$brief_file" "$context_manifest" "" "$attempt"

  if [[ -n "$RUNNER_BIN" ]]; then
    "$RUNNER_BIN" \
      --step "$step" \
      --agent "${REPO_ROOT}/${agent_file}" \
      --prompt "${REPO_ROOT}/${prompt_file}" \
      --repo-root "$REPO_ROOT" \
      --brief "$brief_file" \
      --graph "$GRAPH_FILE"
  fi

  run_step_quality_gates "$step" "$LAST_TASK_ID" "$attempt"
  write_worktree_snapshot "$after_snapshot"
  diff_worktree_snapshots "$before_snapshot" "$after_snapshot" "$changed_list"
  run_stage_validators "post" "$step" "$brief_file" "" "$changed_list" "$attempt"
  verify_required_step_outputs "$step"

  rm -f "$before_snapshot" "$after_snapshot" "$changed_list"
  append_pipeline_event "$step" "attempt" "passed" "attempt ${attempt} succeeded" "$attempt"
}

run_step() {
  local step="$1"
  local agent_file="$2"
  local prompt_file="$3"
  local brief_file="${REPO_ROOT}/runtime/context-cache/${RUN_ID}-${step}.brief.md"
  local skip_reason="" attempt exit_code=0

  CURRENT_PLANNER_INPUT_FINGERPRINT=""
  CURRENT_SPEC_INPUT_FINGERPRINT=""
  CURRENT_SPEC_CONTENT_FINGERPRINT=""

  write_step_brief "$step" "$agent_file" "$prompt_file" "$brief_file"

  printf '%s\n' "prepared ${step} using ${prompt_file}"

  if ! step_should_run "$step"; then
    skip_reason=$(step_skip_reason "$step")
    sync_step_fingerprint_baseline "$step"
    write_skipped_step_result "$step" "$brief_file" "$skip_reason"
    append_fingerprint_note_to_step_result "$step"
    append_pipeline_event "$step" "step" "skipped" "$skip_reason" 1
    printf '%s\n' "skipped ${step}: ${skip_reason}"
    return 0
  fi

  for (( attempt = 1; attempt <= STAGE_MAX_RETRIES; attempt += 1 )); do
    if execute_step_attempt "$step" "$agent_file" "$prompt_file" "$brief_file" "$attempt"; then
      record_step_fingerprint_execution "$step"
      append_fingerprint_note_to_step_result "$step"
      return 0
    fi

    exit_code=$?
    append_pipeline_event "$step" "attempt" "failed" "attempt ${attempt} failed with exit code ${exit_code}" "$attempt"

    if (( attempt < STAGE_MAX_RETRIES )); then
      printf '%s\n' "retrying ${step} after failure on attempt ${attempt}"
      sleep "$STAGE_RETRY_DELAY_SECONDS"
    fi
  done

  return "$exit_code"
}

main() {
  local step agent_file prompt_file
  local cycle=1
  local backlog_transition=""

  REQUESTED_STEPS=()
  if [[ $# -gt 0 ]]; then
    EXECUTION_MODE="single-run"
    for step in "$@"; do
      REQUESTED_STEPS+=("$(normalize_step "$step")")
    done
  fi

  require_command node
  require_file "$GRAPH_FILE" "task graph"
  validate_runner_bin

  mapfile -t EXECUTION_PLAN < <(resolve_execution_plan)

  if [[ ${#EXECUTION_PLAN[@]} -eq 0 ]]; then
    printf '%s\n' "graph resolved to an empty execution plan" >&2
    exit 1
  fi

  if [[ -n "$RESUME_FROM_STEP" ]]; then
    local normalized_resume=""
    local filtered_plan=()
    local seen_resume=0

    normalized_resume=$(normalize_step "$RESUME_FROM_STEP")

    for entry in "${EXECUTION_PLAN[@]}"; do
      IFS=$'\t' read -r step _ <<<"$entry"
      if [[ "$step" == "$normalized_resume" ]]; then
        seen_resume=1
      fi
      if (( seen_resume == 1 )); then
        filtered_plan+=("$entry")
      fi
    done

    (( seen_resume == 1 )) || fail "resume step is not present in execution plan: ${normalized_resume}"
    EXECUTION_PLAN=("${filtered_plan[@]}")
  fi

  mkdir -p \
    "${REPO_ROOT}/runtime/state" \
    "${REPO_ROOT}/runtime/logs" \
    "${REPO_ROOT}/runtime/graphs" \
    "${REPO_ROOT}/runtime/context-cache" \
    "$(security_report_dir)" \
    "$SLICE_REPORT_ROOT"

  run_bootstrap_and_context_setup
  enforce_prd_quality_gate

  PIPELINE_STEPS=()
  for entry in "${EXECUTION_PLAN[@]}"; do
    IFS=$'\t' read -r step _ agent_file prompt_file <<<"$entry"
    PIPELINE_STEPS+=("$step")
  done

  refresh_task_context
  RUN_STATE="running"
  RUN_SUMMARY="running"
  ACTIVE_AGENTS=()
  BLOCKERS=()
  write_runtime_state
  write_graph_plan
  append_pipeline_event "pipeline" "run" "started" "execution mode ${EXECUTION_MODE}" 1

  while :; do
    COMPLETED_STEPS=()

    for entry in "${EXECUTION_PLAN[@]}"; do
      IFS=$'\t' read -r step _ agent_file prompt_file <<<"$entry"
      CURRENT_STEP="$step"
      ACTIVE_AGENTS=("$step")
      BLOCKERS=()
      RUN_SUMMARY="running ${step} (cycle ${cycle})"
      write_runtime_state
      run_step "$step" "$agent_file" "$prompt_file"
      COMPLETED_STEPS+=("$step")
    done

    if [[ "$EXECUTION_MODE" != "continuous" ]]; then
      break
    fi

    backlog_transition=$(advance_backlog_state)
    printf '%s\n' "advanced backlog: ${backlog_transition}"
    write_cycle_review "$cycle" "$backlog_transition"
    compact_review_checkpoints
    refresh_task_context

    if [[ "$LAST_TASK_ID" == "null" || "$LAST_TASK_ID" == "none" ]]; then
      break
    fi

    cycle=$((cycle + 1))
  done

  RUN_STATE="completed"
  CURRENT_STEP="completed"
  ACTIVE_AGENTS=()
  BLOCKERS=()
  RUN_SUMMARY="completed"
  write_runtime_state
  write_security_run_summary
  append_pipeline_event "pipeline" "run" "completed" "completed steps: ${PIPELINE_STEPS[*]}" 1
  write_run_log
  printf '%s\n' "graph pipeline complete: ${PIPELINE_STEPS[*]}"
}

trap 'mark_run_failed $? $LINENO' ERR

main "$@"
