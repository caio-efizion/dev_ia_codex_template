#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
GRAPH_FILE="${REPO_ROOT}/tasks/task-graph.json"
RUN_ID=$(date -u '+%Y%m%dT%H%M%SZ')
RUNNER_BIN="${AI_STEP_RUNNER_BIN:-}"

relpath() {
  local path="$1"
  printf '%s\n' "${path#"${REPO_ROOT}/"}"
}

normalize_step() {
  case "$1" in
    planner|plan)
      printf '%s\n' "planner"
      ;;
    spec|spec-generator|specs)
      printf '%s\n' "spec-generator"
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
    security|secure)
      printf '%s\n' "security"
      ;;
    *)
      printf '%s\n' "unsupported graph target: $1" >&2
      exit 1
      ;;
  esac
}

inputs_for_step() {
  case "$1" in
    planner)
      cat <<'EOF'
- docs/prd.md
- docs/architecture/
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
- ai/context-index/context-map.json
EOF
      ;;
    builder)
      cat <<'EOF'
- tasks/backlog.md
- docs/specs/
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
EOF
      ;;
    tester)
      cat <<'EOF'
- changed implementation files
- docs/testing/test-plan.md
- ai/prompts/tester.prompt.md
- ai/context-compressed/
EOF
      ;;
    security)
      cat <<'EOF'
- changed implementation files
- ai/context/security-context.md
- ai/context/tenancy-context.md
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
EOF
      ;;
    security)
      cat <<'EOF'
- runtime/logs/security-report.md
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
  local current_step="$1"
  cat > "${REPO_ROOT}/runtime/state/pipeline-status.md" <<EOF
run_id: ${RUN_ID}
current_step: ${current_step}
graph_file: tasks/task-graph.json
steps: ${PIPELINE_STEPS[*]}
runner_bin: ${RUNNER_BIN:-not_configured}
EOF
}

write_graph_plan() {
  local plan_file="${REPO_ROOT}/runtime/graphs/execution-plan-${RUN_ID}.md"
  {
    cat <<EOF
# Graph Execution Plan

- run_id: ${RUN_ID}
- graph: tasks/task-graph.json
- runner_bin: ${RUNNER_BIN:-not_configured}

## Ordered Steps

EOF

    local step
    for step in "${PIPELINE_STEPS[@]}"; do
      printf -- "- %s\n" "$step"
    done
  } > "$plan_file"
}

write_run_log() {
  local log_file="${REPO_ROOT}/runtime/logs/pipeline-${RUN_ID}.md"
  {
    cat <<EOF
# AI Pipeline Run

- run_id: ${RUN_ID}
- graph: tasks/task-graph.json
- steps: ${PIPELINE_STEPS[*]}
- runner_bin: ${RUNNER_BIN:-not_configured}

## Step Briefs

EOF

    local step
    for step in "${PIPELINE_STEPS[@]}"; do
      printf -- "- runtime/context-cache/%s-%s.brief.md\n" "${RUN_ID}" "${step}"
    done
  } > "$log_file"
}

run_step() {
  local step="$1"
  local agent_file="$2"
  local prompt_file="$3"
  local brief_file="${REPO_ROOT}/runtime/context-cache/${RUN_ID}-${step}.brief.md"

  cat > "$brief_file" <<EOF
# Pipeline Step Brief

- run_id: ${RUN_ID}
- step: ${step}
- agent: ${agent_file}
- prompt: ${prompt_file}
- graph: tasks/task-graph.json

## Inputs

$(inputs_for_step "$step")

## Expected Outputs

$(outputs_for_step "$step")
EOF

  printf '%s\n' "prepared ${step} using ${prompt_file}"

  if [[ -n "$RUNNER_BIN" ]]; then
    "$RUNNER_BIN" \
      --step "$step" \
      --agent "${REPO_ROOT}/${agent_file}" \
      --prompt "${REPO_ROOT}/${prompt_file}" \
      --repo-root "$REPO_ROOT" \
      --brief "$brief_file" \
      --graph "$GRAPH_FILE"
  fi
}

main() {
  local step agent_file prompt_file

  REQUESTED_STEPS=()
  if [[ $# -gt 0 ]]; then
    for step in "$@"; do
      REQUESTED_STEPS+=("$(normalize_step "$step")")
    done
  fi

  mapfile -t EXECUTION_PLAN < <(resolve_execution_plan)

  if [[ ${#EXECUTION_PLAN[@]} -eq 0 ]]; then
    printf '%s\n' "graph resolved to an empty execution plan" >&2
    exit 1
  fi

  bash "${SCRIPT_DIR}/ai-init-project.sh"
  bash "${SCRIPT_DIR}/ai-refresh-context.sh"

  PIPELINE_STEPS=()
  for entry in "${EXECUTION_PLAN[@]}"; do
    IFS=$'\t' read -r step _ agent_file prompt_file <<<"$entry"
    PIPELINE_STEPS+=("$step")
  done

  write_graph_plan

  for entry in "${EXECUTION_PLAN[@]}"; do
    IFS=$'\t' read -r step _ agent_file prompt_file <<<"$entry"
    write_status "$step"
    run_step "$step" "$agent_file" "$prompt_file"
  done

  write_status "completed"
  write_run_log
  printf '%s\n' "graph pipeline complete: ${PIPELINE_STEPS[*]}"
}

main "$@"
