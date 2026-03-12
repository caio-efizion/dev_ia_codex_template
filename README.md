# AI Development Template Repository

This repository is a reusable template for AI-assisted SaaS development. It separates durable source guidance from generated runtime artifacts, keeps agent workflows explicit, and adds indexed context layers so multiple agents can work from the same system model without repeatedly reloading the full documentation set.

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
tasks/
runtime/
scripts/
Makefile
README.md
```

- `ai/agents/`: role entrypoints for orchestrator, planner, builder, reviewer, tester, security, and spec agents.
- `ai/prompts/`: prompt bodies used by the agents.
- `ai/contracts/`: machine-readable working contracts for the core delivery agents.
- `ai/context/`: reusable long-form context extracted from architecture, security, tenancy, and coding standards.
- `ai/context-compressed/`: short summaries optimized for fast rehydration.
- `ai/context-index/`: the project knowledge graph that links modules, specs, APIs, and schemas.
- `ai/spec-registry/`: the live inventory of template specs and their ownership.
- `ai/system/`: the operating model, workflow, bootstrap guide, and runtime policy.
- `docs/`: reusable source templates for product, architecture, API, database, audit, and testing documentation.
- `tasks/`: reusable planning and backlog templates.
- `runtime/`: ephemeral state, logs, graphs, and context cache artifacts created during execution. Only `.gitkeep` files belong in version control.
- `scripts/`: shell entrypoints for project initialization, context refresh, and pipeline execution.
- `Makefile`: convenience targets for the executable AI development layer.

## Agent Workflow

The default delivery loop is:

1. Orchestrator resolves state and selects one ready slice.
2. Planner repairs backlog or task structure when required.
3. Spec Agent instantiates or updates the linked specification.
4. Builder implements one slice.
5. Reviewer validates architecture and contract compliance.
6. Tester verifies locally and with TestSprite when available.
7. Security audits trusted paths, secrets, and isolation rules.

The canonical rules are in [ai/system/operating-model.md](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/system/operating-model.md) and [ai/system/workflow.md](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/system/workflow.md).

## Execution Layer

- `scripts/ai-init-project.sh` bootstraps a working project by copying missing files from the template set, seeding runtime directories, and refreshing compressed context.
- `scripts/ai-run-graph.sh` validates `tasks/task-graph.json`, resolves dependency order, and stages the prompt-driven pipeline deterministically from the task graph.
- `scripts/ai-run-pipeline.sh` is a compatibility wrapper that delegates to the graph engine.
- `scripts/ai-refresh-context.sh` regenerates the compressed summaries in `ai/context-compressed/` from the current `docs/` tree.
- `make ai-init`, `make ai-run`, `make ai-run-graph`, and the other `make ai-*` targets provide a stable command surface for local execution.

## Context Layers

- `ai/context/` stores reusable long-form reference material.
- `ai/context-compressed/` stores condensed summaries for quick loading.
- `ai/context-index/context-map.json` links modules, specs, APIs, and schemas so agents can navigate the repository as a knowledge graph instead of relying only on free-form search.
- `ai/spec-registry/specs.yaml` is the authoritative inventory of template specs and their status.

## Bootstrap A New Project

1. Copy the required template files into working project files.
2. Replace placeholder tokens such as `{{PROJECT_NAME}}`, `{{SYSTEM_ARCHITECTURE}}`, `{{TECH_STACK}}`, `{{MAIN_MODULES}}`, and `{{TENANCY_MODEL}}`.
3. Instantiate the task plan and backlog from `tasks/*.template.md`.
4. Instantiate the relevant spec templates in `docs/specs/`.
5. Update `ai/context-index/context-map.json` with the real modules, APIs, and schemas.
6. Update `ai/spec-registry/specs.yaml` with the instantiated specs.
7. Create runtime files only under `runtime/` during execution.

Detailed instructions live in [ai/system/bootstrap.md](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/system/bootstrap.md).

## How To Start A New AI-Driven Project

1. Clone the template repository.
2. Create `docs/prd.md`, or let the framework create it from `docs/prd.template.md`.
3. Run `make ai-init`.
4. Fill in the placeholders in the generated working docs.
5. Run `make ai-run`.

`make ai-run` executes the deterministic graph in [tasks/task-graph.json](/root/desenvolvimento-vscode/dev_ia_codex_template/tasks/task-graph.json), prepares each step from the prompt files in [ai/prompts](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/prompts), and writes step briefs into `runtime/context-cache/`. If you have an external CLI runner, set `AI_STEP_RUNNER_BIN` to have the script invoke it for each step automatically.

## Getting Started

1. Clone the repository.
2. Create [docs/prd.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/prd.md) from [docs/prd.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/prd.template.md) if it does not exist yet.
3. Run `make ai-init`.
4. Run `make ai-run`.

## Preserved Original Materials

The repository was refactored from a real project. The original project-specific documentation and generated artifacts are preserved under [docs/archive/original-project](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/archive/original-project) so the template retains its source context without polluting the reusable surface area.
