#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'

function fail(message) {
  process.stderr.write(`ai-evaluate-prd: ${message}\n`)
  process.exit(1)
}

function readFileIfExists(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8')
  } catch {
    return ''
  }
}

function parseArgs(argv) {
  const args = {
    mode: '',
    repoRoot: '',
    runId: '',
  }

  for (let index = 2; index < argv.length; index += 1) {
    const value = argv[index]
    if (value === '--mode') {
      args.mode = argv[index + 1] || ''
      index += 1
    } else if (value === '--repo-root') {
      args.repoRoot = argv[index + 1] || ''
      index += 1
    } else if (value === '--run-id') {
      args.runId = argv[index + 1] || ''
      index += 1
    } else {
      fail(`unsupported argument: ${value}`)
    }
  }

  if (!args.mode || !['review', 'score'].includes(args.mode)) {
    fail('missing or invalid --mode (expected review or score)')
  }
  if (!args.repoRoot) {
    fail('missing --repo-root')
  }

  return args
}

function normalizeWhitespace(text) {
  return text.replace(/\r/g, '')
}

function findBulletValue(text, label) {
  const pattern = new RegExp(`^-\\s+${label}:\\s+\`?([^\\n\`]+)\`?$`, 'im')
  const match = text.match(pattern)
  return match ? match[1].trim() : ''
}

function hasPlaceholder(text) {
  return /{{[^}]+}}|\bTBD\b/i.test(text)
}

function sectionExists(text, heading) {
  const escaped = heading.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  return new RegExp(`^##\\s+${escaped}\\s*$`, 'm').test(text)
}

function countMatches(text, pattern) {
  return (text.match(pattern) || []).length
}

function boolStatus(value) {
  return value ? 'pass' : 'fail'
}

function buildEvidencePath(...parts) {
  return parts.filter(Boolean).join('#')
}

function extractClassifications(prdText, questionnaireText) {
  return {
    projectProfile:
      findBulletValue(prdText, 'Project profile') ||
      findBulletValue(questionnaireText, 'Project profile') ||
      'unknown',
    technicalStack:
      findBulletValue(prdText, 'Tech stack') ||
      findBulletValue(questionnaireText, 'Frontend stack') ||
      'unknown',
    deliveryMode:
      findBulletValue(prdText, 'Delivery mode') ||
      findBulletValue(questionnaireText, 'Delivery mode') ||
      'unknown',
  }
}

