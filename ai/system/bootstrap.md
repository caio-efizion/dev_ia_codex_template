# Bootstrap Guide

Use this flow to turn the template into a project-specific working repository.

The fastest path is:

1. `make ai-init`
2. replace template placeholders
3. `make ai-run`

## 1. Instantiate Core Docs

Create project files from:

- `docs/prd.template.md` -> `docs/prd.md`
- `docs/adr/0001-system-architecture.template.md` -> `docs/adr/0001-system-architecture.md`
- `docs/architecture/*.template.md` -> matching working files
- `docs/api/api-contracts.template.md` -> `docs/api/api-contracts.md`
- `docs/database/database-schema.template.md` -> `docs/database/database-schema.md`
- `docs/domain/domain-model.template.md` -> `docs/domain/domain-model.md`
- `docs/testing/test-plan.template.md` -> `docs/testing/test-plan.md`
- `tasks/tasks.template.md` -> `tasks/tasks.md`
- `tasks/backlog.template.md` -> `tasks/backlog.md`

## 2. Replace Placeholders

At minimum, fill:

- `{{PROJECT_NAME}}`
- `{{SYSTEM_ARCHITECTURE}}`
- `{{TECH_STACK}}`
- `{{MAIN_MODULES}}`
- `{{TENANCY_MODEL}}`

## 3. Instantiate Working Specs

Create project specs from the templates in `docs/specs/` for each planned module or capability.

## 4. Initialize AI Maps

Update:

- `ai/context-index/context-map.json`
- `ai/spec-registry/specs.yaml`

with the real modules, APIs, schemas, and spec paths.

## 5. Keep Runtime Clean

Generate state, logs, graphs, and context cache artifacts only under `runtime/`. Do not commit them.
