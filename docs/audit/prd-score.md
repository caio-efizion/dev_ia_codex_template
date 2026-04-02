# PRD Quality Score

- project_profile: {{PROJECT_PROFILE}}
- technical_stack: {{TECH_STACK}}
- delivery_mode: {{DELIVERY_MODE}}
- readiness_level: L2
- overall_score: 60
- ready_for_pipeline: no
- minimum_recommended_score: 80
- gate_decision: blocked

## Dimension Scores

| Dimension | Score (0-5) |
| --- | --- |
| clarity | 3 |
| completeness | 3 |
| consistency | 3 |
| testability | 3 |
| architecture readiness | 3 |
| security/compliance readiness | 3 |
| operational readiness | 3 |
| delivery readiness | 3 |

## Critical Gaps

- Business: Business problem and urgency are explicit
- Specificity: The PRD describes the target project, not the reusable template or framework
- Users: Primary users, operators, and stakeholders are defined
- Scope: In-scope and out-of-scope boundaries are explicit
- Journeys: Core workflows are described end-to-end
- Functional: Functional requirements are concrete and non-generic
- Acceptance: Requirements have testable acceptance criteria
- Domain: Entities, ownership, and lifecycle expectations are described
- Integrations: External/internal integrations and contracts are identified
- Architecture: Technical and architecture constraints are explicit
- Frontend: User-facing surfaces, states, accessibility, and responsive expectations are explicit when UI exists
- Security: Security, compliance, privacy, and tenancy constraints are explicit
- Delivery: Risks, assumptions, dependencies, and open questions are explicit
- Stack: The technical stack is explicit enough to constrain architecture and implementation decisions
- Alignment: Project profile, technical stack, and delivery mode do not conflict with each other
- frontend-stack: Frontend implementation and verification toolchain are explicit

## Minimum Fixes Required

- Business problem and urgency are explicit
- The PRD describes the target project, not the reusable template or framework
- Primary users, operators, and stakeholders are defined
- In-scope and out-of-scope boundaries are explicit
- Core workflows are described end-to-end
- Functional requirements are concrete and non-generic
- Requirements have testable acceptance criteria
- Entities, ownership, and lifecycle expectations are described
- External/internal integrations and contracts are identified
- Technical and architecture constraints are explicit
- User-facing surfaces, states, accessibility, and responsive expectations are explicit when UI exists
- Security, compliance, privacy, and tenancy constraints are explicit
- Risks, assumptions, dependencies, and open questions are explicit
- The technical stack is explicit enough to constrain architecture and implementation decisions
- Project profile, technical stack, and delivery mode do not conflict with each other
- Frontend implementation and verification toolchain are explicit

## Rationale

- selected project profile: `{{PROJECT_PROFILE}}`
- identified technical stack: `{{TECH_STACK}}`
- identified delivery mode: `{{DELIVERY_MODE}}`
- score is based on explicit PRD structure, absence of template placeholders, frontend-state completeness, security expectations, and blocking verification clarity
- strict gate result: `blocked`