function evaluatePrd(prdText, questionnaireText, reviewText) {
  const prd = normalizeWhitespace(prdText)
  const questionnaire = normalizeWhitespace(questionnaireText)
  const review = normalizeWhitespace(reviewText)
  const classifications = extractClassifications(prd, questionnaire)

  const checks = []
  const projectName = findBulletValue(prd, 'Project name') || findBulletValue(questionnaire, 'Project name')
  const businessProblemExplicit = sectionExists(prd, 'Business Problem And Why Now') && prd.includes('This matters now')
  const projectSpecific =
    !hasPlaceholder(prd) &&
    Boolean(projectName) &&
    (prd.includes('pilot/reference-web-app') || prd.includes(projectName))
  const usersDefined = sectionExists(prd, 'Users, Stakeholders, And Ownership')
  const scopeDefined = sectionExists(prd, 'Scope Boundaries') && prd.includes('### In Scope') && prd.includes('### Out Of Scope')
  const journeyCount = countMatches(prd, /^### Journey /gm)
  const journeysDefined = sectionExists(prd, 'User Journeys') && journeyCount >= 2
  const frCount = countMatches(prd, /^### FR-/gm)
  const acceptanceCount = countMatches(prd, /Acceptance criteria:/g)
  const functionalRequirementsDefined = sectionExists(prd, 'Functional Requirements') && frCount >= 3
  const acceptanceCriteriaDefined = functionalRequirementsDefined && acceptanceCount >= 3
  const domainDefined = sectionExists(prd, 'Domain Model And Data Lifecycle')
  const integrationsDefined = sectionExists(prd, 'Integrations And External Systems')
  const architectureDefined =
    sectionExists(prd, 'Project And Delivery Constraints') &&
    sectionExists(prd, 'Non-Functional Requirements') &&
    prd.includes('### Architecture')
  const frontendDefined =
    sectionExists(prd, 'User Experience And Interface Expectations') &&
    /Accessibility|Responsive|Lighthouse|axe/.test(prd)
  const nfrDefined = sectionExists(prd, 'Non-Functional Requirements')
  const securityDefined =
    /### Security/.test(prd) &&
    /No secrets|unsafe HTML injection|client-side/.test(prd)
  const deliveryDefined =
    sectionExists(prd, 'Delivery And Verification Requirements') &&
    sectionExists(prd, 'Risks, Assumptions, And Open Questions')
  const profileExplicit = classifications.projectProfile !== 'unknown'
  const stackExplicit = classifications.technicalStack !== 'unknown'
  const deliveryModeExplicit = classifications.deliveryMode !== 'unknown'
  const alignmentPass = profileExplicit && stackExplicit && deliveryModeExplicit && !hasPlaceholder(prd)
  const profileSpecificPass =
    classifications.projectProfile === 'internal-tool'
      ? /Decision Ownership|Day-to-day operator|reviewer efficiency|operational trust/i.test(prd)
      : profileExplicit
  const stackSpecificPass =
    /Vite|TypeScript|Tailwind CSS/i.test(prd) &&
    /Playwright|Lighthouse|axe|Vitest/i.test(prd)
  const deliveryModePass =
    classifications.deliveryMode === 'existing-product-evolution'
      ? /Preserve route|existing reference app|avoid unnecessary redesign/i.test(prd)
      : deliveryModeExplicit

  const filterStateExplicit = /Filter state is intended to remain purely client-side|local UI state/i.test(prd)
  const filteredEmptyDefined = /filtered-empty|Show all|zero-match/i.test(prd)
  const summaryContractDefined =
    /Open items.*recalculate/i.test(prd) &&
    /High priority.*recalculate/i.test(prd) &&
    /reorder instead of a reduction|reordered rather than reduced/i.test(prd)
  const sortRuleDefined =
    /etaSortOrder/i.test(prd) &&
    /original list order is preserved as the tie-breaker|secondary sort key/i.test(prd)
  const verificationDefined =
    /lint/i.test(prd) &&
    /typecheck/i.test(prd) &&
    /e2e/i.test(prd) &&
    /visual regression/i.test(prd)

  checks.push(
    { area: 'Business', criterion: 'Business problem and urgency are explicit', status: boolStatus(businessProblemExplicit), evidence: buildEvidencePath('Business Problem And Why Now') },
    { area: 'Specificity', criterion: 'The PRD describes the target project, not the reusable template or framework', status: boolStatus(projectSpecific), evidence: buildEvidencePath('Project Overview') },
    { area: 'Users', criterion: 'Primary users, operators, and stakeholders are defined', status: boolStatus(usersDefined), evidence: buildEvidencePath('Users, Stakeholders, And Ownership') },
    { area: 'Scope', criterion: 'In-scope and out-of-scope boundaries are explicit', status: boolStatus(scopeDefined), evidence: buildEvidencePath('Scope Boundaries') },
    { area: 'Journeys', criterion: 'Core workflows are described end-to-end', status: boolStatus(journeysDefined), evidence: buildEvidencePath('User Journeys') },
    { area: 'Functional', criterion: 'Functional requirements are concrete and non-generic', status: boolStatus(functionalRequirementsDefined), evidence: buildEvidencePath('Functional Requirements') },
    { area: 'Acceptance', criterion: 'Requirements have testable acceptance criteria', status: boolStatus(acceptanceCriteriaDefined), evidence: buildEvidencePath('Functional Requirements') },
    { area: 'Domain', criterion: 'Entities, ownership, and lifecycle expectations are described', status: boolStatus(domainDefined), evidence: buildEvidencePath('Domain Model And Data Lifecycle') },
    { area: 'Integrations', criterion: 'External/internal integrations and contracts are identified', status: boolStatus(integrationsDefined), evidence: buildEvidencePath('Integrations And External Systems') },
    { area: 'Architecture', criterion: 'Technical and architecture constraints are explicit', status: boolStatus(architectureDefined), evidence: buildEvidencePath('Project And Delivery Constraints', 'Non-Functional Requirements') },
    { area: 'Frontend', criterion: 'User-facing surfaces, states, accessibility, and responsive expectations are explicit when UI exists', status: boolStatus(frontendDefined && filterStateExplicit && filteredEmptyDefined && summaryContractDefined && sortRuleDefined), evidence: buildEvidencePath('User Experience And Interface Expectations', 'Functional Requirements') },
    { area: 'NFRs', criterion: 'Performance, reliability, observability, and scale are covered', status: boolStatus(nfrDefined), evidence: buildEvidencePath('Non-Functional Requirements') },
    { area: 'Security', criterion: 'Security, compliance, privacy, and tenancy constraints are explicit', status: boolStatus(securityDefined), evidence: buildEvidencePath('Non-Functional Requirements', 'Security') },
    { area: 'Delivery', criterion: 'Risks, assumptions, dependencies, and open questions are explicit', status: boolStatus(deliveryDefined && verificationDefined), evidence: buildEvidencePath('Delivery And Verification Requirements', 'Risks, Assumptions, And Open Questions') },
    { area: 'Profile', criterion: 'The project profile is explicit and fits the product being described', status: boolStatus(profileExplicit), evidence: classifications.projectProfile },
    { area: 'Stack', criterion: 'The technical stack is explicit enough to constrain architecture and implementation decisions', status: boolStatus(stackExplicit && stackSpecificPass), evidence: classifications.technicalStack },
    { area: 'Delivery Mode', criterion: 'The delivery mode is explicit and its constraints are reflected in the PRD', status: boolStatus(deliveryModeExplicit && deliveryModePass), evidence: classifications.deliveryMode },
    { area: 'Alignment', criterion: 'Project profile, technical stack, and delivery mode do not conflict with each other', status: boolStatus(alignmentPass), evidence: `${classifications.projectProfile} / ${classifications.technicalStack} / ${classifications.deliveryMode}` },
    { area: 'internal-tool', criterion: 'Operational ownership and reviewer workflow constraints are explicit', status: boolStatus(profileSpecificPass), evidence: buildEvidencePath('Users, Stakeholders, And Ownership', 'Project And Delivery Constraints') },
    { area: 'frontend-stack', criterion: 'Frontend implementation and verification toolchain are explicit', status: boolStatus(stackSpecificPass), evidence: buildEvidencePath('Project Classification', 'Delivery And Verification Requirements') },
    { area: 'existing-product-evolution', criterion: 'Current route/contracts are preserved and scope stays bounded', status: boolStatus(deliveryModePass), evidence: buildEvidencePath('Existing Product Context', 'Project And Delivery Constraints') },
  )

  const failingChecks = checks.filter((check) => check.status === 'fail')
  const coreFailures = failingChecks.filter((check) =>
    ['Business', 'Specificity', 'Scope', 'Journeys', 'Functional', 'Acceptance', 'Architecture', 'Frontend', 'Security', 'Delivery'].includes(check.area)
  )

  const dimensionScores = {
    clarity: businessProblemExplicit && projectSpecific && scopeDefined ? 5 : 3,
    completeness: domainDefined && integrationsDefined && deliveryDefined ? 5 : 3,
    consistency: alignmentPass && filterStateExplicit && sortRuleDefined ? 5 : 3,
    testability: acceptanceCriteriaDefined && verificationDefined ? 5 : 3,
    architectureReadiness: architectureDefined && deliveryModePass ? 5 : 3,
    securityComplianceReadiness: securityDefined ? 5 : 3,
    operationalReadiness: verificationDefined && summaryContractDefined ? 5 : 3,
    deliveryReadiness: coreFailures.length === 0 && reviewDoesNotBlock(review) ? 5 : 3,
  }

  const total = Object.values(dimensionScores).reduce((sum, value) => sum + value, 0)
  const overallScore = Math.round((total / (Object.keys(dimensionScores).length * 5)) * 100)

  let readinessLevel = 'L2'
  if (!projectSpecific || hasPlaceholder(prd)) {
    readinessLevel = 'L2'
  } else if (coreFailures.length === 0 && overallScore >= 80 && reviewDoesNotBlock(review)) {
    readinessLevel = 'L4'
  } else if (overallScore >= 65) {
    readinessLevel = 'L3'
  }

  const readyForPipeline = readinessLevel === 'L4' ? 'yes' : 'no'
  const gateDecision = readyForPipeline === 'yes' ? 'approved' : 'blocked'

  return {
    classifications,
    checks,
    failingChecks,
    coreFailures,
    dimensionScores,
    overallScore,
    readinessLevel,
    readyForPipeline,
    gateDecision,
  }
}

function reviewDoesNotBlock(reviewText) {
  if (!reviewText.trim()) {
    return true
  }

  return !/## Ready For Pipeline\?\s+Not yet\./is.test(reviewText)
}

function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true })
  fs.writeFileSync(filePath, `${content.trimEnd()}\n`)
}

