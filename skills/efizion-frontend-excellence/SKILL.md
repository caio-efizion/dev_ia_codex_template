---
name: efizion-frontend-excellence
description: Use when implementing or reviewing user-facing frontend in Efizion projects, especially when the work should follow Tailwind CSS plus shadcn/ui, explicit interaction states, WCAG AA accessibility, responsive behavior, and the repository frontend quality gates. Read the repository frontend governance docs and linked spec first when they exist.
---

# Efizion Frontend Excellence

Use this skill for frontend implementation or review work in repositories derived from the Efizion template.

## Open First

If these files exist in the repository, read them before editing UI code:

- `docs/architecture/frontend-architecture.md`
- `docs/specs/design-system.md`
- `docs/specs/frontend-quality-gates.md`
- `docs/specs/ux-research-and-journeys.md`
- the active linked spec in `docs/specs/`

If a working `.md` file does not exist, use the matching `.template.md` file.

## Build Workflow

1. Confirm the active slice really affects a user-facing surface.
2. Identify the journey, main success path, and required loading, empty, error, success, and disabled states.
3. Reuse existing shared primitives before creating new visual patterns.
4. If the stack supports it, prefer Tailwind CSS for styling and shadcn/ui for accessible primitives.
5. Keep business logic out of leaf presentation components.
6. Build mobile-first, then verify desktop behavior.
7. Keep keyboard navigation, focus visibility, labels, and semantic HTML explicit during implementation.

## Styling Rules

- Use one coherent typography system.
- Prefer tokenized colors, spacing, radius, and shadows over arbitrary values.
- Do not ship raw scaffolded UI or untouched library defaults as final design.
- Make hover, focus, active, disabled, and loading states explicit for interactive controls.

## Frontend Completion Checklist

Before finishing, verify:

- the UI has intentional hierarchy and spacing
- loading, empty, error, success, and disabled states are implemented where relevant
- the main path works on small mobile and desktop layouts
- interactive elements are keyboard reachable and show visible focus
- form fields have labels and error messaging
- sensitive logic stays server-side
- the best available frontend verification has been run or the gap is documented

## Review Bias

When reviewing frontend work, prioritize:

1. broken user journeys
2. missing state handling
3. accessibility regressions
4. poor responsive behavior
5. design-system inconsistency
6. avoidable visual roughness that makes the UI look scaffolded instead of intentional
