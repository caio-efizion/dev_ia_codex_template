# Frontend Architecture

## Purpose

This document defines the frontend architecture baseline for projects that expose user-facing interfaces.

If the selected stack has no browser UI, mark this document as not applicable and explain the equivalent interaction surface.

## Baseline Stack

- styling system: Tailwind CSS
- component primitives: shadcn/ui when the chosen framework is compatible
- design tokens: CSS custom properties wired into Tailwind theme tokens
- iconography: one consistent icon set for the whole product
- form patterns: shared field wrappers with label, description, and error slots

If the chosen frontend stack cannot support shadcn/ui directly, document the replacement component strategy explicitly and preserve the same quality bar.

## Architecture Layers

### Application Shell

Owns:

- global layout
- navigation
- theme provider
- route-level loading boundaries
- global notifications

### Feature Surfaces

Own:

- business-facing screens and flows
- feature-level state and data orchestration
- page composition from shared primitives and feature components

### Shared UI

Owns:

- reusable layout primitives
- form building blocks
- feedback states
- data display patterns
- accessibility helpers

### Design Tokens

Own:

- colors
- spacing scale
- typography scale
- radius
- elevation
- motion durations and easing

## Structural Rules

1. Keep business logic out of leaf presentation components.
2. Keep design tokens centralized; avoid ad-hoc color and spacing values unless they are documented exceptions.
3. Prefer composition of small primitives over page-specific monolith components.
4. Make server/client boundaries explicit when the framework supports both rendering modes.
5. Every async screen must define loading, empty, error, and success behavior.
6. Frontend code must not own privileged writes or trust decisions.

## Recommended Repository Shape

Adapt these paths to the chosen framework while keeping the same separation of concerns.

```text
src/
  app/ or routes/
  features/
  components/
    ui/
    shared/
  lib/
    design-system/
    forms/
    accessibility/
```

## Interaction Architecture

- mobile-first layouts are the default
- touch targets must remain usable at small viewports
- route transitions and async actions should provide immediate feedback
- destructive actions should require explicit confirmation
- forms should expose validation near the triggering field and at summary level when needed

## Accessibility Baseline

- semantic HTML first
- visible focus states on all interactive controls
- keyboard reachability for every primary workflow
- color contrast aligned to WCAG AA
- reduced-motion preferences respected for non-essential animation

## Performance Baseline

- ship the smallest practical client bundle per route
- lazy-load non-critical UI and heavy widgets
- optimize media delivery and avoid layout shift
- preserve responsive performance on mid-range mobile devices first

## Required Companion Docs

- `docs/specs/design-system.md`
- `docs/specs/frontend-quality-gates.md`
- `docs/specs/ux-research-and-journeys.md`
