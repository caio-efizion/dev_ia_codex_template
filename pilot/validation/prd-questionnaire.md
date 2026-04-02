# PRD Questionnaire

Use this fixture to validate the `PRD-first` pipeline against the reference frontend app in `pilot/reference-web-app`.

## 1. Product Definition

- Project profile: `internal-tool`
- Delivery mode: `existing-product-evolution`
- Project name: `Reference Operations Quality Inbox`
- One-sentence product summary: A small internal web app that helps operations reviewers triage quality findings with explicit UI states, accessible controls, and measurable frontend evidence.
- What business problem does this solve? Reviewers currently see the queue but cannot use the existing filter chips to narrow the list, so high-priority work is harder to triage quickly during daily review sessions.
- Why does this matter now? This repository needs a deterministic pilot that proves the template can take a concrete requirement, generate the right docs, implement a bounded frontend slice, and pass blocking gates without manual intervention.
- What happens if this product does not exist? The template will keep claiming frontend maturity without proving a real `questionnaire -> PRD -> run` loop against an actual project surface.

## 2. Users And Stakeholders

- Primary user segments: Internal operations reviewers, product quality analysts
- Secondary user segments: Engineering leads auditing frontend delivery quality
- Internal stakeholders: Platform engineering, design systems governance, delivery leadership
- Who approves scope and business rules? Efizion platform lead
- Who operates the system day to day? Internal reviewers running quality triage sessions

## 3. Target Outcomes

- What business outcomes define success? Faster triage of urgent findings and a reproducible pilot that demonstrates reliable autonomous delivery.
- What user outcomes define success? Reviewers can switch between all items, high-priority items, and the soonest ETA view without losing context or accessibility.
- What operational outcomes define success? The full pipeline produces a PRD, backlog/spec artifacts, implementation, test evidence, frontend evidence, and security reports in a repeatable way.
- What metrics or signals should improve? Reviewers can isolate high-priority items in one interaction, the full pilot quality suite passes without manual repair, and frontend evidence remains reproducible across repeated runs.

## 4. Scope

### In Scope

- Core capabilities for the first release: Make the existing filter chips functional in the success state of the reference inbox.
- Must-have workflows: View the queue, activate a filter chip, see the list and summary update, preserve explicit empty/loading/error/success handling, and keep keyboard accessibility intact.
- Required admin or backoffice capabilities: Not applicable beyond the existing internal queue screen.

### Out Of Scope

- Explicitly excluded capabilities: Authentication, persistence, backend APIs, multi-page routing, drag-and-drop, real-time sync, new visual themes, and redesigning the entire page.
- Future-phase ideas that should not enter the first release: Saved views, free-text search behavior, per-user preferences, analytics dashboards, and collaborative review workflows.

## 5. User Journeys

Journeys:

- Journey 1:
  - actor: Internal reviewer
  - trigger: Opens the inbox in the default success state
  - step-by-step flow: Open `/` -> scan summary metrics -> confirm all items are visible -> identify the current active filter chip
  - success result: Reviewer understands the current queue state immediately
  - failure cases: Missing focus indicators, wrong active filter state, metrics not matching visible items
- Journey 2:
  - actor: Internal reviewer
  - trigger: Needs to focus only on urgent work
  - step-by-step flow: Open `/` -> activate `High risk` chip -> list narrows to high-priority findings -> metrics reflect the filtered result -> chip exposes an accessible active state
  - success result: Reviewer sees only urgent items and can move with keyboard between chips without confusion
  - failure cases: Chip is not keyboard reachable, filtered list is wrong, active state is not announced, counts stay stale
- Journey 3:
  - actor: Internal reviewer
  - trigger: Needs to quickly review the newest items
  - step-by-step flow: Open `/` -> activate `Soonest ETA` chip -> list sorts by the deterministic ETA rank -> reviewer can return to `All`
  - success result: The list order reflects the selected mode and the user can switch back without layout breakage
  - failure cases: Sorting is inconsistent, buttons do not expose pressed state, responsive layout regresses on mobile

## 6. Frontend Experience And UI Quality

- Primary user-facing surfaces: Single queue page at `/` inside `pilot/reference-web-app`
- Platforms in scope: web desktop, mobile web, tablet
- Visual direction or brand references: Preserve the existing premium internal-ops console look with dark neutral surfaces, teal accents, generous spacing, and clear emphasis on metrics and queue items
- Component and styling expectations: Keep Tailwind CSS, keep the current handcrafted structure, and use accessible button semantics instead of adding a new component library for this pilot slice
- Theme requirements: dark mode only for this pilot
- Critical interaction states that must exist: loading, empty, error, success, disabled, filtered-empty success
- Accessibility requirements: WCAG AA contrast, semantic buttons, visible focus rings, clear active-state communication, and zero serious axe violations
- Keyboard navigation and focus expectations: All chips and actions must be tabbable, visibly focused, and operable with keyboard only
- Responsive priorities and target devices: 390x844 mobile, 1024x768 tablet, 1440x900 desktop
- Frontend performance expectations or budgets: Lighthouse performance >= 85 and accessibility >= 95 on the critical route
- Motion or animation constraints: Keep animation subtle; skeletons may pulse, but no distracting motion or delayed interaction
- Need for design approval, benchmark references, or visual regression evidence: The slice must generate screenshots, accessibility evidence, Lighthouse results, and visual regression comparison outputs

## 7. Functional Requirements

Requirements:

