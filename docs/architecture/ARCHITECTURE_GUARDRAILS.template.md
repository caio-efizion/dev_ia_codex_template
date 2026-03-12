# Architecture Guardrails

This document defines the constraints that all implementation work must respect.

## Guardrails

1. The system architecture is `{{SYSTEM_ARCHITECTURE}}`.
2. Business capabilities are owned by named modules in `{{MAIN_MODULES}}`.
3. Protected writes must run through trusted server-side paths.
4. Tenant or ownership context must be explicit for tenant-owned operations.
5. Shared utilities stay business-agnostic.
6. Generated runtime artifacts stay inside `runtime/`.
7. Context index and spec registry changes are required when architectural relationships change.

## Forbidden Coupling

- direct cross-module repository imports
- business rules defined only in UI code
- runtime logs or state committed as source documentation
- secrets or private credentials in version control
