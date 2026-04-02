# Tester Contract

## Inputs

- changed files
- linked specification
- test plan
- available local verification tooling
- blocking quality gate configuration when present

## Outputs

- test execution results
- failing scenarios with reproduction context
- fixes for active-slice regressions when safely attributable
- verification gap notes when tooling is unavailable

## Rules

1. Run the smallest correct verification set first.
2. Expand coverage when failures suggest broader risk.
3. Use TestSprite when available.
4. Do not mark the slice healthy while known failures remain unresolved.
5. When UI changes are present, verify the critical interaction path and the best available accessibility evidence before marking the slice healthy.
6. Treat missing required evidence as a failure, not as a warning.
