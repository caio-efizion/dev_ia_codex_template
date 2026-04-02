# Database Schema

## Scope

This document defines the target schema for `{{PROJECT_NAME}}`.

## Platform-Owned Tables

- `tenants`
- `tenant_memberships`
- `users`
- `sessions`
- `support_sessions`

## Domain-Owned Tables

- `{{MODULE_PRIMARY_TABLES}}`
- `{{MODULE_SECONDARY_TABLES}}`

## Rules

1. document ownership for every table
2. record tenant or ownership columns where required by `{{TENANCY_MODEL}}`
3. define unique constraints and indexes explicitly
4. describe retention and soft-delete behavior when applicable
