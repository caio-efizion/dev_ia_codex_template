# AI Development System

## Overview

`{{PROJECT_NAME}}` uses a multi-agent development workflow aligned to `{{SYSTEM_ARCHITECTURE}}`.

## Agent Flow

1. Orchestrator selects or unblocks a slice.
2. Planner maintains task structure.
3. Specification Agent maintains spec quality.
4. Builder implements one ready slice.
5. Reviewer checks architectural compliance.
6. Tester validates behavior.
7. Security audits trusted paths.

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