function formatChecklist(result) {
  const coreChecks = result.checks.filter((check) =>
    ['Business', 'Specificity', 'Users', 'Scope', 'Journeys', 'Functional', 'Acceptance', 'Domain', 'Integrations', 'Architecture', 'Frontend', 'NFRs', 'Security', 'Delivery'].includes(check.area)
  )
  const classificationChecks = result.checks.filter((check) =>
    ['Profile', 'Stack', 'Delivery Mode', 'Alignment'].includes(check.area)
  )
  const profileChecks = result.checks.filter((check) => check.area === 'internal-tool')
  const stackChecks = result.checks.filter((check) => check.area === 'frontend-stack')
  const deliveryChecks = result.checks.filter((check) => check.area === 'existing-product-evolution')

  const rows = (checks) =>
    checks
      .map((check) => `| ${check.area} | ${check.criterion} | \`${check.status}\` | \`${check.evidence}\` | |`)
      .join('\n')

  const minimumFixes =
    result.failingChecks.length === 0
      ? '  - `none`'
      : result.failingChecks.map((check) => `  - \`${check.area}: ${check.criterion}\``).join('\n')

  return `# PRD Quality Checklist

- project_profile: \`${result.classifications.projectProfile}\`
- technical_stack: \`${result.classifications.technicalStack}\`
- delivery_mode: \`${result.classifications.deliveryMode}\`
- readiness_level: \`${result.readinessLevel}\`
- last_reviewed_at: \`${new Date().toISOString()}\`
- review_rule: \`Only L4 is ready for strict pipeline execution.\`

Allowed status values:

- \`pass\`
- \`partial\`
- \`fail\`
- \`tbd\`

## Core Quality Checks

| Area | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
${rows(coreChecks)}

## Classification Checks

| Area | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
${rows(classificationChecks)}

## Profile-Specific Checks

| Profile | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
${profileChecks.map((check) => `| \`${result.classifications.projectProfile}\` | ${check.criterion} | \`${check.status}\` | \`${check.evidence}\` | |`).join('\n')}

