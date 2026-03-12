# Coding Standards Context

Reusable code standards in this template emphasize consistency, boundary clarity, and AI-friendly discoverability.

## Standards

- format code and docs consistently
- keep filenames predictable and descriptive
- prefer explicit DTOs, contracts, and typed failures
- place business logic in owned modules instead of UI or transport glue
- keep comments focused on intent and invariants

## Documentation Discipline

- architecture changes update architecture docs
- API changes update API contracts
- schema changes update schema docs
- task and spec changes update the registry and context index when relationships move

## Test Expectations

- new logic gets unit coverage
- persistence and policy changes get integration coverage
- API changes get contract coverage
- critical flows get end-to-end verification when appropriate
