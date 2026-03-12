# Background Jobs Specification

## Scope

- capability: Background Jobs
- runtimes: `{{BACKGROUND_RUNTIME}}`
- job categories: `{{JOB_CATEGORIES}}`

## Responsibilities

- dispatch durable jobs
- process retries safely
- expose status and progress
- keep long-running work out of interactive request paths

## Data And Contracts

- job tables: `{{JOB_TABLES}}`
- event sources: `{{EVENT_SOURCES}}`
- operator APIs: `{{JOB_OPERATOR_APIS}}`

## Reliability Rules

- handlers are idempotent
- retries are bounded and observable
- poison jobs are quarantined or escalated

## Test Scenarios

- `{{JOB_TEST_1}}`
- `{{JOB_TEST_2}}`
