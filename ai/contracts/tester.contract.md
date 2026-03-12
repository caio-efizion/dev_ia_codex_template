# Tester Contract

## Inputs

- changed files
- linked specification
- test plan
- available local verification tooling

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
