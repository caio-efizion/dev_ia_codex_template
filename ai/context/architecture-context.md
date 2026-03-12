# Architecture Context

This template assumes an AI-assisted SaaS codebase that is easiest to evolve as a modular monolith first.

## Core Shape

- one repository
- one shared source of truth for product and architecture docs
- domain-oriented modules with explicit ownership
- trusted server-side write paths
- background jobs separated from interactive request flow

## Boundary Rules

- every module owns its write model, repositories, and invariants
- cross-module collaboration happens through published contracts, DTOs, or events
- interface layers may orchestrate modules but must not absorb domain rules
- reporting and analytics consume read models instead of becoming shadow owners of business logic

## AI-System Implications

- durable guidance belongs in `docs/`, `tasks/`, and `ai/`
- fast-loading summaries belong in `ai/context-compressed/`
- machine-readable relationships belong in `ai/context-index/context-map.json`
- runtime state belongs only in `runtime/`

## Migration Guidance

- preserve behavior while moving responsibilities into owned modules
- introduce compatibility adapters before removing legacy paths
- update context index and spec registry whenever a new module, API, or schema seam is created
