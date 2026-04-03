#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'
import { execFileSync } from 'node:child_process'

function fail(message) {
  process.stderr.write(`ai-evaluate-template: ${message}\n`)
  process.exit(1)
}

function parseArgs(argv) {
  const args = {
    mode: '',
    repoRoot: '',
    runId: '',
    output: '',
    minScore: 90,
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
    } else if (value === '--output') {
      args.output = argv[index + 1] || ''
      index += 1
    } else if (value === '--min-score') {
      args.minScore = Number.parseInt(argv[index + 1] || '', 10)
      index += 1
    } else {
      fail(`unsupported argument: ${value}`)
    }
  }

  if (!args.mode || !['validate', 'score'].includes(args.mode)) {
    fail('missing or invalid --mode (expected validate or score)')
  }
  if (!args.repoRoot) {
    fail('missing --repo-root')
  }
  if (!Number.isInteger(args.minScore) || args.minScore < 0 || args.minScore > 100) {
    fail('invalid --min-score (expected integer between 0 and 100)')
  }

  return args
}

function repoPath(repoRoot, relativePath) {
  return path.join(repoRoot, relativePath)
}

function exists(repoRoot, relativePath) {
  return fs.existsSync(repoPath(repoRoot, relativePath))
}

function readText(repoRoot, relativePath) {
  return fs.readFileSync(repoPath(repoRoot, relativePath), 'utf8')
}

function fileExists(repoRoot, relativePath) {
  try {
    return fs.statSync(repoPath(repoRoot, relativePath)).isFile()
  } catch {
    return false
  }
}

function dirExists(repoRoot, relativePath) {
  try {
    return fs.statSync(repoPath(repoRoot, relativePath)).isDirectory()
  } catch {
    return false
  }
}

function listFilesRecursive(basePath, rootPath = basePath) {
  if (!fs.existsSync(basePath)) {
    return []
  }

  const entries = fs.readdirSync(basePath, { withFileTypes: true })
  const files = []

  for (const entry of entries) {
    const absolutePath = path.join(basePath, entry.name)
    if (entry.isDirectory()) {
      files.push(...listFilesRecursive(absolutePath, rootPath))
      continue
    }

    files.push(path.relative(rootPath, absolutePath).replace(/\\/g, '/'))
  }

  return files
}

function gitTrackedFiles(repoRoot) {
  try {
    const output = execFileSync('git', ['-C', repoRoot, 'ls-files'], { encoding: 'utf8' })
    return output
      .split('\n')
      .map((value) => value.trim())
      .filter(Boolean)
  } catch {
    return listFilesRecursive(repoRoot).filter((relativePath) => !relativePath.startsWith('.git/'))
  }
}

function isBinaryBuffer(buffer) {
  const sampleSize = Math.min(buffer.length, 4096)
  for (let index = 0; index < sampleSize; index += 1) {
    if (buffer[index] === 0) {
      return true
    }
  }
  return false
}

function findAbsolutePathReferences(repoRoot, trackedFiles) {
  const matches = []
  const patterns = [
    /\/root\/desenvolvimento-vscode\/dev_ia_codex_template/g,
    /\/home\/caio\/projetos\/dev_ia_codex_template/g,
  ]

  for (const relativePath of trackedFiles) {
    const absolutePath = repoPath(repoRoot, relativePath)
    const buffer = fs.readFileSync(absolutePath)

    if (isBinaryBuffer(buffer)) {
      continue
    }

    const text = buffer.toString('utf8')
    for (const pattern of patterns) {
      if (pattern.test(text)) {
        matches.push(relativePath)
        break
      }
    }
  }

  return matches
}

