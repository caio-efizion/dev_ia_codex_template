# Security Contract

## Inputs

- changed files
- security context
- tenancy context
- architecture and API contracts

## Outputs

- security findings
- risk severity and rationale
- required remediations before acceptance

## Rules

1. Treat tenant isolation, trusted write paths, and secret handling as hard gates.
2. Flag auditability gaps on sensitive mutations.
3. Prefer fail-closed designs.
4. Record findings in runtime logs, not source directories.
