# Design System

## Purpose

This document defines the default visual and interaction language for frontend work in projects created from this template.

## Component And Styling Baseline

- use Tailwind CSS for utility-first styling
- use shadcn/ui for accessible, production-grade primitives when the framework supports it
- treat shadcn/ui as a starting point, not as unedited demo UI
- centralize colors, spacing, radius, shadows, and motion through tokens

## Visual Direction

### Layout

- prioritize generous whitespace over dense dashboards by default
- use clear content width constraints and consistent rhythm between sections
- keep scanning easy on both mobile and desktop

### Typography

- use one font family across product UI
- recommended defaults: `Inter` or `Geist Sans`
- create clear scale steps for page title, section title, body, helper text, and caption
- use weight and size to create hierarchy before adding decoration

### Color System

- define semantic tokens for background, foreground, muted, border, accent, success, warning, and destructive states
- support both light and dark mode from the same token system
- avoid one-off hex values in components when a semantic token should exist
- interactive states must have explicit hover, active, focus, disabled, and loading styling

### Shape, Elevation, And Motion

- default radius: `rounded-lg`
- use soft shadows and restrained borders to separate surfaces
- transitions should feel deliberate and fast, never decorative for their own sake
- motion must support reduced-motion preferences

## Interaction Rules

1. Every clickable control must have a visible hover and focus state.
2. Every async action must show pending feedback.
3. Every data surface must define loading, empty, error, and success states.
4. Forms must expose label, help text when needed, and inline error messaging.
5. Destructive actions must be visually distinct and require confirmation when risk is meaningful.

## Accessibility Rules

- text and meaningful icons must meet WCAG AA contrast targets
- all interactive elements must be reachable and operable by keyboard
- use semantic HTML elements before ARIA fallbacks
- every form field needs an associated label
- informative images need descriptive alt text; decorative images use `alt=""`

## Responsive Rules

- design mobile-first and scale upward
- preserve readable line lengths and spacing at wide layouts
- avoid hiding essential actions behind hover-only patterns
- keep target sizes comfortable on touch devices

## Implementation Notes

- build app-specific components on top of shared primitives
- prefer tokenized Tailwind classes over arbitrary values
- document any intentional design system exceptions in the linked spec
- do not ship frontend work that skips state design just because backend integration is incomplete
