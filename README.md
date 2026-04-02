# AI Development Template Repository

This repository is a reusable template for AI-assisted software delivery at Efizion. It separates durable source guidance from generated runtime artifacts, keeps agent workflows explicit, and adds indexed context layers so multiple agents can work from the same system model without repeatedly reloading the full documentation set.

The committed repository is the reusable baseline. Each new project should start as a repository created from this template, then become project-specific through the `PRD-first` workflow rather than through broad manual document instantiation.

## Repository Architecture

```text
ai/
  agents/
  prompts/
  contracts/
  context/
  context-compressed/
  context-index/
  spec-registry/
  system/
docs/
skills/
tasks/
runtime/
scripts/
Makefile
README.md
```

- `ai/agents/`: role entrypoints for orchestrator, planner, PRD writer/reviewer/auditor, spec agent, UX/UI designer, builder, reviewer, tester, frontend auditor, and security.
- `ai/prompts/`: prompt bodies used by the agents.
- `ai/contracts/`: machine-readable working contracts for the core delivery agents.
- `ai/context/`: reusable long-form context extracted from architecture, security, tenancy, and coding standards.
- `ai/context-compressed/`: short summaries optimized for fast rehydration.
- `ai/context-index/`: the project knowledge graph that links modules, specs, APIs, and schemas.
- `ai/spec-registry/`: the live inventory of template specs and their ownership.
- `ai/system/`: the operating model, workflow, bootstrap guide, and runtime policy.
- `docs/`: reusable source templates for product, architecture, API, database, audit, and testing documentation.
- `skills/`: versioned shared Codex skills that the team can install into local Codex environments.
- `tasks/`: reusable planning and backlog templates.
- `runtime/`: ephemeral state, logs, graphs, and context cache artifacts created during execution. Only `.gitkeep` files belong in version control.
- `scripts/`: shell entrypoints for project initialization, context refresh, and pipeline execution.
- `Makefile`: convenience targets for the executable AI development layer.

## Agent Workflow

The default delivery loop is:

1. Orchestrator resolves state and selects one ready slice.
2. Planner repairs backlog or task structure when required.
3. Spec Agent instantiates or updates the linked specification.
4. UX/UI Designer refines frontend-facing slices before implementation.
5. Builder implements one slice.
6. Reviewer validates architecture and contract compliance.
7. Tester verifies locally and with TestSprite when available.
8. Frontend Auditor checks user-visible quality, accessibility, responsiveness, and frontend evidence.
9. Security audits trusted paths, secrets, and isolation rules.

The canonical rules are in [ai/system/operating-model.md](ai/system/operating-model.md) and [ai/system/workflow.md](ai/system/workflow.md).
`tasks/task-graph.json` is the single source of truth for the default CLI pipeline order.

## Template Lifecycle

The intended lifecycle is:

1. Efizion creates a new repository from this template.
2. The team captures project-specific requirements in `docs/prd-questionnaire.md`.
3. `make ai-prd` is rerun as requirements become clearer.
4. `make ai-prd-review` and `make ai-prd-score` decide whether the PRD is strong enough to drive autonomous execution.
5. `make ai-run` derives the backlog, spec registry, context index, and working specs from the PRD and continues slice-by-slice delivery.
6. `make ai-install-skills` can synchronize the versioned shared skills for team use in Codex.

Non-template files that still contain `{{...}}` placeholders are acceptable in the template baseline and in a freshly generated project repository. They are bootstrap scaffolding, not authoritative project truth.

## Template Quality Loop

Template maintainers should validate the reusable baseline separately from any project-specific PRD:

- `make ai-template-validate` checks cleanliness, portability, graph integrity, and baseline safety
- `make ai-template-score` scores the template baseline against a reusable quality target
- `make ai-prd-score` and `make ai-run-strict` remain project PRD gates after a repository is instantiated from the template

## Execution Layer

