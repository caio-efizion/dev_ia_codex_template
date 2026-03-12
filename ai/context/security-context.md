# Security Context

The template assumes high trust in server-controlled boundaries and low trust in client input.

## Non-Negotiable Controls

- protected writes are server-trusted
- authorization is evaluated on the server
- secrets stay in environment variables or secret stores
- sensitive mutations emit audit evidence
- logs redact secrets and unnecessary personal data

## Data Protection Model

- the client never supplies authoritative ownership identifiers blindly
- service-role or privileged operations are isolated to trusted backend paths
- object storage and uploads use signed or equivalent controlled flows
- retries and background processing remain idempotent for sensitive commands

## Review Heuristics

- reject direct browser writes to protected tables
- reject cross-tenant reads or writes
- reject contract changes that bypass auditability
- reject runtime logs or state files committed as source material
