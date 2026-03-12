# Tenancy Context

This template is optimized for SaaS projects where tenant isolation is a first-class architectural concern.

## Tenant Model

- every tenant-owned operation resolves an explicit tenant context
- platform-global roles do not replace tenant context
- repositories scope by tenant ownership, not by record id alone
- missing tenant context is a hard failure

## Isolation Layers

1. application layer resolves tenant membership or equivalent access context
2. database or storage layer enforces tenant-safe access
3. contracts describe ownership, failure modes, and support access rules

## Operational Consequences

- schema docs must identify which tables are tenant-owned
- API specs must describe tenant resolution and authorization
- tests must cover cross-tenant rejection
- support workflows require explicit audit trails
