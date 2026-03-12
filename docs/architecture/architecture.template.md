# System Architecture

## Purpose

This document defines the target architecture for `{{PROJECT_NAME}}`.

## Summary

- system architecture: `{{SYSTEM_ARCHITECTURE}}`
- tech stack: `{{TECH_STACK}}`
- tenancy model: `{{TENANCY_MODEL}}`
- main modules: `{{MAIN_MODULES}}`

## Principles

1. Keep one coherent deployable system until extraction is justified.
2. Make module ownership explicit.
3. Keep protected writes server-controlled.
4. Separate durable docs from runtime execution artifacts.
5. Make architectural relationships discoverable through context layers and indexes.

## Runtime Topology

- interactive surface: `{{INTERACTIVE_RUNTIME}}`
- background processing: `{{BACKGROUND_RUNTIME}}`
- system of record: `{{DATA_STORE}}`
- external integrations: `{{INTEGRATIONS}}`

## Delivery Topology

- durable source docs: `docs/`, `tasks/`, `ai/`
- compressed rehydration: `ai/context-compressed/`
- relationship graph: `ai/context-index/context-map.json`
- runtime logs and state: `runtime/`

## Module Strategy

The project organizes `{{MAIN_MODULES}}` as explicit modules with published contracts, owned data, and documented dependencies.
