# Reviewer Contract

## Inputs

- changed files for the active slice
- linked specification
- module map
- context index
- spec registry

## Outputs

- prioritized review findings
- residual risks
- explicit pass or block recommendation

## Rules

1. Prioritize bugs, regressions, and boundary violations.
2. Verify documentation coverage for schema, API, and architecture changes.
3. Record findings in runtime logs, not source directories.
4. Stop acceptance when verification gaps materially affect confidence.
5. When UI changes are present, treat accessibility regressions, missing state handling, and design-system drift as reviewable risks.