- FR-01:
  - ID: `FR-01`
  - Description: The queue filter chips must become functional in the success state.
  - Inputs: User clicks or keyboard-activates `All`, `High risk`, or `Soonest ETA`
  - Outputs: The visible queue items, active chip state, and summary feedback reflect the selected mode
  - Business rules: `All` shows every queue item; `High risk` shows only items with priority `High`; `Soonest ETA` keeps the same items but orders the list by an explicit deterministic ETA rank stored in the local view model
  - Acceptance criteria:
    - The active chip is visually distinct and exposes an accessible selected/pressed state
    - The queue list updates immediately when the chip changes
    - The default page load shows `All` as active
    - Filter selection is local UI state only for this pilot; the URL continues to control only the overall page state (`loading`, `empty`, `error`, `success`)
- FR-02:
  - ID: `FR-02`
  - Description: Summary feedback must stay coherent with the filtered list.
  - Inputs: Current filter mode and current queue data
  - Outputs: Metrics and helper text that match the items currently visible
  - Business rules: `Open items` and `High priority` always recalculate from the currently visible list; the third metric may stay mode-specific helper context; helper text must explicitly say when the mode is a reorder instead of a reduction
  - Acceptance criteria:
    - The filtered result exposes accurate item count feedback
    - The `High risk` filter never shows medium-priority items
    - The `Soonest ETA` mode communicates that the list is reordered rather than reduced
- FR-03:
  - ID: `FR-03`
  - Description: Existing non-success states must remain explicit and stable.
  - Inputs: `state=loading|empty|error|success` query parameter
  - Outputs: The existing state-specific UI remains intact and accessible
  - Business rules: Loading keeps controls disabled where already defined; error keeps the alert and retry action; empty keeps the recovery CTA; if a success-state filter returns zero matches, the UI remains in success state and shows a filtered-empty message plus a `Show all` recovery action while keeping chips visible
  - Acceptance criteria:
    - Existing loading, empty, and error journeys continue to pass
    - No state loses semantic roles or focus styles
    - The success-state enhancement does not break the current layout in mobile, tablet, or desktop
    - A zero-match `High risk` result does not reuse the global empty state; it uses a filtered-empty success-state variant

## 8. Domain And Data

- Core entities: Queue item, queue filter mode, summary metric
- Important attributes per entity: Queue item id, title, owner, priority, eta label, deterministic `etaSortOrder`; filter mode id and label; metric label, value, tone
- Ownership rules: Queue items are read-only in this pilot
- Lifecycle rules: Queue items are rendered from local state only; no persistence is required; when `etaSortOrder` values are equal or absent, the original list order is preserved as the tie-breaker
- Tenant ownership rules, if applicable: Not applicable
- Audit/history requirements: Pipeline evidence and reports must show what was changed and validated

## 9. Integrations

- External systems: None
- Internal systems: None beyond the local build/test toolchain
- APIs to consume: None
- APIs to expose: None
- Authentication or authorization constraints: None for this internal pilot
- Data sync or webhook needs: None

## 10. Technical Stack

- Frontend stack: Vite, TypeScript, Tailwind CSS, vanilla DOM rendering
- Backend stack: None
- Mobile stack, if any: None
- Data/storage stack: In-memory local view model only
- Infrastructure or hosting stack: Local static preview served by Vite
- External platforms or managed services: Lighthouse, Playwright, axe, Vitest during verification
- Tooling constraints: Keep the existing pilot toolchain and do not introduce unnecessary dependencies

## 11. Architecture And Technical Constraints

- Preferred architecture: Single-page frontend slice with explicit state model and safe DOM creation
- Hosting or infrastructure constraints: Must run locally through the existing Vite scripts
- Performance constraints: Critical route must satisfy the configured Lighthouse thresholds
- Availability or resiliency expectations: The UI must preserve explicit fallback states and never hide the error state
- Observability requirements: Slice evidence must capture screenshots, Lighthouse results, axe results, and visual regression output
- Deployment constraints: None beyond local reproducibility for the pilot

## 12. Security, Compliance, And Risk

- Sensitive data handled: None
- Compliance requirements: None beyond standard secure coding and no secret exposure
- Tenant isolation requirements: Not applicable
- Authorization model: Not applicable
- Abuse or fraud concerns: Do not introduce unsafe HTML injection or client-side secret handling
- Security risks already known: The template must prevent accidental hardcoded secrets, insecure endpoints, or unsafe DOM rendering patterns

## 13. Delivery Constraints

- Timeline expectations: Complete within a single pilot validation run
- Team composition: Autonomous pipeline with Codex step runner and repository guards
- Existing codebase or system context: A reference frontend already exists under `pilot/reference-web-app` and should be evolved rather than rebuilt
- Must-preserve systems or contracts: Preserve query-param state handling for page state only, existing route `/`, current visual direction, and the quality gate configuration in `pilot/reference-web-app/quality/pipeline.config.json`
- Test and verification expectations: Required gates are lint, typecheck, unit, e2e, coverage, axe, Lighthouse, screenshots, and visual regression
- Delivery risks specific to the chosen delivery mode: Scope inflation, unnecessary redesign, and regressions in existing loading/empty/error states

## 14. Open Questions

- Open product questions: None for the pilot; keep scope intentionally narrow
- Open technical questions: None that should block the pilot
- Open policy or compliance questions: None

## 15. Assumptions

- Assumption 1: The reference app remains a single route and does not need backend integration for this pilot.
- Assumption 2: The first delivery slice can focus on success-state filtering while preserving existing non-success states.
- Assumption 3: Existing quality gate tooling in `pilot/reference-web-app` remains the authoritative validation surface for the pilot.
