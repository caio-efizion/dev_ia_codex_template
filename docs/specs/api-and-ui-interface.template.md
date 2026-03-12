# API And UI Interface Specification

## Scope

- capability: API and UI Interface
- routes or surfaces: `{{API_SURFACES}}`

## Responsibilities

- route composition
- DTO serialization
- request validation
- tenant and auth context resolution

## Contracts

- base path: `{{API_BASE_PATH}}`
- public routes: `{{PUBLIC_ROUTES}}`
- protected routes: `{{PROTECTED_ROUTES}}`
- versioning: `{{API_VERSIONING_STRATEGY}}`

## UI Rules

- keep business logic out of presentation code
- keep user-visible copy localizable
- expose loading, empty, and error states explicitly

## Test Scenarios

- `{{INTERFACE_TEST_1}}`
- `{{INTERFACE_TEST_2}}`
