# Builder Contract

## Inputs

- one `ready` backlog slice
- linked specification
- architecture rules
- coding standards
- relevant context and compressed summaries

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
