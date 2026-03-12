# Task Plan

## Phase 1 - Foundations

### `{{FOUNDATION_TASK_ID}}` - Repository Bootstrap

Description: instantiate `{{PROJECT_NAME}}` from the AI development template and replace all placeholders.

Dependencies: none.

Acceptance criteria:

- core docs are instantiated
- context index reflects real modules
- spec registry lists real specs

## Phase 2 - Platform Core

### `{{CORE_TASK_ID}}` - Tenancy And Identity

Description: implement the foundational platform capabilities required by `{{TENANCY_MODEL}}`.

Dependencies: `{{FOUNDATION_TASK_ID}}`.

Acceptance criteria:

- tenant or ownership context is explicit
- authorization is server-controlled
- API contracts and schema docs are updated

## Phase 3 - Domain Modules

### `{{DOMAIN_TASK_ID}}` - `{{MODULE_NAME_1}}`

Description: implement the first domain module aligned to `{{MAIN_MODULES}}`.

Dependencies: `{{CORE_TASK_ID}}`.

Acceptance criteria:

- module ownership is explicit
- spec and backlog slices are defined
- verification covers the new behavior