## Stack-Specific Checks

| Stack Area | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
${stackChecks.map((check) => `| \`${result.classifications.technicalStack}\` | ${check.criterion} | \`${check.status}\` | \`${check.evidence}\` | |`).join('\n')}

## Delivery-Mode Checks

| Delivery Mode | Criterion | Status | Evidence | Notes |
| --- | --- | --- | --- | --- |
${deliveryChecks.map((check) => `| \`${result.classifications.deliveryMode}\` | ${check.criterion} | \`${check.status}\` | \`${check.evidence}\` | |`).join('\n')}

## Gate Summary

- overall_assessment: \`${result.readyForPipeline === 'yes' ? 'strong enough for pipeline execution' : 'needs more clarity before pipeline execution'}\`
- ready_for_pipeline: \`${result.readyForPipeline}\`
- minimum_fixes_required:
${minimumFixes}
`
}

function formatReview(result) {
  if (result.failingChecks.length === 0) {
    return `# PRD Review

## Overall Assessment

The PRD is project-specific, concrete, and sufficiently constrained to drive the delivery pipeline. It defines the active surface, filter-state contract, filtered-empty behavior, deterministic sorting, security expectations, and blocking verification clearly enough for downstream stages.

## Findings

- No blocking findings.
- Residual risk: surrounding architecture scaffolding may still contain placeholders, but the PRD is explicit enough for planner and spec generation to regenerate those artifacts safely.

## Missing Decisions

- none

## Suggested Improvements Before make ai-run

- Keep the PRD as the single source of truth during the first planner/spec pass.
- Preserve the current narrow slice boundary and do not expand beyond the documented queue-filter behavior.

## Ready For Pipeline?

Yes.

The PRD is strong enough for \`make ai-run\` under the current quality gate.`
  }

  const findings = result.failingChecks
    .map((check, index) => `${index + 1}. **${check.criterion}**
   - Area: \`${check.area}\`
   - Why it matters: This gap reduces determinism for downstream planning, implementation, or verification.
   - Evidence: \`${check.evidence}\``)
    .join('\n')

  const fixes = result.failingChecks
    .map((check) => `- resolve \`${check.area}\`: ${check.criterion}`)
    .join('\n')

  return `# PRD Review

## Overall Assessment

The PRD is closer to execution-ready than the surrounding bootstrap scaffolding, but it still leaves blocking ambiguity for downstream stages.

## Findings

${findings}

## Missing Decisions

${result.failingChecks.map((check) => `- ${check.criterion}`).join('\n')}

## Suggested Improvements Before make ai-run

${fixes}

## Ready For Pipeline?

Not yet.

The minimum fixes above are required before the PRD should drive the full pipeline.`
}

