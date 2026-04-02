# Frontend Quality Gates

## Purpose

This document defines the blocking quality gates for user-facing frontend work.

These gates apply whenever a slice changes browser UI, layout behavior, interaction patterns, client-side performance, or interface contracts that affect the user journey.

## Gate 1: Design System Compliance

The slice must:

- use the documented token system
- reuse shared primitives before inventing new visual patterns
- avoid raw, unrefined library defaults in final UI
- keep spacing, typography, and visual hierarchy consistent with the design system

## Gate 2: State Completeness

Every affected surface must define:

- loading state
- empty state when data may be absent
- error state with recovery path when possible
- disabled or pending state for async actions
- success confirmation when the action changes user-visible state

## Gate 3: Accessibility

The slice must pass:

- semantic HTML review
- keyboard navigation review
- visible focus-state review
- form labeling review
- image alt-text review
- automated accessibility checks for affected critical paths

Minimum target:

- WCAG AA contrast for text and essential icons

## Gate 4: Responsive Behavior

The slice must be verified at minimum in:

- small mobile viewport
- common tablet or narrow laptop viewport
- desktop viewport

The UI must remain usable without layout overlap, clipped actions, or unreadable density.

## Gate 5: Performance

Use the best available verification for the stack and hosting model.

Default budgets for critical routes unless the project documents stricter values:

- LCP: less than or equal to 2.5s
- INP: less than or equal to 200ms
- CLS: less than or equal to 0.1
- Lighthouse Performance: 85 or higher on critical routes
- Lighthouse Accessibility: 95 or higher on critical routes

If these exact checks are not available yet, record the gap and provide the closest measurable proxy.

## Gate 6: Test Coverage

When frontend behavior changes materially, require:

- component or interaction tests for critical UI logic when practical
- end-to-end coverage for the happy path of the affected user journey
- at least one failure-path or empty-state journey when relevant
- visual regression evidence for key components or pages when visual change risk is significant

## Gate 7: Observability

When the project maturity justifies it, affected frontend work should expose:

- runtime error capture
- route or journey timing visibility
- web-vitals or RUM instrumentation on critical flows

## Manual Review Checklist

Reviewers and frontend auditors should explicitly check:

1. Does the UI look intentionally designed rather than scaffolded?
2. Are loading, empty, error, and success states all visible and coherent?
3. Can the main workflow be completed with keyboard only?
4. Does the mobile layout preserve priority actions?
5. Did the change introduce layout shift, sluggish interaction, or visual inconsistency?
