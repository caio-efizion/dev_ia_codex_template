# AI Development System

## Overview

`{{PROJECT_NAME}}` uses a multi-agent development workflow aligned to `{{SYSTEM_ARCHITECTURE}}`.

## Agent Flow

1. Orchestrator selects or unblocks a slice.
2. Planner maintains task structure.
3. Specification Agent maintains spec quality.
4. UX/UI Designer makes interface states, accessibility, and responsive behavior explicit for UI-facing slices.
5. Builder implements one ready slice.
6. Reviewer checks architectural compliance.
7. Tester validates behavior.
8. Frontend Auditor checks user-visible quality, accessibility, responsiveness, and performance evidence for UI-facing slices.
9. Security audits trusted paths.

## Supporting Layers

- long-form context: `ai/context/`
- compressed context: `ai/context-compressed/`
- relationship graph: `ai/context-index/context-map.json`
- spec inventory: `ai/spec-registry/specs.yaml`
- runtime artifacts: `runtime/`

## Operating Rules

- prefer generated project docs over templates
- keep runtime artifacts out of source directories
- update context and registry metadata when the architecture changes
- keep frontend architecture, design system, and frontend quality gates aligned with user-facing changes