function parseGraph(repoRoot) {
  const graph = JSON.parse(readText(repoRoot, 'tasks/task-graph.json'))
  const nodes = Array.isArray(graph.nodes) ? graph.nodes : []
  const edges = Array.isArray(graph.edges) ? graph.edges : []
  const nodeIds = new Set()
  const issues = []

  for (const node of nodes) {
    if (!node || !node.id || !node.agent || !node.prompt) {
      issues.push(`invalid node entry: ${JSON.stringify(node)}`)
      continue
    }

    if (nodeIds.has(node.id)) {
      issues.push(`duplicate node id: ${node.id}`)
      continue
    }

    nodeIds.add(node.id)

    const agentPath = `ai/agents/${node.agent}.md`
    if (!fileExists(repoRoot, agentPath)) {
      issues.push(`missing agent file for node ${node.id}: ${agentPath}`)
    }

    if (!fileExists(repoRoot, node.prompt)) {
      issues.push(`missing prompt file for node ${node.id}: ${node.prompt}`)
    }
  }

  for (const edge of edges) {
    if (!edge || !edge.from || !edge.to) {
      issues.push(`invalid edge entry: ${JSON.stringify(edge)}`)
      continue
    }
    if (!nodeIds.has(edge.from)) {
      issues.push(`edge references missing source node: ${edge.from}`)
    }
    if (!nodeIds.has(edge.to)) {
      issues.push(`edge references missing target node: ${edge.to}`)
    }
  }

  return {
    nodeCount: nodes.length,
    edgeCount: edges.length,
    issues,
  }
}

function hasMakeTarget(makefileText, target) {
  return new RegExp(`^${target}:`, 'm').test(makefileText)
}

function findUnexpectedFiles(repoRoot, relativeDir, allowedFiles) {
  const rootDir = repoPath(repoRoot, relativeDir)
  if (!dirExists(repoRoot, relativeDir)) {
    return [`missing directory: ${relativeDir}`]
  }

  return listFilesRecursive(rootDir)
    .map((file) => `${relativeDir}/${file}`)
    .filter((file) => !allowedFiles.has(file))
}

function scoreFromChecks(checks, ids) {
  const relevantChecks = checks.filter((check) => ids.includes(check.id))
  const passed = relevantChecks.filter((check) => check.status === 'pass').length
  const ratio = relevantChecks.length === 0 ? 0 : passed / relevantChecks.length

  if (ratio === 1) {
    return 5
  }
  if (ratio >= 0.85) {
    return 4
  }
  if (ratio >= 0.7) {
    return 3
  }
  if (ratio >= 0.5) {
    return 2
  }
  if (ratio > 0) {
    return 1
  }
  return 0
}

