# Developer Guide

## 1. Overview Of The AI Development Framework

This framework is a reusable operating system for AI-assisted software delivery. It is intended to be used by Efizion as the baseline for new project repositories. It combines durable documentation, explicit agent roles, compressed context, deterministic execution, and runtime-only artifacts so new projects can start from a controlled baseline instead of improvising their workflow.

The architecture is layered:

- `docs/` and `tasks/` hold durable source guidance
- `ai/` holds the agent system, prompts, contracts, context, indexes, and operating model
- `runtime/` holds execution artifacts only
- `skills/` holds versioned shared Codex skills for the team
- `scripts/` and `Makefile` provide the executable entrypoints

AI agents work as specialized stages in a controlled delivery loop. Planner structures work, the Specification Agent defines implementation scope, UX/UI Designer makes frontend-facing slices explicit before code is written, Builder implements, Reviewer checks architecture, Tester verifies behavior, Frontend Auditor checks user-visible quality, and Security validates trust boundaries.

## 2. Repository Architecture

### `ai/context`

Long-form reference material for architecture, security, tenancy, and coding standards. Agents use it when they need detailed source guidance.

### `ai/context-compressed`

Short summaries regenerated from the current docs set. These reduce context-loading cost and give agents a fast rehydration layer before they read the full source docs.

### `ai/context-index`

Machine-readable relationship map. It links modules, APIs, schemas, and specs so agents can navigate the project as a knowledge graph.

### `ai/context-policy.yaml`

Deterministic routing policy for selective context loading. The step runner uses it to decide which context categories each agent should open first and which broad context classes to avoid by default.

### `ai/spec-registry`

Registry of known specs and their metadata. This helps keep ownership and status explicit.

### `ai/agents`

Role entrypoints for orchestrator, planner, PRD authoring/review/audit, builder, reviewer, tester, security, and spec-related agents.

### `ai/prompts`

Prompt bodies used by the agent stages during execution.

### `ai/contracts`

Working contracts that define the expected inputs, outputs, and rules for the core agent roles.

### `docs`

Product, architecture, API, schema, audit, and testing guidance. Templates live here, and working project docs are instantiated from them.

For frontend-heavy projects, the key governance docs are:

- `docs/architecture/frontend-architecture.md`
- `docs/specs/design-system.md`
- `docs/specs/frontend-quality-gates.md`
- `docs/specs/ux-research-and-journeys.md`

### `tasks`

Planning artifacts, including the phase plan, backlog, and deterministic task graph.

### `runtime`

Ephemeral execution data only. These files should not be committed beyond `.gitkeep`.

### `scripts`

Executable shell entrypoints for initialization, context refresh, pipeline execution, and graph-driven orchestration.

### `skills`

Versioned shared skills that can be installed into local Codex environments. Use these when Efizion wants reusable Codex behavior to travel with the repository instead of living only in one developer's `~/.codex/skills`.

## 3. Creating A New Project

1. Clone the template repository.
2. Run `make ai-init` to create the minimal `PRD-first` authoring surface and seed runtime directories.
3. Fill `docs/prd-questionnaire.md` with raw product, workflow, domain, integration, and constraint details, including `project_profile`, `technical_stack`, and `delivery_mode`.
4. Run `make ai-prd` to generate or refine `docs/prd.md`.
5. Run `make ai-prd-review` to identify PRD weaknesses before delivery execution.
6. Run `make ai-prd-score` to maintain the objective checklist and gate score.
7. Iterate on `docs/prd-questionnaire.md` and `docs/prd.md` until the project is specific enough for autonomous planning.
8. Run `make ai-run` so the planner and spec-generator can derive `tasks`, `spec-registry`, `context-index`, and initial specs from the PRD.
9. If you want enforced quality gating, use `make ai-run-strict`.
10. Run `make ai-install-skills` if the project should install the shared repository skills locally.
11. If you explicitly want the old broad template materialization flow, use `make ai-init-full`.

