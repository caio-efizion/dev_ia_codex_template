# Runtime Policy

`runtime/` is reserved for ephemeral execution artifacts.

Allowed categories:

- `runtime/state/`
- `runtime/logs/`
- `runtime/graphs/`
- `runtime/context-cache/`

Committed repository contents in those directories should be limited to `.gitkeep`.

Examples of runtime-only files:

- agent state snapshots
- execution logs
- generated task graphs
- generated prompt briefs and cached context
- temporary audit outputs
- local replay traces
