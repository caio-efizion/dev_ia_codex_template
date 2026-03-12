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

## Rules

1. Decompose work into reviewable slices.
2. Keep exactly one `ready` slice at most.
3. Do not invent scope that is not grounded in the PRD or architecture.
4. Keep backlog dependencies explicit and machine-readable.
