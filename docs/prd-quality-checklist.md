# PRD Quality Checklist

- project_profile: `{{PROJECT_PROFILE}}`
- technical_stack: `{{TECH_STACK}}`
- delivery_mode: `{{DELIVERY_MODE}}`
- readiness_level: `L2`
- last_reviewed_at: `2026-04-02T22:23:20.720Z`
- review_rule: `Only L4 is ready for strict pipeline execution.`

Allowed status values:

- `pass`
- `partial`
- `fail`
- `tbd`

## Core Quality Checks

| Area | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Business | Business problem and urgency are explicit | `fail` | `Business Problem And Why Now` | |
| Specificity | The PRD describes the target project, not the reusable template or framework | `fail` | `Project Overview` | |
| Users | Primary users, operators, and stakeholders are defined | `fail` | `Users, Stakeholders, And Ownership` | |
| Scope | In-scope and out-of-scope boundaries are explicit | `fail` | `Scope Boundaries` | |
| Journeys | Core workflows are described end-to-end | `fail` | `User Journeys` | |
| Functional | Functional requirements are concrete and non-generic | `fail` | `Functional Requirements` | |
| Acceptance | Requirements have testable acceptance criteria | `fail` | `Functional Requirements` | |
| Domain | Entities, ownership, and lifecycle expectations are described | `fail` | `Domain Model And Data Lifecycle` | |
| Integrations | External/internal integrations and contracts are identified | `fail` | `Integrations And External Systems` | |
| Architecture | Technical and architecture constraints are explicit | `fail` | `Project And Delivery Constraints#Non-Functional Requirements` | |
| Frontend | User-facing surfaces, states, accessibility, and responsive expectations are explicit when UI exists | `fail` | `User Experience And Interface Expectations#Functional Requirements` | |
| NFRs | Performance, reliability, observability, and scale are covered | `pass` | `Non-Functional Requirements` | |
| Security | Security, compliance, privacy, and tenancy constraints are explicit | `fail` | `Non-Functional Requirements#Security` | |
| Delivery | Risks, assumptions, dependencies, and open questions are explicit | `fail` | `Delivery And Verification Requirements#Risks, Assumptions, And Open Questions` | |

## Classification Checks

| Area | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Profile | The project profile is explicit and fits the product being described | `pass` | `{{PROJECT_PROFILE}}` | |
| Stack | The technical stack is explicit enough to constrain architecture and implementation decisions | `fail` | `{{TECH_STACK}}` | |
| Delivery Mode | The delivery mode is explicit and its constraints are reflected in the PRD | `pass` | `{{DELIVERY_MODE}}` | |
| Alignment | Project profile, technical stack, and delivery mode do not conflict with each other | `fail` | `{{PROJECT_PROFILE}} / {{TECH_STACK}} / {{DELIVERY_MODE}}` | |

## Profile-Specific Checks

| Profile | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
| `{{PROJECT_PROFILE}}` | Operational ownership and reviewer workflow constraints are explicit | `pass` | `Users, Stakeholders, And Ownership#Project And Delivery Constraints` | |

## Stack-Specific Checks

| Stack Area | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
| `{{TECH_STACK}}` | Frontend implementation and verification toolchain are explicit | `fail` | `Project Classification#Delivery And Verification Requirements` | |

## Delivery-Mode Checks

| Delivery Mode | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
| `{{DELIVERY_MODE}}` | Current route/contracts are preserved and scope stays bounded | `pass` | `Existing Product Context#Project And Delivery Constraints` | |

## Gate Summary

- overall_assessment: `needs more clarity before pipeline execution`
- ready_for_pipeline: `no`
- minimum_fixes_required:
  - `Business: Business problem and urgency are explicit`
  - `Specificity: The PRD describes the target project, not the reusable template or framework`
  - `Users: Primary users, operators, and stakeholders are defined`
  - `Scope: In-scope and out-of-scope boundaries are explicit`
  - `Journeys: Core workflows are described end-to-end`
  - `Functional: Functional requirements are concrete and non-generic`
  - `Acceptance: Requirements have testable acceptance criteria`
  - `Domain: Entities, ownership, and lifecycle expectations are described`
  - `Integrations: External/internal integrations and contracts are identified`
  - `Architecture: Technical and architecture constraints are explicit`
  - `Frontend: User-facing surfaces, states, accessibility, and responsive expectations are explicit when UI exists`
  - `Security: Security, compliance, privacy, and tenancy constraints are explicit`
  - `Delivery: Risks, assumptions, dependencies, and open questions are explicit`
  - `Stack: The technical stack is explicit enough to constrain architecture and implementation decisions`
  - `Alignment: Project profile, technical stack, and delivery mode do not conflict with each other`
  - `frontend-stack: Frontend implementation and verification toolchain are explicit`