In a project repository freshly created from the template, non-template docs may still contain baseline placeholders. That is expected. Those files are bootstrap scaffolding until the PRD-first workflow rewrites them into project-specific artifacts.

## 4. Starting AI Development

### `make ai-init`

This command:

- creates `docs/prd.md` if it does not exist
- creates `docs/prd-questionnaire.md` if it does not exist
- creates `docs/prd-quality-checklist.md` if it does not exist
- creates runtime scaffolding and the minimum files required for a `PRD-first` start
- initializes runtime directories and state files
- refreshes compressed context summaries

### `make ai-prd`

This command:

- uses `docs/prd-questionnaire.md` as the primary authoring input
- runs the PRD Writer through the standard step runner
- builds or refines `docs/prd.md`
- preserves the normal context-routing behavior and runtime logging
- is expected to be rerun whenever requirements, constraints, or project scope evolve
- preserves and expands three explicit dimensions in the PRD:
  - `project_profile`
  - `technical_stack`
  - `delivery_mode`

### `make ai-prd-review`

This command:

- reviews `docs/prd.md` before the main pipeline runs
- writes findings to `docs/audit/prd-review.md`
- focuses on ambiguity, missing decisions, weak acceptance criteria, and architecture-impacting gaps

### `make ai-prd-score`

This command:

- updates `docs/prd-quality-checklist.md`
- writes `docs/audit/prd-score.md`
- assigns a reusable project profile, technical stack summary, delivery mode, and readiness level
- produces a deterministic gate artifact that can block the pipeline in strict mode

### `make ai-init-full`

This compatibility command:

- performs the same minimal bootstrap
- also copies the broader working-doc template set into place
- is useful when a project wants the legacy “materialize everything first” flow

### `make ai-run`

This command:

- validates `tasks/task-graph.json`
- resolves the deterministic stage order
- prepares runtime briefs for each stage
- invokes the default step runner from `AI_STEP_RUNNER_BIN`, which points to `scripts/ai-step-runner-codex.sh` unless you override it
- builds a selective context manifest per step when `ai/context-policy.yaml` is present
- expects the planner and spec-generator to replace bootstrapped placeholders with project artifacts instead of requiring full manual instantiation first
- runs stage security validators before and after each agent step
- runs blocking quality gates after `tester`
- writes durable evidence to `reports/security/` and `reports/slices/`

### `make ai-run-strict`

This command:

- runs the same graph engine as `make ai-run`
- enables `AI_ENFORCE_PRD_QUALITY=1`
- blocks execution unless `docs/audit/prd-score.md` meets the configured gate
- is the recommended mode when a project should not proceed with a weak PRD

### `make ai-run-graph`

This command runs the same graph engine directly. Use it when you want to emphasize the graph-driven execution path or call the deterministic runner explicitly from automation.

### `make ai-install-skills`

This command:

- copies versioned skills from `skills/` into `${CODEX_HOME:-~/.codex}/skills`
- lets Efizion keep reusable Codex behavior under version control
- is useful when a team wants the same local skill behavior across machines

### `make ai-quality-gates`

This command:

- requires `AI_SLICE_ID=<slice-id>`
- runs the blocking local quality suite for the referenced slice
- writes `reports/slices/<slice-id>/quality-gates.json`

### `make ai-pilot-validate`

This command:

- creates a temporary Git workspace from the current repository snapshot
- seeds the versioned questionnaire fixture from `pilot/validation/prd-questionnaire.md`
- runs `make ai-prd`, `make ai-prd-review`, `make ai-prd-score`, and `make ai-run`
- preserves logs and copied artifacts under `reports/pilot-validation/`
- writes the summary report to `reports/pilot-validation.md`

## 5. AI Development Pipeline

The framework expects the following flow:

