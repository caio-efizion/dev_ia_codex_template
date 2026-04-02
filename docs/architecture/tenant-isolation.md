# Tenant Isolation

## Model

`{{PROJECT_NAME}}` uses:

`{{TENANCY_MODEL}}`

## Required Layers

1. request-level tenant resolution
2. authorization aligned to tenant membership or equivalent ownership
3. repository or data-access scoping
4. storage-level isolation where applicable

## Rules

- repositories never trust raw client ownership identifiers blindly
- load-by-id operations still scope by tenant or owner
- cross-tenant access tests are mandatory
- support overrides require explicit audit evidence
