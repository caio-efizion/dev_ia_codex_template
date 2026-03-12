# Module Map

## Boundary Rules

- each module owns its write model and invariants
- cross-module interaction happens through published contracts
- shared code contains only cross-cutting primitives

## Baseline Module Inventory

| Module | Owns | Published Contracts | Allowed Dependencies |
| --- | --- | --- | --- |
| Tenant Core | tenants, memberships, entitlements | tenant resolution, membership lookup | none |
| Identity And Access | users, sessions, support access | auth session, permission evaluation | Tenant Core |
| `{{MODULE_NAME_1}}` | `{{MODULE_1_TABLES}}` | `{{MODULE_1_CONTRACTS}}` | `{{MODULE_1_DEPENDENCIES}}` |
| `{{MODULE_NAME_2}}` | `{{MODULE_2_TABLES}}` | `{{MODULE_2_CONTRACTS}}` | `{{MODULE_2_DEPENDENCIES}}` |
| API And UI Interface | no business tables | public API, internal BFF | all published contracts |
| Background Jobs | job orchestration state | job dispatch, status query | published contracts only |

## Notes

- Replace placeholder module rows with the real `{{MAIN_MODULES}}`.
- Keep this file synchronized with `ai/context-index/context-map.json`.