function evaluateTemplate(repoRoot) {
  const trackedFiles = gitTrackedFiles(repoRoot)
  const makefileText = readText(repoRoot, 'Makefile')
  const readmeText = readText(repoRoot, 'README.md')
  const agentsText = readText(repoRoot, 'AGENTS.md')
  const developerGuideText = readText(repoRoot, 'docs/developer-guide.md')
  const graph = parseGraph(repoRoot)
  const absolutePathRefs = findAbsolutePathReferences(repoRoot, trackedFiles)
  const runtimeUnexpectedFiles = findUnexpectedFiles(repoRoot, 'runtime', new Set([
    'runtime/context-cache/.gitkeep',
    'runtime/graphs/.gitkeep',
    'runtime/logs/.gitkeep',
    'runtime/logs/template-score.md',
    'runtime/logs/template-validation.md',
    'runtime/state/.gitkeep',
  ]))
  const reportsUnexpectedFiles = findUnexpectedFiles(repoRoot, 'reports', new Set([
    'reports/README.md',
    'reports/security/.gitkeep',
    'reports/slices/.gitkeep',
  ]))
  const guardFiles = listFilesRecursive(repoPath(repoRoot, 'security/agent-guards'))
    .filter((relativePath) => relativePath.endsWith('.guard.md'))
  const validatorFiles = listFilesRecursive(repoPath(repoRoot, 'security/validators'))
    .filter((relativePath) => relativePath.endsWith('.sh'))

  const checks = [
    {
      id: 'required-surfaces',
      area: 'Structure',
      criterion: 'Template keeps the canonical top-level surfaces expected by Efizion',
      status: [
        'ai',
        'docs',
        'tasks',
        'runtime',
        'scripts',
        'security',
        'reports',
        'quality',
        'pilot',
        'skills',
        'README.md',
        'AGENTS.md',
        'Makefile',
      ].every((relativePath) => exists(repoRoot, relativePath)) ? 'pass' : 'fail',
      evidence: 'ai/, docs/, tasks/, runtime/, scripts/, security/, reports/, quality/, pilot/, skills/',
    },
    {
      id: 'graph-integrity',
      area: 'Structure',
      criterion: 'The task graph resolves only to existing agents and prompts',
      status: graph.nodeCount > 0 && graph.issues.length === 0 ? 'pass' : 'fail',
      evidence: graph.issues.length === 0
        ? `nodes=${graph.nodeCount}, edges=${graph.edgeCount}`
        : graph.issues.join('; '),
    },
    {
      id: 'execution-scripts',
      area: 'Execution',
      criterion: 'Core execution entrypoints exist for bootstrap, adoption, graph run, step runner, quality, and pilot validation',
      status: [
        'scripts/ai-init-project.sh',
        'scripts/ai-inspect-existing-project.mjs',
        'scripts/ai-adopt-existing.sh',
        'scripts/ai-audit-security.sh',
        'scripts/ai-audit-frontend.sh',
        'scripts/ai-workflow.sh',
        'scripts/ai-run-graph.sh',
        'scripts/ai-step-runner-codex.sh',
        'scripts/ai-run-quality-gates.sh',
        'scripts/ai-run-pilot-validation.sh',
      ].every((relativePath) => fileExists(repoRoot, relativePath)) ? 'pass' : 'fail',
      evidence: 'scripts/ai-init-project.sh, scripts/ai-inspect-existing-project.mjs, scripts/ai-adopt-existing.sh, scripts/ai-audit-security.sh, scripts/ai-audit-frontend.sh, scripts/ai-workflow.sh, scripts/ai-run-graph.sh, scripts/ai-step-runner-codex.sh, scripts/ai-run-quality-gates.sh, scripts/ai-run-pilot-validation.sh',
    },
    {
      id: 'makefile-template-targets',
      area: 'Execution',
      criterion: 'Makefile exposes lightweight template validation and template scoring targets',
      status: hasMakeTarget(makefileText, 'ai-template-validate') && hasMakeTarget(makefileText, 'ai-template-score') ? 'pass' : 'fail',
      evidence: 'Makefile targets ai-template-validate and ai-template-score',
    },
    {
      id: 'makefile-workflow-targets',
      area: 'Execution',
      criterion: 'Makefile exposes a simple define -> build -> prove operator surface plus one-shot flow targets',
      status: (
        hasMakeTarget(makefileText, 'ai-define') &&
        hasMakeTarget(makefileText, 'ai-build') &&
        hasMakeTarget(makefileText, 'ai-prove') &&
        hasMakeTarget(makefileText, 'ai-flow') &&
        hasMakeTarget(makefileText, 'ai-flow-strict')
      ) ? 'pass' : 'fail',
      evidence: 'Makefile targets ai-define, ai-build, ai-prove, ai-flow, and ai-flow-strict',
    },
    {
      id: 'makefile-adoption-targets',
      area: 'Execution',
      criterion: 'Makefile exposes explicit adoption commands for existing active projects',
      status: (
        hasMakeTarget(makefileText, 'ai-adopt-existing') &&
        hasMakeTarget(makefileText, 'ai-audit-security') &&
        hasMakeTarget(makefileText, 'ai-audit-frontend')
      ) ? 'pass' : 'fail',
      evidence: 'Makefile targets ai-adopt-existing, ai-audit-security, and ai-audit-frontend',
    },
    {
      id: 'security-surface',
      area: 'Security',
      criterion: 'Security policy, agent guards, and validator scripts are all present',
      status: fileExists(repoRoot, 'security/security-policy.md') && guardFiles.length >= 8 && validatorFiles.length >= 5 ? 'pass' : 'fail',
      evidence: `policy=${fileExists(repoRoot, 'security/security-policy.md') ? 'present' : 'missing'}, guards=${guardFiles.length}, validators=${validatorFiles.length}`,
    },
    {
      id: 'baseline-cleanliness',
      area: 'Cleanliness',
      criterion: 'No obsolete submodule or duplicated core remains in the baseline',
      status: !exists(repoRoot, '.gitmodules') && !exists(repoRoot, 'ai-core') ? 'pass' : 'fail',
      evidence: '.gitmodules and ai-core must both be absent',
    },
    {
      id: 'runtime-cleanliness',
      area: 'Cleanliness',
      criterion: 'runtime/ stays limited to .gitkeep plus local template audit outputs',
      status: runtimeUnexpectedFiles.length === 0 ? 'pass' : 'fail',
      evidence: runtimeUnexpectedFiles.length === 0 ? 'runtime is clean' : runtimeUnexpectedFiles.join(', '),
    },
    {
      id: 'reports-cleanliness',
      area: 'Cleanliness',
      criterion: 'reports/ baseline keeps only placeholders and README, without stale evidence bundles',
      status: reportsUnexpectedFiles.length === 0 ? 'pass' : 'fail',
      evidence: reportsUnexpectedFiles.length === 0 ? 'reports baseline is clean' : reportsUnexpectedFiles.join(', '),
    },
    {
      id: 'pilot-hygiene',
      area: 'Cleanliness',
      criterion: 'Pilot reference app has no committed local build or dependency directories',
      status: ![
        'pilot/reference-web-app/node_modules',
        'pilot/reference-web-app/dist',
        'pilot/reference-web-app/coverage',
        'pilot/reference-web-app/test-results',
        'pilot/reference-web-app/playwright-report',
      ].some((relativePath) => exists(repoRoot, relativePath)) ? 'pass' : 'fail',
      evidence: 'pilot/reference-web-app node_modules/, dist/, coverage/, test-results/, playwright-report/ must be absent',
    },
    {
      id: 'portability',
      area: 'Portability',
      criterion: 'Tracked files do not depend on machine-specific absolute repository paths',
      status: absolutePathRefs.length === 0 ? 'pass' : 'fail',
      evidence: absolutePathRefs.length === 0 ? 'no absolute local paths found' : absolutePathRefs.join(', '),
    },
    {
      id: 'template-docs',
      area: 'Governance',
      criterion: 'Root docs explain template validation separately from project PRD gating',
      status: (
        readmeText.includes('ai-template-validate') &&
        readmeText.includes('ai-template-score') &&
        developerGuideText.includes('ai-template-validate') &&
        developerGuideText.includes('ai-template-score') &&
        agentsText.includes('ai-template-validate') &&
        agentsText.includes('ai-template-score')
      ) ? 'pass' : 'fail',
      evidence: 'README.md, docs/developer-guide.md, and AGENTS.md mention ai-template-validate and ai-template-score',
    },
    {
      id: 'workflow-docs',
      area: 'Governance',
      criterion: 'Root docs present define -> build -> prove as the primary human operator flow',
      status: (
        readmeText.includes('ai-define') &&
        readmeText.includes('ai-build') &&
        readmeText.includes('ai-prove') &&
        developerGuideText.includes('ai-define') &&
        developerGuideText.includes('ai-build') &&
        developerGuideText.includes('ai-prove') &&
        agentsText.includes('ai-define') &&
        agentsText.includes('ai-build') &&
        agentsText.includes('ai-prove')
      ) ? 'pass' : 'fail',
      evidence: 'README.md, docs/developer-guide.md, and AGENTS.md mention ai-define, ai-build, and ai-prove',
    },
    {
      id: 'adoption-docs',
      area: 'Governance',
      criterion: 'Root docs present an adoption flow for existing active repositories',
      status: (
        readmeText.includes('ai-adopt-existing') &&
        readmeText.includes('ai-audit-security') &&
        readmeText.includes('ai-audit-frontend') &&
        developerGuideText.includes('ai-adopt-existing') &&
        developerGuideText.includes('ai-audit-security') &&
        developerGuideText.includes('ai-audit-frontend') &&
        agentsText.includes('ai-adopt-existing') &&
        agentsText.includes('ai-audit-security') &&
        agentsText.includes('ai-audit-frontend') &&
        fileExists(repoRoot, 'docs/adoption/README.md')
      ) ? 'pass' : 'fail',
      evidence: 'README.md, docs/developer-guide.md, AGENTS.md, and docs/adoption/README.md must describe the existing-project adoption flow',
    },
    {
      id: 'template-vs-prd-separation',
      area: 'Governance',
      criterion: 'Docs make clear that strict PRD scoring is a project gate, not a template baseline gate',
      status: (
        readmeText.includes('project PRD') ||
        developerGuideText.includes('project PRD') ||
        agentsText.includes('project PRD')
      ) ? 'pass' : 'fail',
      evidence: 'project PRD language should appear in root documentation around ai-run-strict',
    },
  ]

  const dimensions = {
    structure: ['required-surfaces', 'graph-integrity'],
    execution: ['execution-scripts', 'makefile-template-targets', 'makefile-workflow-targets', 'makefile-adoption-targets'],
    security: ['security-surface'],
    cleanliness: ['baseline-cleanliness', 'runtime-cleanliness', 'reports-cleanliness', 'pilot-hygiene'],
    portability: ['portability'],
    governance: ['template-docs', 'workflow-docs', 'adoption-docs', 'template-vs-prd-separation'],
  }

  const dimensionScores = Object.fromEntries(
    Object.entries(dimensions).map(([dimension, ids]) => [dimension, scoreFromChecks(checks, ids)])
  )

  const total = Object.values(dimensionScores).reduce((sum, value) => sum + value, 0)
  const overallScore = Math.round((total / (Object.keys(dimensionScores).length * 5)) * 100)
  const failingChecks = checks.filter((check) => check.status === 'fail')
  const gateDecision = failingChecks.length === 0 ? 'approved' : 'blocked'
  const status = failingChecks.length === 0 ? 'pass' : 'fail'

  return {
    checks,
    dimensions,
    dimensionScores,
    overallScore,
    status,
    gateDecision,
  }
}

