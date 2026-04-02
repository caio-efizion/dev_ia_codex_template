# Repository Agent Guide

This repository is a reusable AI development template for Efizion's multi-agent software delivery flow.

The committed repository is the reusable baseline. New project repositories are expected to be created from this template, refined through the `PRD-first` workflow, and only then treated as project-specific execution environments.

The canonical operating model lives in [ai/system/operating-model.md](ai/system/operating-model.md).

## Required Reading Order

Before changing architecture, templates, or agent workflows, read:

1. [docs/prd.template.md](docs/prd.template.md)
2. [docs/adr/0001-system-architecture.template.md](docs/adr/0001-system-architecture.template.md)
3. [docs/architecture/STRUCTURE_RULES.template.md](docs/architecture/STRUCTURE_RULES.template.md)
4. [docs/architecture/architecture.template.md](docs/architecture/architecture.template.md)
5. [docs/architecture/frontend-architecture.template.md](docs/architecture/frontend-architecture.template.md)
6. [docs/architecture/module-map.template.md](docs/architecture/module-map.template.md)
7. [docs/specs/design-system.template.md](docs/specs/design-system.template.md)
8. [docs/specs/frontend-quality-gates.template.md](docs/specs/frontend-quality-gates.template.md)
9. [docs/specs/ux-research-and-journeys.template.md](docs/specs/ux-research-and-journeys.template.md)
10. [docs/specs/coding-standards.template.md](docs/specs/coding-standards.template.md)
11. [tasks/tasks.template.md](tasks/tasks.template.md)
12. [ai/system/workflow.md](ai/system/workflow.md)
13. [ai/system/operating-model.md](ai/system/operating-model.md)

When the template is instantiated for a real project, prefer the generated non-template files first and fall back to template files only when the generated equivalents do not exist yet.

In a freshly created project repository, non-template files may still contain baseline placeholders. Treat those files as bootstrapped scaffolding until `make ai-prd`, the Planner, and the Specification Agent replace them with project-specific content derived from the PRD.

For guided PRD work, prefer:

1. `docs/prd-questionnaire.md`
2. `docs/prd.md`
3. `docs/prd-quality-checklist.md`
4. `docs/prd-questionnaire.template.md`
5. `docs/prd.template.md`

Treat these as separate dimensions when authoring or auditing the PRD:

1. `project_profile`
2. `technical_stack`
3. `delivery_mode`

## Core Rules

1. Keep reusable source guidance in `ai/`, `docs/`, and `tasks/`.
2. Keep generated logs, graphs, and agent state in `runtime/` only.
3. Update `ai/context-index/context-map.json` and `ai/spec-registry/specs.yaml` when modules, APIs, schemas, or specs change.
4. Preserve modular boundaries and trusted write paths.
5. Require explicit tenant context for tenant-owned operations.
6. Keep business logic and persisted values language-neutral, even if the first UI release is `pt-BR`.
7. Never commit secrets, tokens, or private credentials.
8. Treat `security/security-policy.md` and `security/agent-guards/*.guard.md` as blocking constraints, not advisory docs.
9. Treat `reports/security/` and `reports/slices/` as durable evidence surfaces for validation output.

## Agent Locations

- agent definitions: [ai/agents](ai/agents)
- prompts: [ai/prompts](ai/prompts)
- contracts: [ai/contracts](ai/contracts)
- shared skills: [skills](skills)
- context layer: [ai/context](ai/context)
- compressed context: [ai/context-compressed](ai/context-compressed)
- context index: [ai/context-index/context-map.json](ai/context-index/context-map.json)
- spec registry: [ai/spec-registry/specs.yaml](ai/spec-registry/specs.yaml)

## Runtime Policy

`runtime/` is reserved for ephemeral execution state. The committed repository keeps only `.gitkeep` files there.

## Orchestrator Entry Point

When the user says `run orchestrator`, use [ai/agents/orchestrator.md](ai/agents/orchestrator.md) in continuous mode unless they explicitly ask for a single slice.

`tasks/task-graph.json` is the single source of truth for the default execution order used by the CLI pipeline.

Agents that are not referenced by `tasks/task-graph.json` are optional utilities and should not be treated as implicit pipeline stages.

The guided PRD commands are:

- `make ai-prd` to build or refine `docs/prd.md`
- `make ai-prd-review` to review PRD quality before `make ai-run`
- `make ai-prd-score` to maintain the PRD quality checklist and formal gate score
- `make ai-run-strict` to enforce PRD quality before the full delivery pipeline runs
- `make ai-quality-gates` to run the blocking quality suite for a specific slice with `AI_SLICE_ID=<slice-id>`
- `make ai-pilot-validate` to execute the versioned pilot validation flow and write `reports/pilot-validation.md`

The canonical start flow for a repository generated from this template is:

1. capture project requirements in `docs/prd-questionnaire.md`
2. iterate on `make ai-prd`
3. review and score the PRD
4. let `make ai-run` derive the backlog, spec registry, context index, working specs, and frontend governance artifacts from the approved PRD

## Preserved Source Material

When template evolution needs provenance from an original project snapshot, preserve it under [docs/archive/original-project/README.md](docs/archive/original-project/README.md).
