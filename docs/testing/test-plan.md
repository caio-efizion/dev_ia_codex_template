# Test Plan

## Scope

This document defines how `{{PROJECT_NAME}}` is verified.

## Test Layers

- unit: `{{UNIT_TEST_SCOPE}}`
- integration: `{{INTEGRATION_TEST_SCOPE}}`
- API: `{{API_TEST_SCOPE}}`
- end-to-end: `{{E2E_TEST_SCOPE}}`
- accessibility: `{{A11Y_TEST_SCOPE}}`
- visual-regression: `{{VISUAL_REGRESSION_SCOPE}}`

## Required Checks Per Slice

1. run the smallest correct local verification set
2. run build verification when it materially reduces risk
3. use TestSprite when available
4. record any remaining gaps
5. when UI changes, verify loading, empty, error, and success states
6. when UI changes, verify keyboard access and visible focus behavior
7. when UI changes materially, run critical-path end-to-end coverage and the best available accessibility checks
