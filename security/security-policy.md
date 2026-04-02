# Security Policy

## Purpose

This policy defines the mandatory security controls for the autonomous delivery pipeline.

Security is a blocking cross-cutting layer. No stage may proceed when a relevant risk remains open.

## Security Principles

1. Fail closed when risk cannot be measured confidently.
2. Minimize agent context to the files required for the active step.
3. Treat secrets, credentials, tokens, and tenant-owned data as prohibited output unless the destination is an approved secret-management surface.
4. Validate every stage before execution and after execution.
5. Keep security reports durable under `reports/security/` and runtime-only traces under `runtime/`.

## Secret And Credential Rules

- Never commit `.env`, `.env.local`, `.env.production`, private keys, certificates, or token dumps.
- Allow only explicit example files such as `.env.example`, `.env.template`, and `.env.sample`.
- Use environment variables or secret managers for credentials.
- Hardcoded secrets are always `CRITICAL` risk.
- Secret-like material found in inputs or outputs blocks the pipeline immediately.

## Logging Policy

- Runtime execution traces stay under `runtime/logs/`.
- Durable security audit outputs stay under `reports/security/`.
- Logs must not contain access tokens, full connection strings with credentials, session cookies, or raw personal data.
- Redact sensitive values instead of printing them.

## Data Exposure Rules

- Pass the minimum possible context to each stage.
- Do not expose tenant-owned data to agents that do not need it.
- Do not expose secrets inside prompts, step briefs, reports, screenshots, or generated docs.
- Frontend code must not embed server-only configuration, privileged endpoints, or trust decisions.

## Risk Classification

| Level | Meaning | Pipeline Action |
| --- | --- | --- |
| `LOW` | cosmetic or informational issue with no immediate exploit path | record and continue |
| `MEDIUM` | unsafe pattern or missing control that can become exploitable | block the current stage |
| `HIGH` | exploitable weakness, secret-handling failure, unsafe trust boundary, or significant data-exposure path | fail the pipeline |
| `CRITICAL` | confirmed secret leak, credential exposure, cross-tenant risk, or hardcoded privileged material | fail immediately and stop all remaining stages |

## Blocking Rules

The pipeline must fail when any validator reports:

- `MEDIUM` or higher during input validation for a stage
- `MEDIUM` or higher during output validation for a stage
- any secret leak
- any committed `.env` or private key artifact
- any dependency vulnerability at or above the configured threshold
- missing required security evidence for a stage

## Stage Validation Order

For every stage:

1. input validation
2. agent execution
3. output validation
4. security summary update

A stage is accepted only when all four parts succeed.

## Isolation Rules

- Context routing must prefer the linked spec, contract, changed files, and security guidance before broader docs.
- `runtime/` remains ephemeral; durable evidence belongs in `reports/`.
- Security validators must inspect only the current stage inputs or outputs unless a broader dependency scan is explicitly required.

## Security Reports

Each pipeline run must produce durable reports under `reports/security/<run-id>/` with:

- stage status
- detected violations
- blocking decision
- remediation notes
- final run summary

## Local Enforcement Baseline

The template requires these checks whenever applicable:

- input validation
- output validation
- secret scanning
- static pattern analysis
- dependency scanning
- environment-file validation

If a required check cannot run, the stage fails unless the policy explicitly marks it `not_applicable`.
