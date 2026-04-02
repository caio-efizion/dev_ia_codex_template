#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
PILOT_FIXTURE="${REPO_ROOT}/pilot/validation/prd-questionnaire.md"
QUALITY_CONFIG_REL="pilot/reference-web-app/quality/pipeline.config.json"
REPORT_ROOT="${REPO_ROOT}/reports/pilot-validation"
ARTIFACT_ROOT="${REPORT_ROOT}/artifacts"
LOG_ROOT="${REPORT_ROOT}/logs"
REPORT_FILE="${REPO_ROOT}/reports/pilot-validation.md"
KEEP_WORKDIR="${AI_PILOT_KEEP_WORKDIR:-0}"
SKIP_FULL_RUN="${AI_PILOT_SKIP_RUN:-0}"
WORK_DIR="${AI_PILOT_WORKDIR:-}"

TEMP_REPO=""
RUN_FAILED=0

fail() {
  printf 'ai-run-pilot-validation: %s\n' "$1" >&2
  exit 1
}

timestamp_utc() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

ensure_workdir() {
  if [[ -n "$WORK_DIR" ]]; then
    mkdir -p "$WORK_DIR"
    return 0
  fi

  WORK_DIR=$(mktemp -d)
}

cleanup() {
  if [[ -n "$WORK_DIR" && "$KEEP_WORKDIR" != "1" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

relpath() {
  local path="$1"
  printf '%s\n' "${path#"${REPO_ROOT}/"}"
}

copy_repo() {
  TEMP_REPO="${WORK_DIR}/repo"
  mkdir -p "$TEMP_REPO"

  rsync -a --delete \
    --exclude '.git/' \
    --exclude 'runtime/' \
    --exclude 'reports/' \
    --exclude 'pilot/reference-web-app/node_modules/' \
    --exclude 'pilot/reference-web-app/dist/' \
    --exclude 'pilot/reference-web-app/coverage/' \
    --exclude 'pilot/reference-web-app/playwright-report/' \
    --exclude 'pilot/reference-web-app/test-results/' \
    "${REPO_ROOT}/" "${TEMP_REPO}/"
}

init_temp_repo() {
  (
    cd "$TEMP_REPO"
    git init -q
    git config user.email "pilot-validator@example.com"
    git config user.name "Pilot Validator"
    git add .
    git commit -qm "pilot baseline"
  )
}

seed_fixture() {
  [[ -f "$PILOT_FIXTURE" ]] || fail "missing pilot fixture: $(relpath "$PILOT_FIXTURE")"
  cp "$PILOT_FIXTURE" "${TEMP_REPO}/docs/prd-questionnaire.md"
}

reset_generated_artifacts() {
  rm -f \
    "${TEMP_REPO}/docs/audit/prd-review.md" \
    "${TEMP_REPO}/docs/audit/prd-score.md" \
    "${TEMP_REPO}/docs/prd-quality-checklist.md" \
    "${TEMP_REPO}/tasks/tasks.md" \
    "${TEMP_REPO}/tasks/backlog.md"
}

run_logged() {
  local name="$1"
  shift

  local log_file="${LOG_ROOT}/${name}.log"
  local status_file="${LOG_ROOT}/${name}.status"

  mkdir -p "$LOG_ROOT"
  printf '%s\n' "running ${name}"

  if (
    cd "$TEMP_REPO"
    export AI_QUALITY_CONFIG="$QUALITY_CONFIG_REL"
    export AI_STAGE_MAX_RETRIES="${AI_STAGE_MAX_RETRIES:-2}"
    "$@"
  ) >"$log_file" 2>&1; then
    printf 'passed\n' > "$status_file"
    printf '%s\n' "completed ${name}: passed"
    return 0
  fi

  printf 'failed\n' > "$status_file"
  printf '%s\n' "completed ${name}: failed"
  RUN_FAILED=1
  return 1
}

copy_if_exists() {
  local source_rel="$1"
  local target_rel="$2"
  local source_path="${TEMP_REPO}/${source_rel}"
  local target_path="${ARTIFACT_ROOT}/${target_rel}"

  if [[ -f "$source_path" ]]; then
    mkdir -p "$(dirname "$target_path")"
    cp "$source_path" "$target_path"
  fi
}

copy_dir_if_exists() {
  local source_rel="$1"
  local target_rel="$2"
  local source_path="${TEMP_REPO}/${source_rel}"
  local target_path="${ARTIFACT_ROOT}/${target_rel}"

  if [[ -d "$source_path" ]]; then
    mkdir -p "$target_path"
    rsync -a "$source_path/" "$target_path/"
  fi
}

collect_artifacts() {
  rm -rf "$ARTIFACT_ROOT"
  mkdir -p "$ARTIFACT_ROOT"

  copy_if_exists "docs/prd.md" "docs/prd.md"
  copy_if_exists "docs/audit/prd-review.md" "docs/audit/prd-review.md"
  copy_if_exists "docs/audit/prd-score.md" "docs/audit/prd-score.md"
  copy_if_exists "tasks/tasks.md" "tasks/tasks.md"
  copy_if_exists "tasks/backlog.md" "tasks/backlog.md"
  copy_if_exists "runtime/logs/pipeline-events.jsonl" "runtime/logs/pipeline-events.jsonl"
  copy_if_exists "runtime/logs/test-report.md" "runtime/logs/test-report.md"
  copy_if_exists "runtime/logs/reviewer-report.md" "runtime/logs/reviewer-report.md"
  copy_if_exists "runtime/logs/frontend-auditor-report.md" "runtime/logs/frontend-auditor-report.md"
  copy_if_exists "runtime/logs/security-report.md" "runtime/logs/security-report.md"
  copy_dir_if_exists "reports/security" "reports/security"
  copy_dir_if_exists "reports/slices" "reports/slices"
}

first_existing_report() {
  local pattern="$1"
  local file

  for file in $pattern; do
    if [[ -f "$file" ]]; then
      printf '%s\n' "$file"
      return 0
    fi
  done

  return 1
}

extract_score_field() {
  local file="$1"
  local field="$2"
  if [[ ! -f "$file" ]]; then
    return 0
  fi
  sed -n "s/^- ${field}: \`\\{0,1\\}\\([^\\\`]*\\)\`\\{0,1\\}$/\\1/p" "$file" | head -n 1
}

write_report() {
  local prd_score_file="${ARTIFACT_ROOT}/docs/audit/prd-score.md"
  local run_status="pass"
  local prd_status review_status score_status run_status_file
  local readiness_level overall_score ready_for_pipeline gate_decision

  prd_status=$(cat "${LOG_ROOT}/ai-prd.status" 2>/dev/null || printf 'missing')
  review_status=$(cat "${LOG_ROOT}/ai-prd-review.status" 2>/dev/null || printf 'missing')
  score_status=$(cat "${LOG_ROOT}/ai-prd-score.status" 2>/dev/null || printf 'missing')
  run_status_file=$(cat "${LOG_ROOT}/ai-run.status" 2>/dev/null || printf 'skipped')

  if [[ "$RUN_FAILED" -ne 0 || "$prd_status" != "passed" || "$review_status" != "passed" || "$score_status" != "passed" ]]; then
    run_status="fail"
  fi
  if [[ "$SKIP_FULL_RUN" != "1" && "$run_status_file" != "passed" ]]; then
    run_status="fail"
  fi

  readiness_level=$(extract_score_field "$prd_score_file" "readiness_level")
  overall_score=$(extract_score_field "$prd_score_file" "overall_score")
  ready_for_pipeline=$(extract_score_field "$prd_score_file" "ready_for_pipeline")
  gate_decision=$(extract_score_field "$prd_score_file" "gate_decision")

  mkdir -p "$(dirname "$REPORT_FILE")"
  cat > "$REPORT_FILE" <<EOF
# Pilot Validation

- generated_at: \`$(timestamp_utc)\`
- status: \`${run_status}\`
- temp_repo: \`${TEMP_REPO}\`
- keep_workdir: \`${KEEP_WORKDIR}\`
- full_pipeline_requested: \`$([[ "$SKIP_FULL_RUN" == "1" ]] && printf 'no' || printf 'yes')\`

## Command Status

- \`make ai-prd\`: \`${prd_status}\`
- \`make ai-prd-review\`: \`${review_status}\`
- \`make ai-prd-score\`: \`${score_status}\`
- \`make ai-run\`: \`${run_status_file}\`

## PRD Gate Summary

- readiness_level: \`${readiness_level:-unknown}\`
- overall_score: \`${overall_score:-unknown}\`
- ready_for_pipeline: \`${ready_for_pipeline:-unknown}\`
- gate_decision: \`${gate_decision:-unknown}\`

## Artifact Roots

- logs: \`$(relpath "$LOG_ROOT")\`
- artifacts: \`$(relpath "$ARTIFACT_ROOT")\`

## Key Artifacts

- PRD snapshot: \`$( [[ -f "${ARTIFACT_ROOT}/docs/prd.md" ]] && relpath "${ARTIFACT_ROOT}/docs/prd.md" )\`
- PRD review snapshot: \`$( [[ -f "${ARTIFACT_ROOT}/docs/audit/prd-review.md" ]] && relpath "${ARTIFACT_ROOT}/docs/audit/prd-review.md" )\`
- PRD score snapshot: \`$( [[ -f "${ARTIFACT_ROOT}/docs/audit/prd-score.md" ]] && relpath "${ARTIFACT_ROOT}/docs/audit/prd-score.md" )\`
- Task plan snapshot: \`$( [[ -f "${ARTIFACT_ROOT}/tasks/tasks.md" ]] && relpath "${ARTIFACT_ROOT}/tasks/tasks.md" )\`
- Backlog snapshot: \`$( [[ -f "${ARTIFACT_ROOT}/tasks/backlog.md" ]] && relpath "${ARTIFACT_ROOT}/tasks/backlog.md" )\`
- Security reports snapshot: \`$( [[ -d "${ARTIFACT_ROOT}/reports/security" ]] && relpath "${ARTIFACT_ROOT}/reports/security" )\`
- Slice reports snapshot: \`$( [[ -d "${ARTIFACT_ROOT}/reports/slices" ]] && relpath "${ARTIFACT_ROOT}/reports/slices" )\`

## Notes

- The validation workspace is a temporary Git repository initialized from the current template snapshot so Codex can use normal repository workflows during validation.
- The pilot questionnaire fixture is versioned at \`pilot/validation/prd-questionnaire.md\`.
- Logs are preserved even when a command fails, so the next debugging step is deterministic.
EOF
}

main() {
  command -v rsync >/dev/null 2>&1 || fail "rsync is required"
  command -v git >/dev/null 2>&1 || fail "git is required"
  command -v make >/dev/null 2>&1 || fail "make is required"

  rm -rf "$LOG_ROOT" "$ARTIFACT_ROOT"
  mkdir -p "$REPORT_ROOT" "$LOG_ROOT" "$ARTIFACT_ROOT"
  trap cleanup EXIT

  ensure_workdir
  copy_repo
  init_temp_repo
  seed_fixture
  reset_generated_artifacts
  printf '%s\n' "pilot temp repo: ${TEMP_REPO}"

  if ! run_logged "ai-prd" make ai-prd; then
    collect_artifacts
    write_report
    fail "pilot validation failed at make ai-prd; inspect $(relpath "$LOG_ROOT") and $(relpath "$REPORT_FILE")"
  fi

  if ! run_logged "ai-prd-review" make ai-prd-review; then
    collect_artifacts
    write_report
    fail "pilot validation failed at make ai-prd-review; inspect $(relpath "$LOG_ROOT") and $(relpath "$REPORT_FILE")"
  fi

  if ! run_logged "ai-prd-score" make ai-prd-score; then
    collect_artifacts
    write_report
    fail "pilot validation failed at make ai-prd-score; inspect $(relpath "$LOG_ROOT") and $(relpath "$REPORT_FILE")"
  fi

  if [[ "$SKIP_FULL_RUN" != "1" ]]; then
    if ! run_logged "ai-run" make ai-run; then
      collect_artifacts
      write_report
      fail "pilot validation failed at make ai-run; inspect $(relpath "$LOG_ROOT") and $(relpath "$REPORT_FILE")"
    fi
  else
    printf 'skipped\n' > "${LOG_ROOT}/ai-run.status"
  fi

  collect_artifacts
  write_report

  if [[ "$RUN_FAILED" -ne 0 ]]; then
    fail "pilot validation failed; inspect $(relpath "$LOG_ROOT") and $(relpath "$REPORT_FILE")"
  fi
}

main "$@"
