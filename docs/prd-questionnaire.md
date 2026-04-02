# PRD Questionnaire

Use this file to capture raw product inputs before generating or refining `docs/prd.md`.

Answer with concrete detail. Short answers are acceptable at first, but avoid vague placeholders when you already know the constraint.

Answer for the target project being created from this template, not for the template repository itself.

## 1. Product Definition

- Project profile:
- Delivery mode:
- Project name:
- One-sentence product summary:
- What business problem does this solve?
- Why does this matter now?
- What happens if this product does not exist?

Suggested project profiles:

- `generic`
- `saas-b2b`
- `internal-tool`
- `api-service`
- `ecommerce`
- `marketplace`
- `ai-automation`
- `institutional-site`
- `integration-platform`

Suggested delivery modes:

- `greenfield`
- `existing-product-evolution`
- `mvp`
- `discovery`
- `migration`
- `integration-project`
- `replatform`
- `maintenance`

## 2. Users And Stakeholders

- Primary user segments:
- Secondary user segments:
- Internal stakeholders:
- Who approves scope and business rules?
- Who operates the system day to day?

## 3. Target Outcomes

- What business outcomes define success?
- What user outcomes define success?
- What operational outcomes define success?
- What metrics or signals should improve?

## 4. Scope

### In Scope

- Core capabilities for the first release:
- Must-have workflows:
- Required admin or backoffice capabilities:

### Out Of Scope

- Explicitly excluded capabilities:
- Future-phase ideas that should not enter the first release:

## 5. User Journeys

For each critical journey, describe:

- actor
- trigger
- step-by-step flow
- success result
- failure cases

Journeys:

- Journey 1:
- Journey 2:
- Journey 3:

## 6. Frontend Experience And UI Quality

Answer this section whenever the project has a browser UI, backoffice, portal, dashboard, or any other user-facing frontend.

- Primary user-facing surfaces:
- Platforms in scope: web desktop, mobile web, tablet, native mobile, kiosk, other
- Visual direction or brand references:
- Component and styling expectations:
- Theme requirements: light mode, dark mode, both, not applicable
- Critical interaction states that must exist: loading, empty, error, success, disabled, onboarding, permission denied, other
- Accessibility requirements:
- Keyboard navigation and focus expectations:
- Responsive priorities and target devices:
- Frontend performance expectations or budgets:
- Motion or animation constraints:
- Need for design approval, benchmark references, or visual regression evidence:

If the project has no user-facing frontend, write `not applicable` and explain the primary interface surface instead.

## 7. Functional Requirements

List the most important functional requirements in detail.

For each requirement, capture:

- ID:
- Description:
- Inputs:
- Outputs:
- Business rules:
- Acceptance criteria:

Requirements:

- FR-01:
- FR-02:
- FR-03:

## 8. Domain And Data

- Core entities:
- Important attributes per entity:
- Ownership rules:
- Lifecycle rules:
- Tenant ownership rules, if applicable:
- Audit/history requirements:

## 9. Integrations

- External systems:
- Internal systems:
- APIs to consume:
- APIs to expose:
- Authentication or authorization constraints:
- Data sync or webhook needs:

## 10. Technical Stack

- Frontend stack:
- Backend stack:
- Mobile stack, if any:
- Data/storage stack:
- Infrastructure or hosting stack:
- External platforms or managed services:
- Tooling constraints:

## 11. Architecture And Technical Constraints

- Preferred architecture:
- Hosting or infrastructure constraints:
- Performance constraints:
- Availability or resiliency expectations:
- Observability requirements:
- Deployment constraints:

## 12. Security, Compliance, And Risk

- Sensitive data handled:
- Compliance requirements:
- Tenant isolation requirements:
- Authorization model:
- Abuse or fraud concerns:
- Security risks already known:

## 13. Delivery Constraints

- Timeline expectations:
- Team composition:
- Existing codebase or system context:
- Must-preserve systems or contracts:
- Test and verification expectations:
- Delivery risks specific to the chosen delivery mode:

## 14. Open Questions

- Open product questions:
- Open technical questions:
- Open policy or compliance questions:

## 15. Assumptions

- Assumption 1:
- Assumption 2:
- Assumption 3:
