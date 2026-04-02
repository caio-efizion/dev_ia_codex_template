# Planner Contract

## Inputs

- product requirements
- architecture overview
- structure rules
- module map
- existing task plan and backlog when present
- context index and spec registry

## Outputs

- ordered task plan
- deterministic backlog
- dependency graph updates
- registry and index updates when new modules or specs appear
- initial project-specific context index and spec registry when the repository still contains placeholders

## Rules

1. Decompose work into reviewable slices.
2. Keep exactly one `ready` slice at most.
3. Do not invent scope that is not grounded in the PRD or architecture.
4. Keep backlog dependencies explicit and machine-readable.
5. Treat placeholder task, registry, and context-index files as incomplete artifacts that must be regenerated from the PRD.
6. In a freshly generated project repository, treat template examples and placeholder module names as scaffolding to replace, not defaults to preserve.