- `scripts/ai-init-project.sh` bootstraps a working project in `PRD-first` mode by default, creating the minimal authoring surface plus runtime scaffolding and compressed context.
- `scripts/ai-run-graph.sh` validates `tasks/task-graph.json`, resolves dependency order, prepares per-step briefs, and executes each stage through the configured step runner.
- `scripts/ai-run-pipeline.sh` is a compatibility wrapper that delegates to the graph engine.
- `scripts/ai-step-runner-codex.sh` is the default Codex bridge used by the graph runner.
- `scripts/ai-build-prd.sh` runs a guided PRD authoring pass from the questionnaire into `docs/prd.md`.
- `scripts/ai-review-prd.sh` performs a critical PRD quality review and writes the result to `docs/audit/prd-review.md`.
- `scripts/ai-score-prd.sh` maintains the reusable PRD quality checklist and writes a formal gate score to `docs/audit/prd-score.md`.
- `scripts/ai-refresh-context.sh` regenerates the compressed summaries in `ai/context-compressed/` from working docs while ignoring `*.template.md` spec files.
- `scripts/ai-install-shared-skills.sh` installs versioned repository skills from `skills/` into `${CODEX_HOME:-~/.codex}/skills`.
- `scripts/ai-run-stage-validators.sh` enforces pre-step and post-step security validators around each stage.
- `scripts/ai-run-quality-gates.sh` runs blocking lint, typecheck, unit, e2e, coverage, accessibility, Lighthouse, screenshot, and visual-regression checks for a slice.
- `scripts/ai-run-pilot-validation.sh` runs the versioned PRD-first pilot flow in a temporary Git workspace and writes durable evidence to `reports/pilot-validation.md`.
- `make ai-init`, `make ai-init-full`, `make ai-prd`, `make ai-prd-review`, `make ai-prd-score`, `make ai-template-validate`, `make ai-template-score`, `make ai-run`, `make ai-run-strict`, `make ai-run-graph`, `make ai-refresh-context`, `make ai-install-skills`, `make ai-quality-gates`, `make ai-pilot-validate`, and the other `make ai-*` targets provide a stable command surface for local execution.

## Security By Design

Security is a blocking cross-cutting layer in this template.

- global policy: `security/security-policy.md`
- per-agent guards: `security/agent-guards/*.guard.md`
- automatic validators: `security/validators/`
- durable security reports: `reports/security/<run-id>/`

The graph runner executes validators before and after each stage. Any relevant security violation, secret exposure, insecure endpoint pattern, unsafe DOM pattern, or forbidden env handling should fail the pipeline.

## Evidence And Blocking Gates

The delivery graph is designed to produce objective evidence, not only prose:

- per-slice reports: `reports/slices/<slice-id>/`
- screenshots, route inventory, accessibility reports, Lighthouse reports, and visual regression output
- blocking quality summary: `reports/slices/<slice-id>/quality-gates.json`
- structured pipeline events: `runtime/logs/pipeline-events.jsonl`

The default frontend skill is versioned in `skills/efizion-frontend-excellence/` and is automatically coupled to `ux-ui-designer` and `builder` by the default Codex step runner.

## Context Layers

- `ai/context/` stores reusable long-form reference material.
- `ai/context-compressed/` stores condensed summaries for quick loading.
- `ai/context-index/context-map.json` links modules, specs, APIs, and schemas so agents can navigate the repository as a knowledge graph instead of relying only on free-form search.
- `ai/spec-registry/specs.yaml` is the authoritative inventory of template specs and their status.
- `ai/context-policy.yaml` defines which context categories each agent should prefer or avoid when the step runner builds a selective context manifest.

## Context Routing

The default runner uses selective context routing when [ai/context-policy.yaml](ai/context-policy.yaml) is present.

- The graph engine writes a step brief into `runtime/context-cache/`.
- `scripts/ai-step-runner-codex.sh` reads that brief, consults `ai/context-policy.yaml`, and uses `ai/context-index/context-map.json` plus git state to build a per-step context manifest.
- The runner passes that manifest to Codex as the default context pack, so agents start from only the files most relevant to their role.
- `*.template.md` files are excluded from routed context by default.
- If `ai/context-policy.yaml` is missing, the runner falls back to the previous minimal behavior and only points Codex at the agent file, prompt file, and step brief.

Context routing is deterministic and budget-aware. The runner deduplicates files, skips unrelated paths, and stops adding context once the file-count or byte budget is reached.

Useful environment variables:

- `AI_DEBUG_CONTEXT=1`: prints the applied policy, selected files, and estimated token size.
- `AI_CONTEXT_MAX_FILES`: caps the number of routed context files. Default: `24`.
- `AI_CONTEXT_MAX_BYTES`: caps the estimated total size of routed context files. Default: `120000`.

## Guided PRD Workflow

The recommended start flow is:

1. Run `make ai-init`.
2. Fill `docs/prd-questionnaire.md` with raw product, scope, workflow, data, integration, and constraint detail, including `project_profile`, `technical_stack`, and `delivery_mode`.
   For projects with UI, also capture frontend surfaces, interaction states, accessibility expectations, responsive priorities, and frontend performance constraints.
3. Run `make ai-prd` to generate or refine `docs/prd.md`.
4. Run `make ai-prd-review` to create `docs/audit/prd-review.md`.
5. Run `make ai-prd-score` to maintain `docs/prd-quality-checklist.md` and create `docs/audit/prd-score.md`.
6. Refine the questionnaire or PRD until the review and score are strong enough.
7. Run `make ai-run` or `make ai-run-strict`.

