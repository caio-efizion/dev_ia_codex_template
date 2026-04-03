# AI Operating Model

This document defines how agents should operate in this template repository and in projects bootstrapped from it.

## Principles

1. Source guidance is durable and versioned.
2. Runtime artifacts are ephemeral and isolated.
3. Work is planned and executed one reviewed slice at a time.
4. Architectural relationships are maintained explicitly through specs, the registry, and the context index.
5. A generated project repository becomes execution-ready by deriving project artifacts from the PRD, not by manually materializing every template file upfront.

## Canonical Surfaces

- `docs/`: product, architecture, API, schema, audit, and testing templates
- `tasks/`: task plan and backlog templates
- `ai/agents/`: agent entrypoints
- `ai/prompts/`: prompt bodies
- `ai/contracts/`: agent contracts
- `ai/context/`: long-form reusable context
- `ai/context-compressed/`: short summaries
- `ai/context-index/context-map.json`: relationship map
- `ai/spec-registry/specs.yaml`: spec inventory
- `security/`: security policy, per-agent guards, and validators
- `reports/`: durable validation evidence and pilot outputs
- `runtime/`: execution-only state, logs, and graphs

## Template Lifecycle

This repository has two valid states:

- template baseline: reusable prompts, contracts, templates, and bootstrap scaffolding committed for future projects
- instantiated project: a repository created from the template and progressively made concrete through the `PRD-first` workflow

In a freshly instantiated project, files such as `docs/prd.md`, `tasks/tasks.md`, `tasks/backlog.md`, `ai/context-index/context-map.json`, or `ai/spec-registry/specs.yaml` may still contain baseline placeholders. Those files are not authoritative project truth yet. They are expected to be rewritten from:

1. `docs/prd-questionnaire.md`
2. `docs/prd.md`
3. planner output
4. specification output

## Preferred Operator Surface

When humans drive execution manually, use:

1. `make ai-define`
2. `make ai-build`
3. `make ai-prove`

Use `make ai-flow` or `make ai-flow-strict` when one command is preferred. Use `make ai-run` or `make ai-run-strict` for one-shot automation and CI-oriented full graph execution.

When adopting the template into an already active repository, prepend the operator flow with:

1. `make ai-adopt-existing`
2. `make ai-audit-security`
3. `make ai-audit-frontend`

## Agent Roles

| Agent | Responsibility | Primary Outputs |
| --- | --- | --- |
| Orchestrator | workflow coordination and slice progression | runtime state, slice selection, workflow continuity |
| Planner | task decomposition and dependency ordering | task plan, backlog |
| Specification Agent | detailed implementation specs | instantiated or updated specs |
| UX/UI Designer | interface-state, accessibility, and responsive refinement before implementation | updated spec guidance, UX/UI runtime report |
| Builder | implementation of one ready slice | code, tests, doc updates |
| Reviewer | architecture and contract review | review report |
| Tester | verification and failure triage | test report, fixes for active-slice regressions |
| Frontend Auditor | user-visible quality, accessibility, and frontend evidence review | frontend audit report |
| Security | trust-boundary review | security report |

Optional authoring utilities can exist outside the main delivery graph, such as PRD writer, PRD reviewer, and PRD auditor agents. Those utilities support source quality before the main execution loop begins.

## Working Rules

1. Prefer generated project files over templates.
2. Use the compressed context before re-reading every long-form doc.
3. Update the context index and spec registry when architectural relationships move.
4. Keep generated logs, graphs, and state in `runtime/` only.
5. Do not commit runtime files.
6. In new project repositories, treat placeholder working files as scaffolding to regenerate from the PRD, not as content to preserve.
7. Treat `security/security-policy.md` and the matching `security/agent-guards/*.guard.md` as hard constraints for every stage.
8. Treat `reports/security/` and `reports/slices/` as durable evidence required to prove execution quality.

## Delivery Rules

1. One slice may be `ready` at a time.
2. A slice is not complete until build, review, test, frontend-audit, and security phases pass when those phases apply.
3. Schema, API, and architecture changes update their matching docs in the same slice.
4. TestSprite should be used when available after code generation.
5. Security validators run before and after each stage and fail the pipeline on relevant violations.
6. Frontend-facing slices are incomplete until blocking quality gates and evidence generation pass for the affected slice.
