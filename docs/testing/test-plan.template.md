# Test Plan

## Scope

This document defines how `{{PROJECT_NAME}}` is verified.

## Test Layers

- unit: `{{UNIT_TEST_SCOPE}}`
- integration: `{{INTEGRATION_TEST_SCOPE}}`
- API: `{{API_TEST_SCOPE}}`
- end-to-end: `{{E2E_TEST_SCOPE}}`

## Required Checks Per Slice

1. run the smallest correct local verification set
2. run build verification when it materially reduces risk
3. use TestSprite when available
4. record any remaining gaps