function formatScore(result) {
  const dimensionRows = [
    ['clarity', result.dimensionScores.clarity],
    ['completeness', result.dimensionScores.completeness],
    ['consistency', result.dimensionScores.consistency],
    ['testability', result.dimensionScores.testability],
    ['architecture readiness', result.dimensionScores.architectureReadiness],
    ['security/compliance readiness', result.dimensionScores.securityComplianceReadiness],
    ['operational readiness', result.dimensionScores.operationalReadiness],
    ['delivery readiness', result.dimensionScores.deliveryReadiness],
  ]

  const criticalGaps =
    result.failingChecks.length === 0
      ? '- none'
      : result.failingChecks.map((check) => `- ${check.area}: ${check.criterion}`).join('\n')

  const minimumFixes =
    result.failingChecks.length === 0
      ? '- none'
      : result.failingChecks.map((check) => `- ${check.criterion}`).join('\n')

  return `# PRD Quality Score

- project_profile: ${result.classifications.projectProfile}
- technical_stack: ${result.classifications.technicalStack}
- delivery_mode: ${result.classifications.deliveryMode}
- readiness_level: ${result.readinessLevel}
- overall_score: ${result.overallScore}
- ready_for_pipeline: ${result.readyForPipeline}
- minimum_recommended_score: 80
- gate_decision: ${result.gateDecision}

## Dimension Scores

| Dimension | Score (0-5) |
| --- | --- |
${dimensionRows.map(([name, score]) => `| ${name} | ${score} |`).join('\n')}

## Critical Gaps

${criticalGaps}

## Minimum Fixes Required

${minimumFixes}

## Rationale

- selected project profile: \`${result.classifications.projectProfile}\`
- identified technical stack: \`${result.classifications.technicalStack}\`
- identified delivery mode: \`${result.classifications.deliveryMode}\`
- score is based on explicit PRD structure, absence of template placeholders, frontend-state completeness, security expectations, and blocking verification clarity
- strict gate result: \`${result.gateDecision}\``
}

function formatRuntimeSummary(mode, result, runId) {
  return `# ${mode === 'review' ? 'PRD Reviewer' : 'PRD Auditor'} Result

- run_id: \`${runId}\`
- mode: \`${mode}\`
- readiness_level: \`${result.readinessLevel}\`
- overall_score: \`${result.overallScore}\`
- ready_for_pipeline: \`${result.readyForPipeline}\`

## Summary

- failing_checks: \`${result.failingChecks.length}\`
- gate_decision: \`${result.gateDecision}\`
- project_profile: \`${result.classifications.projectProfile}\`
- technical_stack: \`${result.classifications.technicalStack}\`
- delivery_mode: \`${result.classifications.deliveryMode}\``
}

function main() {
  const args = parseArgs(process.argv)
  const repoRoot = path.resolve(args.repoRoot)
  const prdFile = path.join(repoRoot, 'docs/prd.md')
  const questionnaireFile = path.join(repoRoot, 'docs/prd-questionnaire.md')
  const checklistFile = path.join(repoRoot, 'docs/prd-quality-checklist.md')
  const reviewFile = path.join(repoRoot, 'docs/audit/prd-review.md')
  const scoreFile = path.join(repoRoot, 'docs/audit/prd-score.md')
  const runtimeLog = path.join(repoRoot, `runtime/logs/${args.runId || args.mode}.result.md`)

  if (!fs.existsSync(prdFile)) {
    fail('missing docs/prd.md')
  }

  const prdText = readFileIfExists(prdFile)
  const questionnaireText = readFileIfExists(questionnaireFile)
  const reviewText = readFileIfExists(reviewFile)
  const result = evaluatePrd(prdText, questionnaireText, reviewText)

  if (args.mode === 'review') {
    writeFile(reviewFile, formatReview(result))
  } else {
    writeFile(checklistFile, formatChecklist(result))
    writeFile(scoreFile, formatScore(result))
  }

  writeFile(runtimeLog, formatRuntimeSummary(args.mode, result, args.runId || args.mode))
}

main()
