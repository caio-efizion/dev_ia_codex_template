# Developer Guide

## 1. Overview Of The AI Development Framework

This framework is a reusable operating system for AI-assisted software delivery. It combines durable documentation, explicit agent roles, compressed context, deterministic execution, and runtime-only artifacts so new projects can start from a controlled baseline instead of improvising their workflow.

The architecture is layered:

- `docs/` and `tasks/` hold durable source guidance
- `ai/` holds the agent system, prompts, contracts, context, indexes, and operating model
- `runtime/` holds execution artifacts only
- `scripts/` and `Makefile` provide the executable entrypoints

AI agents work as specialized stages in a controlled delivery loop. Planner structures work, the Specification Agent defines implementation scope, Builder implements, Reviewer checks architecture, Tester verifies behavior, and Security validates trust boundaries.

## 2. Repository Architecture

### `ai/context`

Long-form reference material for architecture, security, tenancy, and coding standards. Agents use it when they need detailed source guidance.

### `ai/context-compressed`

Short summaries regenerated from the current docs set. These reduce context-loading cost and give agents a fast rehydration layer before they read the full source docs.

### `ai/context-index`

Machine-readable relationship map. It links modules, APIs, schemas, and specs so agents can navigate the project as a knowledge graph.

### `ai/spec-registry`

Registry of known specs and their metadata. This helps keep ownership and status explicit.

### `ai/agents`

Role entrypoints for orchestrator, planner, builder, reviewer, tester, security, and spec-related agents.

### `ai/prompts`

Prompt bodies used by the agent stages during execution.

### `ai/contracts`

Working contracts that define the expected inputs, outputs, and rules for the core agent roles.

### `docs`

Product, architecture, API, schema, audit, and testing guidance. Templates live here, and working project docs are instantiated from them.

### `tasks`

Planning artifacts, including the phase plan, backlog, and deterministic task graph.

### `runtime`

Ephemeral execution data only. These files should not be committed beyond `.gitkeep`.

### `scripts`

Executable shell entrypoints for initialization, context refresh, pipeline execution, and graph-driven orchestration.

## 3. Creating A New Project

1. Clone the template repository.
2. Create `docs/prd.md` from `docs/prd.template.md`.
3. Replace the template placeholders such as `{{PROJECT_NAME}}`, `{{SYSTEM_ARCHITECTURE}}`, `{{TECH_STACK}}`, `{{MAIN_MODULES}}`, and `{{TENANCY_MODEL}}`.
4. Run `make ai-init` to instantiate the remaining missing working files and seed runtime directories.
5. Update `tasks/tasks.md`, `tasks/backlog.md`, `ai/context-index/context-map.json`, and `ai/spec-registry/specs.yaml` with project-specific data.

## 4. Starting AI Development

### `make ai-init`

This command:

- creates `docs/prd.md` if it does not exist
- copies missing working docs from the template set
- initializes runtime directories and state files
- refreshes compressed context summaries

### `make ai-run`

This command:

- validates `tasks/task-graph.json`
- resolves the deterministic stage order
- prepares runtime briefs for each stage
- optionally invokes an external AI runner if `AI_STEP_RUNNER_BIN` is configured

### `make ai-run-graph`

This command runs the same graph engine directly. Use it when you want to emphasize the graph-driven execution path or call the deterministic runner explicitly from automation.

## 5. AI Development Pipeline

The framework expects the following flow:

1. PRD defines the product and operating constraints.
2. Planner structures the phase plan and backlog.
3. Spec Generator creates or repairs implementation specs.
4. Builder implements the active slice.
5. Reviewer validates architecture and contract compliance.
6. Tester runs verification.
7. Security audits trust boundaries and data protection rules.

The exact execution order is controlled by `tasks/task-graph.json`. The graph engine validates the graph, resolves a topological order, and executes stages in that order. This prevents accidental stage reordering and makes the pipeline explicit rather than implied by shell scripts.

## 6. Writing Good PRDs

A good PRD should define:

- project purpose and business problem
- target users
- in-scope and out-of-scope behavior
- core functional requirements
- non-functional requirements such as architecture, observability, security, and compliance
- delivery constraints that affect agent behavior

Recommended format:

- clear title and overview
- explicit functional requirements with acceptance criteria
- explicit architectural and operational constraints
- language-neutral domain terms even when UI copy is localized

AI agents use the PRD as the top-level source of truth when they plan tasks, generate specs, and resolve ambiguity. Weak PRDs produce unstable downstream specs and backlog slices.

## 7. Working With Specs

Project specs live in `docs/specs/`.

The Specification Agent creates or updates them from the template files. A good spec should define:

- scope
- business rules
- ownership and dependencies
- data model impact
- API or interface contracts
- validation and authorization rules
- failure modes
- test scenarios

Specs should be kept aligned with the backlog, spec registry, and context index. If the implementation changes a contract, the matching spec should change in the same slice.

## 8. Understanding Runtime Artifacts

### `runtime/state`

Execution state such as the active pipeline status and agent-state snapshots.

### `runtime/logs`

Human-readable execution logs, review notes, and pipeline run summaries.

### `runtime/graphs`

Derived execution plans and graph-related runtime outputs.

### `runtime/context-cache`

Per-step context briefs prepared by the graph engine before each stage runs.

These artifacts are for execution support only. They should not replace the durable docs in `docs/`, `tasks/`, or `ai/`.

## 9. Updating Context

Use:

```bash
make ai-refresh-context
```

This regenerates the compressed summaries in `ai/context-compressed/` from the current docs tree.

The context compression layer exists to give agents a smaller, faster context surface. It should be refreshed whenever the PRD, architecture, specs, or API contracts change materially.

## 10. Extending The System

To add a new agent:

1. add the entrypoint in `ai/agents/`
2. add its prompt in `ai/prompts/`
3. add or update its contract in `ai/contracts/` if needed
4. add a node to `tasks/task-graph.json`
5. connect it with explicit edges

To add a new pipeline stage:

- update the task graph
- ensure the referenced agent and prompt exist
- update scripts or docs only if the stage has unique inputs or outputs

To modify execution order:

- edit `tasks/task-graph.json`
- keep dependencies explicit
- run the graph engine to validate there are no cycles

To extend prompts:

- update the corresponding file in `ai/prompts/`
- keep the prompt aligned with the agent contract and operating model

## 11. Troubleshooting

### Pipeline not executing

- confirm `tasks/task-graph.json` exists and is valid JSON
- run `bash scripts/ai-run-graph.sh` directly to see validation errors
- confirm referenced agent and prompt files exist

### Missing specs

- verify `docs/specs/` contains the expected templates or instantiated specs
- run `make ai-init` if the project has not been bootstrapped yet
- verify the backlog points to the right spec paths

### Agent conflicts

- confirm the PRD, backlog, specs, and context index agree on ownership
- verify only one backlog item is marked `ready`
- refresh compressed context after major doc changes

### Graph validation failure

- look for cycles in `tasks/task-graph.json`
- confirm every edge references a real node
- confirm every node references a real agent and prompt
