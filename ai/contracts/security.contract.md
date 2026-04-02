# Security Contract

## Inputs

- changed files
- security context
- tenancy context
- architecture and API contracts
- security policy and matching agent guard

## Outputs

- security findings
- risk severity and rationale
- required remediations before acceptance

## Rules

1. Treat tenant isolation, trusted write paths, and secret handling as hard gates.
2. Flag auditability gaps on sensitive mutations.
3. Prefer fail-closed designs.
4. Record findings in runtime logs, not source directories.
5. When frontend code changes, check that the client surface does not take on privileged decisions or expose sensitive implementation detail.
6. Treat validator failures and secret findings as blocking unless clearly proven to be false positives.
