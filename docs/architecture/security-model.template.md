# Security Model

## Scope

This document defines the security posture for `{{PROJECT_NAME}}`.

## Core Controls

- trusted write paths only
- server-side authorization
- explicit `{{TENANCY_MODEL}}` enforcement
- secret isolation outside version control
- auditability for sensitive mutations

## Required Practices

1. resolve tenant or ownership context on trusted paths
2. keep credentials in environment variables or secret managers
3. redact secrets and unnecessary personal data from logs
4. require review for cross-boundary integrations
5. document security-sensitive assumptions in specs and API contracts
