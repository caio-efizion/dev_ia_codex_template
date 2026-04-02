# Repository Structure Rules

This template uses the following top-level layout:

```text
ai/
docs/
tasks/
runtime/
src/
tests/
```

Additional code roots such as `apps/`, `packages/`, or `infra/` may be added only if the instantiated project documents them explicitly.

## Directory Intent

- `ai/`: agent system, context, contracts, registry, and workflow
- `docs/`: durable source documentation
- `tasks/`: planning and backlog source files
- `runtime/`: ephemeral execution artifacts
- `src/`: application or service code
- `tests/`: cross-module verification

## Rules

1. Source docs do not store generated runtime state.
2. Runtime directories keep only `.gitkeep` in version control.
3. New modules must follow the documented module map.
4. Shared utilities must remain independent from module-private business rules.
