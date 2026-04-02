# Coding Standards

## Formatting

- formatter: `{{FORMATTER}}`
- linting: `{{LINTER}}`
- line endings: LF
- encoding: UTF-8

## Code Rules

1. keep file names predictable
2. keep business logic in owned modules
3. use explicit contracts and typed failures where practical
4. avoid leaking secrets or runtime-only data into source control
5. when the stack includes browser UI, prefer Tailwind CSS plus shared component primitives over ad-hoc styling
6. frontend code must expose loading, empty, error, disabled, and success states for async interactions

## Documentation Rules

1. architecture changes update architecture docs
2. API changes update API contracts
3. schema changes update schema docs
4. spec and backlog relationships update the registry and context index
5. frontend interaction changes update the linked spec and the relevant frontend governance docs when expectations change materially

## Testing Rules

1. new logic gets tests
2. contract changes get contract coverage
3. critical flows get end-to-end checks when appropriate
4. user-facing changes get accessibility, responsive, and interaction-state verification when applicable
