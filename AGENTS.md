# Repository Agent Guide

This repository is a reusable AI development template for multi-agent SaaS delivery.

The canonical operating model lives in [ai/system/operating-model.md](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/system/operating-model.md).

## Required Reading Order

Before changing architecture, templates, or agent workflows, read:

1. [docs/prd.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/prd.template.md)
2. [docs/adr/0001-system-architecture.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/adr/0001-system-architecture.template.md)
3. [docs/architecture/STRUCTURE_RULES.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/architecture/STRUCTURE_RULES.template.md)
4. [docs/architecture/architecture.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/architecture/architecture.template.md)
5. [docs/architecture/module-map.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/architecture/module-map.template.md)
6. [docs/specs/coding-standards.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/specs/coding-standards.template.md)
7. [tasks/tasks.template.md](/root/desenvolvimento-vscode/dev_ia_codex_template/tasks/tasks.template.md)
8. [ai/system/workflow.md](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/system/workflow.md)
9. [ai/system/operating-model.md](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/system/operating-model.md)

When the template is instantiated for a real project, prefer the generated non-template files first and fall back to template files only when the generated equivalents do not exist yet.

## Core Rules

1. Keep reusable source guidance in `ai/`, `docs/`, and `tasks/`.
2. Keep generated logs, graphs, and agent state in `runtime/` only.
3. Update `ai/context-index/context-map.json` and `ai/spec-registry/specs.yaml` when modules, APIs, schemas, or specs change.
4. Preserve modular boundaries and trusted write paths.
5. Require explicit tenant context for tenant-owned operations.
6. Keep business logic and persisted values language-neutral, even if the first UI release is `pt-BR`.
7. Never commit secrets, tokens, or private credentials.

## Agent Locations

- agent definitions: [ai/agents](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/agents)
- prompts: [ai/prompts](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/prompts)
- contracts: [ai/contracts](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/contracts)
- context layer: [ai/context](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/context)
- compressed context: [ai/context-compressed](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/context-compressed)
- context index: [ai/context-index/context-map.json](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/context-index/context-map.json)
- spec registry: [ai/spec-registry/specs.yaml](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/spec-registry/specs.yaml)

## Runtime Policy

`runtime/` is reserved for ephemeral execution state. The committed repository keeps only `.gitkeep` files there.

## Orchestrator Entry Point

When the user says `run orchestrator`, use [ai/agents/orchestrator.md](/root/desenvolvimento-vscode/dev_ia_codex_template/ai/agents/orchestrator.md) in continuous mode unless they explicitly ask for a single slice.

## Preserved Source Material

The original project-specific repository snapshot is preserved under [docs/archive/original-project](/root/desenvolvimento-vscode/dev_ia_codex_template/docs/archive/original-project) for reference during future template evolution.
