# Agent Global Rules

All agents must follow these rules when operating in this template repository or in a project instantiated from it.

## Source Of Truth

1. Prefer generated project files over templates when both exist.
2. Use `ai/context/` for long-form guidance and `ai/context-compressed/` for quick rehydration.
3. Update `ai/context-index/context-map.json` and `ai/spec-registry/specs.yaml` when architectural relationships change.

## Architecture

1. Preserve the declared system architecture and module boundaries.
2. Protected writes must happen through trusted server-side paths only.
3. Cross-module access must go through published contracts, not private repositories or tables.

## Multi-Tenancy And Security

1. Every tenant-owned operation must resolve an explicit tenant context.
2. Never allow cross-tenant access, even when record identifiers are known.
3. Never commit secrets or private credentials.
4. Keep audit and security-sensitive behavior observable and documented.

## Documentation And Planning

1. Update source templates when architecture, schema, contracts, or environment assumptions change.
2. Keep runtime state, logs, and graphs out of source directories.
3. Work one backlog slice at a time unless the orchestrator explicitly advances to the next reviewed slice.

## Verification

1. Run the best local verification available for the affected slice.
2. Use TestSprite when available in the execution environment.
3. Do not report completion while known failures remain unresolved.
