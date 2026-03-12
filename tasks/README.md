# Task Templates

Instantiate `tasks/tasks.template.md` and `tasks/backlog.template.md` into working project files during bootstrap.

- `tasks/tasks.md`: phase-level roadmap and major capabilities
- `tasks/backlog.md`: executable slice queue used by the orchestrator
- `tasks/task-graph.json`: deterministic stage dependency graph used by the graph engine

Keep backlog dependencies explicit and allow at most one `ready` slice at a time.