function writeFile(filePath, content) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true })
  fs.writeFileSync(filePath, content)
}

function formatValidationReport(result, runId) {
  const failingChecks = result.checks.filter((check) => check.status === 'fail')

  return `# Template Validation

- run_id: \`${runId}\`
- status: \`${result.status}\`
- gate_decision: \`${result.gateDecision}\`
- scope: \`baseline-template\`

## Checks

${result.checks.map((check) => `- [${check.status}] ${check.area}: ${check.criterion} (${check.evidence})`).join('\n')}

## Required Fixes

${failingChecks.length === 0 ? '- none' : failingChecks.map((check) => `- ${check.area}: ${check.criterion}`).join('\n')}

## Notes

- This validation measures the reusable template baseline, not the readiness of a project-specific PRD.
- Project PRD enforcement remains a separate gate through \`make ai-prd-score\` and \`make ai-run-strict\`.
`
}

function formatScoreReport(result, runId, minScore) {
  const failingChecks = result.checks.filter((check) => check.status === 'fail')
  const meetsTarget = result.overallScore >= minScore && failingChecks.length === 0

  return `# Template Quality Score

- run_id: \`${runId}\`
- scope: \`baseline-template\`
- overall_score: ${result.overallScore}
- minimum_recommended_score: ${minScore}
- gate_decision: \`${meetsTarget ? 'approved' : 'blocked'}\`

## Dimension Scores

| Dimension | Score (0-5) |
| --- | --- |
${Object.entries(result.dimensionScores).map(([dimension, score]) => `| ${dimension} | ${score} |`).join('\n')}

## Failing Checks

${failingChecks.length === 0 ? '- none' : failingChecks.map((check) => `- ${check.area}: ${check.criterion} (${check.evidence})`).join('\n')}

## Scoring Notes

- This score measures template baseline quality, not project-specific PRD readiness.
- \`make ai-prd-score\` and \`make ai-run-strict\` continue to govern project execution quality after a repository is instantiated from the template.
`
}

function main() {
  const args = parseArgs(process.argv)
  const runId = args.runId || new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z')
  const result = evaluateTemplate(args.repoRoot)
  const outputPath = args.output || repoPath(
    args.repoRoot,
    args.mode === 'validate' ? 'runtime/logs/template-validation.md' : 'runtime/logs/template-score.md'
  )

  const content = args.mode === 'validate'
    ? formatValidationReport(result, runId)
    : formatScoreReport(result, runId, args.minScore)

  writeFile(outputPath, content)

  if (args.mode === 'validate') {
    process.stdout.write(`template validation: ${result.status} (${outputPath})\n`)
    if (result.status !== 'pass') {
      process.exit(1)
    }
    return
  }

  const failingChecks = result.checks.filter((check) => check.status === 'fail')
  const meetsTarget = result.overallScore >= args.minScore && failingChecks.length === 0
  process.stdout.write(`template score: ${result.overallScore} (${meetsTarget ? 'approved' : 'blocked'}) (${outputPath})\n`)

  if (!meetsTarget) {
    process.exit(1)
  }
}

main()
