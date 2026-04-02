# Bootstrap Guide

Use this flow to turn the Efizion template into a project-specific working repository.

The fastest path is:

1. create a new repository from this template
2. `make ai-init`
3. fill `docs/prd-questionnaire.md`
4. `make ai-prd`
5. `make ai-prd-review`
6. `make ai-prd-score`
7. refine the questionnaire and PRD until they are detailed enough to drive planning
8. `make ai-run` or `make ai-run-strict`
9. optionally `make ai-install-skills` to synchronize shared repository skills into the local Codex environment

`make ai-init` now defaults to a minimal `PRD-first` bootstrap.

`make ai-prd` is intended to be rerun as the project requirements evolve. The questionnaire and PRD are living source artifacts during discovery, alignment, and delivery.

The committed template may already contain non-template working files with baseline placeholders. In a generated project repository, treat those files as bootstrap scaffolding until the PRD writer, Planner, and Specification Agent replace them with project-specific content.

## 1. Minimal Bootstrap

The default bootstrap prepares:

- `docs/prd.template.md` -> `docs/prd.md`
- `docs/prd-questionnaire.template.md` -> `docs/prd-questionnaire.md`
- `docs/prd-quality-checklist.template.md` -> `docs/prd-quality-checklist.md`
- `ai/system/state.template.md` -> `runtime/state/agent-state.md`
- runtime directories under `runtime/`
- compressed context summaries under `ai/context-compressed/`

## 2. Capture The Raw Product Inputs

Start with `docs/prd-questionnaire.md`.

Describe:

- project profile
- technical stack
- delivery mode
- product purpose and urgency
- users and stakeholders
- journeys and workflows
- scope boundaries
- business rules
- entities and integrations
- non-functional constraints
- security, compliance, and risk
- delivery assumptions and open questions

## 3. Build And Review The PRD

Run:

```bash
make ai-prd
make ai-prd-review
make ai-prd-score
```

This guided loop builds `docs/prd.md` from the questionnaire, writes a quality review to `docs/audit/prd-review.md`, and produces a gate score in `docs/audit/prd-score.md`.

## 4. Author The PRD

Prefer refining `docs/prd-questionnaire.md` and rerunning `make ai-prd` over manually editing raw template placeholders.

Direct PRD edits are still valid when:

- refining terminology
- resolving review findings
- adding decisions that are easier to express in long-form prose

By the time the PRD is ready for strict execution, `docs/prd.md` should describe the target project clearly and should not still read like reusable template scaffolding.

The more detailed the PRD, the better the planner can derive:

- task plan and backlog
- spec registry
- context index
- initial working specs

For UI-heavy projects, keep these governance docs aligned with the PRD and active specs:

- `docs/architecture/frontend-architecture.md`
- `docs/specs/design-system.md`
- `docs/specs/frontend-quality-gates.md`
- `docs/specs/ux-research-and-journeys.md`

## 5. Run The AI Pipeline

Run:

```bash
make ai-run
```

The planner and specification agent should materialize the remaining project-specific artifacts from the PRD.

If you want enforcement instead of guidance, run:

```bash
make ai-run-strict
```

That mode blocks the delivery pipeline unless the PRD score explicitly approves execution.

## 6. Optional Full Bootstrap

If you want the old “copy all working docs first” behavior, run:

```bash
make ai-init-full
```

That mode also creates:

- `docs/adr/0001-system-architecture.md`
- `docs/architecture/*.md`
- `docs/api/api-contracts.md`
- `docs/database/database-schema.md`
- `docs/domain/domain-model.md`
- `docs/testing/test-plan.md`
- `tasks/tasks.md`
- `tasks/backlog.md`

Use this mode only when a project explicitly wants broad pre-materialization of working docs. It is not the default Efizion flow.

## 7. Instantiate Working Specs

In the preferred flow, the Specification Agent creates project specs from the templates in `docs/specs/` as the active slices become concrete. Manual spec instantiation is a fallback, not the default path.

## 8. Initialize AI Maps

Update:

- `ai/context-index/context-map.json`
- `ai/spec-registry/specs.yaml`

with the real modules, APIs, schemas, and spec paths when the planner/spec-generator has not already done so. In the intended workflow, `make ai-run` should usually handle this automatically from the PRD.

## 9. Keep Runtime Clean

Generate state, logs, graphs, and context cache artifacts only under `runtime/`. Do not commit them.
