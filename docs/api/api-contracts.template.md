# API Contracts

## Scope

This document defines the API conventions for `{{PROJECT_NAME}}`.

## Conventions

- base path: `{{API_BASE_PATH}}`
- versioning strategy: `{{API_VERSIONING_STRATEGY}}`
- authentication model: `{{AUTH_MODEL}}`
- tenancy model: `{{TENANCY_MODEL}}`
- pagination strategy: `{{PAGINATION_STRATEGY}}`
- filtering strategy: `{{FILTERING_STRATEGY}}`
- validation strategy: `{{VALIDATION_STRATEGY}}`
- audit and correlation metadata: `{{REQUEST_ID_AND_AUDIT_CONTEXT}}`

## Request Envelope

```json
{
  "requestId": "{{REQUEST_ID}}",
  "tenantContext": "{{TENANT_CONTEXT}}",
  "payload": {}
}
```

## Success Envelope

```json
{
  "ok": true,
  "data": {},
  "meta": {
    "requestId": "{{REQUEST_ID}}"
  }
}
```

## Error Envelope

```json
{
  "ok": false,
  "error": {
    "code": "{{ERROR_CODE}}",
    "message": "{{ERROR_MESSAGE}}",
    "details": []
  },
  "meta": {
    "requestId": "{{REQUEST_ID}}"
  }
}
```

## Contract Rules

1. Protected routes resolve authorization server-side.
2. Tenant-owned operations require explicit tenant context.
3. Contracts must define failure modes and validation semantics.
4. Schema or endpoint drift updates this file in the same slice.
5. Response shapes must be stable enough for shared frontend hooks and screens.
