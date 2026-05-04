# Development Backlog

- Active task: `none`
- Reason: `{{ACTIVE_TASK_REASON}}`

## Progress Tracker

| Module | Status |
| --- | --- |
| Tenant Core | planned |
| Identity And Access | planned |
| `{{MODULE_NAME_1}}` | planned |
| `{{MODULE_NAME_2}}` | planned |
| API And UI Interface | planned |
| Background Jobs | planned |

## Execution Rules

- each task links to one spec
- dependencies must be explicit
- only one task may be `ready`
- valid statuses: `todo`, `ready`, `done`, `blocked`
- do not advance without validating the current task
- complete each task with its own commit before promoting the next one
- keep the backlog aligned with real specs, context maps, and module ownership

## Backlog

| Task ID | Parent | Module | Feature | Description | Dependencies | Complexity | Type | Spec | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `{{TASK_ID_1}}` | `{{PARENT_1}}` | `{{MODULE_NAME_1}}` | `{{FEATURE_1}}` | `{{DESCRIPTION_1}}` | `{{DEPS_1}}` | `{{COMPLEXITY_1}}` | `{{TYPE_1}}` | `{{SPEC_PATH_1}}` | `todo` |
| `{{TASK_ID_2}}` | `{{PARENT_2}}` | `{{MODULE_NAME_2}}` | `{{FEATURE_2}}` | `{{DESCRIPTION_2}}` | `{{DEPS_2}}` | `{{COMPLEXITY_2}}` | `{{TYPE_2}}` | `{{SPEC_PATH_2}}` | `todo` |
