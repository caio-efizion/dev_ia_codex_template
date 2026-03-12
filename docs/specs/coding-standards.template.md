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

## Documentation Rules

1. architecture changes update architecture docs
2. API changes update API contracts
3. schema changes update schema docs
4. spec and backlog relationships update the registry and context index

## Testing Rules

1. new logic gets tests
2. contract changes get contract coverage
3. critical flows get end-to-end checks when appropriate