1. PRD defines the product and operating constraints.
2. Planner structures the phase plan and backlog.
3. Spec Generator creates or repairs implementation specs.
4. UX/UI Designer refines frontend-facing slices before implementation.
5. Builder implements the active slice.
6. Reviewer validates architecture and contract compliance.
7. Tester runs verification.
8. Frontend Auditor reviews user-visible quality, accessibility, responsiveness, and performance evidence.
9. Security audits trust boundaries and data protection rules.

The exact execution order is controlled by `tasks/task-graph.json`. The graph engine validates the graph, resolves a topological order, and executes stages in that order. This prevents accidental stage reordering and makes the pipeline explicit rather than implied by shell scripts. The default graph order is Planner -> Spec Generator -> UX/UI Designer -> Builder -> Reviewer -> Tester -> Frontend Auditor -> Security.

## 6. Writing Good PRDs

A good PRD should define:

- project purpose and business problem
- target users
- in-scope and out-of-scope behavior
- core functional requirements
- non-functional requirements such as architecture, observability, security, and compliance
- delivery constraints that affect agent behavior
- the explicit project profile
- the explicit technical stack
- the explicit delivery mode

Recommended format:

- clear title and overview
- explicit functional requirements with acceptance criteria
- explicit architectural and operational constraints
- language-neutral domain terms even when UI copy is localized

AI agents use the PRD as the top-level source of truth when they plan tasks, generate specs, and resolve ambiguity. Weak PRDs produce unstable downstream specs and backlog slices.

The PRD must describe the target project created from this template, not the template repository itself.

Do not confuse the three main classification axes:

- `project_profile`: the kind of system being built, such as SaaS B2B or ecommerce
- `technical_stack`: the implementation technology, such as Next.js, Laravel, Node.js, Postgres, or Supabase
- `delivery_mode`: the execution context, such as greenfield, MVP, migration, replatform, or existing-product evolution

In the preferred workflow, the PRD is the only source artifact that must be authored in depth before the first full `make ai-run`.

The recommended way to get there is:

1. capture raw detail in `docs/prd-questionnaire.md`
2. run `make ai-prd`
3. run `make ai-prd-review`
4. run `make ai-prd-score`
5. refine until the review and score are strong enough for execution

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

For frontend-heavy projects, the default supporting docs are:

- `docs/specs/design-system.md`
- `docs/specs/frontend-quality-gates.md`
- `docs/specs/ux-research-and-journeys.md`

Specs should be kept aligned with the backlog, spec registry, and context index. If the implementation changes a contract, the matching spec should change in the same slice.

On a fresh project, the planner should first derive the task plan, backlog, context index, and spec registry from the PRD. The Specification Agent then instantiates the concrete spec required by the active slice and rewires any remaining template spec references to project-specific files.

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

## 9A. Context Routing

Selective context routing is handled by `scripts/ai-step-runner-codex.sh`.

- The runner starts from the current step brief in `runtime/context-cache/`.
- It reads `ai/context-policy.yaml` for the active agent.
- It uses `ai/context-index/context-map.json`, linked specs, changed files, contracts, and compressed context summaries to assemble a focused context manifest.
- It excludes `*.template.md`, runtime artifacts, and unrelated repository areas by default.
- If `ai/context-policy.yaml` is missing, the runner falls back to the previous minimal prompt behavior.

Routing remains deterministic:

- file order follows the policy include order
- duplicates are removed
- context is capped by `AI_CONTEXT_MAX_FILES` and `AI_CONTEXT_MAX_BYTES`
- lower-priority files are deferred once the budget is reached

Useful environment variables:

- `AI_DEBUG_CONTEXT=1` prints selected files, applied rules, and an estimated token footprint
- `AI_CONTEXT_MAX_FILES` overrides the routed file-count budget
- `AI_CONTEXT_MAX_BYTES` overrides the routed byte budget

Example policy shape:

```yaml
BUILDER:
  include:
    - context-index
    - linked-spec
    - relevant-code
  exclude:
    - docs

REVIEWER:
  include:
    - changed-files
    - diff
    - linked-spec
  exclude:
    - historical-context
```

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
