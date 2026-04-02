# Builder Contract

## Inputs

- one `ready` backlog slice
- linked specification
- architecture rules
- coding standards
- relevant context and compressed summaries
- security policy and builder guard

## Outputs

- implementation for the active slice
- tests for changed behavior
- source documentation updates when contracts, APIs, or schemas change
- registry and index updates when architectural relationships change

## Rules

1. Implement only the active slice.
2. Keep protected writes on trusted server paths.
3. Respect module ownership and published contracts.
4. Keep generated execution artifacts out of source directories.
5. When the active slice affects user-facing UI, implement the documented state model, accessibility requirements, and responsive behavior as first-class scope.
6. Treat the builder security guard as a hard fail-closed constraint.
