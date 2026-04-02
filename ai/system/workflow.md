# Workflow

The template uses a deterministic multi-agent delivery loop controlled by `tasks/task-graph.json`.

PRD quality assurance is a parallel authoring loop. It is not part of `tasks/task-graph.json`, but it can gate execution when strict quality enforcement is enabled.

In a repository freshly created from this template, working files that still contain `{{...}}` placeholders are a valid bootstrap state. The workflow is expected to converge those files into project-specific artifacts from the PRD before implementation proceeds.

## Sequence

1. Orchestrator resolves repository state.
2. The task graph engine validates `tasks/task-graph.json`.
3. Bootstrap and compressed-context refresh run only when required by missing working files or source drift.
4. Optional PRD quality review, scoring, and gate checks run before the main delivery pipeline, and `make ai-run-strict` can require approval before execution.
5. Planner repairs or creates the task inventory, backlog, context index, and spec registry when those artifacts are missing, invalid, or still contain template placeholders, using `docs/prd.md` as the primary project source.
6. Specification Agent creates or repairs the linked spec only when the active slice lacks a usable working spec, instantiates concrete project spec files from templates when needed, and updates related registry/index entries as the slice becomes concrete.
7. Orchestrator ensures exactly one task is `ready`.
8. Pre-stage security validation runs against the routed inputs and the stage guard before every agent step.
9. UX/UI Designer refines frontend-facing slices so UI states, accessibility, and responsive behavior are explicit before implementation.
10. Builder implements the ready slice.
11. Reviewer checks architecture and contract compliance.
12. Tester runs the relevant verification.
13. Blocking quality gates run for the active slice, including lint, typecheck, unit, e2e, coverage, and frontend evidence when configured.
14. Frontend Auditor reviews user-visible quality, accessibility, responsiveness, and frontend evidence for frontend-facing slices.
15. Post-stage security validation runs against the changed file set and the stage guard.
16. Security audits trust boundaries and isolation.
17. Orchestrator records the result and commits the slice when appropriate.

## State Management

- runtime state file: `runtime/state/agent-state.md`
- runtime fingerprint baseline: `runtime/state/execution-fingerprints.json`
- runtime logs: `runtime/logs/`
- runtime graphs: `runtime/graphs/`
- task graph source: `tasks/task-graph.json`
- step-local briefs and resume context: `runtime/context-cache/`
- durable security reports: `reports/security/<run-id>/`
- durable slice evidence: `reports/slices/<slice-id>/`

## Continuous Execution Handoff

- `tasks/task-graph.json` is the single source of truth for default pipeline order.
- When continuous execution stops because of an external blocker, record the blocker and expected resume point in `runtime/state/agent-state.md`.
- The backlog remains the durable source of the next ready slice; runtime state records execution handoff only.
- Fingerprints under `runtime/state/execution-fingerprints.json` allow planner and spec steps to be skipped safely when inputs have not drifted.
- Retry and resume are explicit execution controls through `AI_STAGE_MAX_RETRIES`, `AI_STAGE_RETRY_DELAY_SECONDS`, and `AI_RESUME_FROM_STEP`.
- Agents should rehydrate from `runtime/context-cache/` and compressed context before expanding into long-form docs.

## Safety Rules

- stop on blockers and record them
- never promote multiple ready slices
- never store runtime outputs in source directories
- keep context index and spec registry synchronized with the source of truth
- abort execution when graph validation fails
- when `AI_ENFORCE_PRD_QUALITY=1`, block pipeline execution unless the PRD gate score explicitly approves the PRD
- do not treat baseline template placeholders as execution-ready project truth
- block execution when required stage evidence is missing
- block execution when security validators or blocking quality gates fail
