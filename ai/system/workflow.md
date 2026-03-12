# Workflow

The template uses a deterministic multi-agent delivery loop controlled by `tasks/task-graph.json`.

## Sequence

1. Orchestrator resolves repository state.
2. The task graph engine validates `tasks/task-graph.json`.
3. Planner repairs or creates the task inventory if needed.
4. Specification Agent creates or repairs the linked spec if needed.
5. Orchestrator ensures exactly one task is `ready`.
6. Builder implements the ready slice.
7. Reviewer checks architecture and contract compliance.
8. Tester runs the relevant verification.
9. Security audits trust boundaries and isolation.
10. Orchestrator records the result and commits the slice when appropriate.

## State Management

- runtime state file: `runtime/state/agent-state.md`
- runtime logs: `runtime/logs/`
- runtime graphs: `runtime/graphs/`
- task graph source: `tasks/task-graph.json`

## Safety Rules

- stop on blockers and record them
- never promote multiple ready slices
- never store runtime outputs in source directories
- keep context index and spec registry synchronized with the source of truth
- abort execution when graph validation fails
