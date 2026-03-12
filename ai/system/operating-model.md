# AI Operating Model

This document defines how agents should operate in this template repository and in projects bootstrapped from it.

## Principles

1. Source guidance is durable and versioned.
2. Runtime artifacts are ephemeral and isolated.
3. Work is planned and executed one reviewed slice at a time.
4. Architectural relationships are maintained explicitly through specs, the registry, and the context index.

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
- `runtime/`: execution-only state, logs, and graphs

## Agent Roles

| Agent | Responsibility | Primary Outputs |
| --- | --- | --- |
| Orchestrator | workflow coordination and slice progression | runtime state, slice selection, workflow continuity |
| Planner | task decomposition and dependency ordering | task plan, backlog |
| Specification Agent | detailed implementation specs | instantiated or updated specs |
| Builder | implementation of one ready slice | code, tests, doc updates |
| Reviewer | architecture and contract review | review report |
| Tester | verification and failure triage | test report, fixes for active-slice regressions |
| Security | trust-boundary review | security report |

## Working Rules

1. Prefer generated project files over templates.
2. Use the compressed context before re-reading every long-form doc.
3. Update the context index and spec registry when architectural relationships move.
4. Keep generated logs, graphs, and state in `runtime/` only.
5. Do not commit runtime files.

## Delivery Rules

1. One slice may be `ready` at a time.
2. A slice is not complete until build, review, test, and security phases pass.
3. Schema, API, and architecture changes update their matching docs in the same slice.
4. TestSprite should be used when available after code generation.