`make ai-prd`, `make ai-prd-review`, and `make ai-prd-score` reuse the same step runner and selective context routing used by the main pipeline.

For the reusable template itself, use `make ai-template-validate` and `make ai-template-score` instead of reading `docs/audit/prd-score.md` as a baseline quality signal. That PRD score is for an instantiated project's product definition.

The PRD quality system separates three axes that should not be confused:

- `project_profile`: what kind of product or system this is
- `technical_stack`: what technologies will implement it
- `delivery_mode`: how the work is being delivered, such as greenfield, MVP, migration, or evolution of an existing product

When you want enforcement instead of guidance, use:

```bash
make ai-run-strict
```

That target enables `AI_ENFORCE_PRD_QUALITY=1`, which blocks the delivery pipeline unless `docs/audit/prd-score.md` explicitly approves the PRD.

## Bootstrap A New Project

1. Create a new repository from this template.
2. Run `make ai-init` to seed runtime scaffolding and any missing bootstrap files.
3. Fill `docs/prd-questionnaire.md` with project-specific requirements.
4. Run `make ai-prd`, `make ai-prd-review`, and `make ai-prd-score` iteratively until the PRD is strong enough to drive execution.
5. Keep the frontend governance docs available for UI-heavy projects: `docs/architecture/frontend-architecture.md`, `docs/specs/design-system.md`, `docs/specs/frontend-quality-gates.md`, and `docs/specs/ux-research-and-journeys.md`.
6. Run `make ai-run` so the Planner and Specification Agent can derive `tasks/tasks.md`, `tasks/backlog.md`, `ai/spec-registry/specs.yaml`, `ai/context-index/context-map.json`, and the first working specs from the PRD.
7. Create runtime files only under `runtime/` during execution.
8. Run `make ai-install-skills` if the team should install the versioned repository skills locally.

Detailed instructions live in [ai/system/bootstrap.md](ai/system/bootstrap.md).

## How To Start A New AI-Driven Project

1. Clone the template repository.
2. Run `make ai-init`.
3. Fill `docs/prd-questionnaire.md`.
4. Run `make ai-prd`.
5. Run `make ai-prd-review`.
6. Run `make ai-prd-score`.
7. Focus on making the PRD the most complete source artifact in the repository. In the default bootstrap mode, `ai-init` intentionally does not materialize every working doc, because `make ai-run` is expected to derive the missing planning artifacts from the PRD.
8. Run `make ai-run` or `make ai-run-strict`.

`make ai-run` executes the deterministic graph in [tasks/task-graph.json](tasks/task-graph.json), prepares each step from the prompt files in [ai/prompts](ai/prompts), writes step briefs into `runtime/context-cache/`, and by default invokes [scripts/ai-step-runner-codex.sh](scripts/ai-step-runner-codex.sh). Set `AI_STEP_RUNNER_BIN` only when you need to override the default runner.

In the intended `PRD-first` workflow, `make ai-run` should be able to derive and repair the remaining planning artifacts from `docs/prd.md`, including:

- `tasks/tasks.md`
- `tasks/backlog.md`
- `docs/specs/*.md` for the active slice
- `ai/spec-registry/specs.yaml`
- `ai/context-index/context-map.json`

If you want the old broad bootstrap behavior, use:

```bash
make ai-init-full
```

That mode materializes the working docs from templates before the first run.

The default graph order is Planner -> Spec Generator -> UX/UI Designer -> Builder -> Reviewer -> Tester -> Frontend Auditor -> Security.

## Optional Agents

Agents that are present under `ai/agents/` but not referenced by [tasks/task-graph.json](tasks/task-graph.json) are optional utilities. Today that includes [ai/agents/spec-auditor.md](ai/agents/spec-auditor.md), which is intentionally available for manual spec reviews but is not part of the default orchestrator flow.

The PRD support agents [ai/agents/prd-writer.md](ai/agents/prd-writer.md), [ai/agents/prd-reviewer.md](ai/agents/prd-reviewer.md), and [ai/agents/prd-auditor.md](ai/agents/prd-auditor.md) are also optional utilities outside the default delivery graph.

## Shared Skills

Versioned team skills live under `skills/`.

Current shared skill:

- `skills/efizion-frontend-excellence/`

Install them locally with:

```bash
make ai-install-skills
```

## Getting Started

1. Clone the repository.
2. Run `make ai-init`.
3. Fill `docs/prd-questionnaire.md`.
4. Run `make ai-prd`, `make ai-prd-review`, and `make ai-prd-score`.
5. Run `make ai-run` or `make ai-run-strict`.

## Preserved Original Materials

When template evolution needs provenance artifacts from an original project, preserve them under [docs/archive/original-project/README.md](docs/archive/original-project/README.md) without polluting the reusable surface area.
