#!/usr/bin/env node

import fs from 'node:fs'
import path from 'node:path'

function fail(message) {
  process.stderr.write(`ai-inspect-existing-project: ${message}\n`)
  process.exit(1)
}

function parseArgs(argv) {
  const args = {
    repoRoot: '',
    output: '',
  }

  for (let index = 2; index < argv.length; index += 1) {
    const value = argv[index]
    if (value === '--repo-root') {
      args.repoRoot = argv[index + 1] || ''
      index += 1
    } else if (value === '--output') {
      args.output = argv[index + 1] || ''
      index += 1
    } else {
      fail(`unsupported argument: ${value}`)
    }
  }

  if (!args.repoRoot) {
    fail('missing --repo-root')
  }

  return args
}

function safeReadFile(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8')
  } catch {
    return ''
  }
}

function safeReadJson(filePath) {
  try {
    return JSON.parse(fs.readFileSync(filePath, 'utf8'))
  } catch {
    return null
  }
}

function fileExists(filePath) {
  try {
    return fs.statSync(filePath).isFile()
  } catch {
    return false
  }
}

function dirExists(filePath) {
  try {
    return fs.statSync(filePath).isDirectory()
  } catch {
    return false
  }
}

function walkFiles(rootDir) {
  const skipDirs = new Set([
    '.git',
    '.next',
    '.turbo',
    '.vercel',
    '.vite',
    '.vite-temp',
    'build',
    'coverage',
    'dist',
    'node_modules',
    'playwright-report',
    'reports',
    'runtime',
    'test-results',
    'target',
  ])

  const files = []

  function visit(currentDir) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true })
    for (const entry of entries) {
      const absolutePath = path.join(currentDir, entry.name)
      const relativePath = path.relative(rootDir, absolutePath).replace(/\\/g, '/')
      if (entry.isDirectory()) {
        if (skipDirs.has(entry.name)) {
          continue
        }
        visit(absolutePath)
        continue
      }
      files.push(relativePath)
    }
  }

  visit(rootDir)
  return files.sort((left, right) => left.localeCompare(right))
}

function unique(values) {
  return [...new Set(values.filter(Boolean))]
}

function hasDependency(deps, name) {
  return deps.has(name)
}

function detectPackageManager(repoRoot, packageDir, packageJson) {
  const packageManagerField = String(packageJson.packageManager || '')
  if (packageManagerField.startsWith('pnpm')) return 'pnpm'
  if (packageManagerField.startsWith('yarn')) return 'yarn'
  if (packageManagerField.startsWith('bun')) return 'bun'
  if (packageManagerField.startsWith('npm')) return 'npm'

  const candidates = [
    ['pnpm-lock.yaml', 'pnpm'],
    ['yarn.lock', 'yarn'],
    ['bun.lockb', 'bun'],
    ['package-lock.json', 'npm'],
  ]

  for (const [fileName, manager] of candidates) {
    if (fileExists(path.join(packageDir, fileName))) {
      return manager
    }
  }

  for (const [fileName, manager] of candidates) {
    if (fileExists(path.join(repoRoot, fileName))) {
      return manager
    }
  }

  return 'npm'
}

function scriptCommand(packageManager, scriptName) {
  if (!scriptName) {
    return ''
  }

  switch (packageManager) {
    case 'pnpm':
      return `pnpm ${scriptName}`
    case 'yarn':
      return `yarn ${scriptName}`
    case 'bun':
      return `bun run ${scriptName}`
    case 'npm':
    default:
      return `npm run ${scriptName}`
  }
}

function pickScript(scripts, candidates) {
  for (const candidate of candidates) {
    if (typeof scripts[candidate] === 'string' && scripts[candidate].trim()) {
      return candidate
    }
  }
  return ''
}

function detectFrameworks(deps) {
  const frameworks = []

  if (hasDependency(deps, 'next')) frameworks.push('Next.js')
  if (hasDependency(deps, 'react')) frameworks.push('React')
  if (hasDependency(deps, 'vue')) frameworks.push('Vue')
  if (hasDependency(deps, 'nuxt')) frameworks.push('Nuxt')
  if (hasDependency(deps, 'svelte') || hasDependency(deps, '@sveltejs/kit')) frameworks.push('Svelte')
  if (hasDependency(deps, 'vite')) frameworks.push('Vite')
  if (hasDependency(deps, '@angular/core')) frameworks.push('Angular')

  return unique(frameworks)
}

function detectStyling(deps, repoRoot, allFiles) {
  const styling = []

  if (hasDependency(deps, 'tailwindcss')) styling.push('Tailwind CSS')
  if (hasDependency(deps, 'styled-components')) styling.push('styled-components')
  if (hasDependency(deps, '@emotion/react')) styling.push('Emotion')
  if (hasDependency(deps, 'sass')) styling.push('Sass')
  if (allFiles.some((file) => file.endsWith('.module.css'))) styling.push('CSS Modules')

  if (styling.length === 0) {
    const cssFiles = allFiles.filter((file) => /\.(css|scss|sass|less)$/.test(file))
    if (cssFiles.length > 0) {
      styling.push('CSS stylesheets')
    }
  }

  return unique(styling)
}

function detectComponentLibraries(deps, allFiles) {
  const libraries = []

  if (hasDependency(deps, '@radix-ui/react-slot') || hasDependency(deps, 'class-variance-authority')) {
    libraries.push('shadcn/ui-compatible primitives')
  }
  if (hasDependency(deps, '@mui/material')) libraries.push('MUI')
  if (hasDependency(deps, 'antd')) libraries.push('Ant Design')
  if (hasDependency(deps, '@chakra-ui/react')) libraries.push('Chakra UI')
  if (hasDependency(deps, '@headlessui/react')) libraries.push('Headless UI')
  if (allFiles.some((file) => /^src\/components\/ui\//.test(file) || /^components\/ui\//.test(file))) {
    libraries.push('shared ui primitives')
  }

  return unique(libraries)
}

function findFrontendRoots(repoRoot, packageDir, allFiles) {
  const knownDirs = [
    'src',
    'app',
    'pages',
    'components',
    'frontend',
    'client',
    'web',
    'apps/web',
    'apps/frontend',
  ]

  const packageRelative = path.relative(repoRoot, packageDir).replace(/\\/g, '/')
  const rootedDirs = []

  for (const knownDir of knownDirs) {
    const candidate = packageRelative && packageRelative !== '.'
      ? `${packageRelative}/${knownDir}`.replace(/^\.\/+/, '')
      : knownDir

    if (dirExists(path.join(repoRoot, candidate))) {
      rootedDirs.push(candidate)
    }
  }

  if (rootedDirs.length > 0) {
    return unique(rootedDirs)
  }

  return unique(
    allFiles
      .filter((file) => /\.(tsx|jsx|vue|svelte)$/.test(file))
      .slice(0, 30)
      .map((file) => file.split('/').slice(0, 2).join('/'))
  )
}

function findRouteHints(allFiles) {
  const routePatterns = [
    /(^|\/)app\/.+\/page\.(tsx|jsx|ts|js|vue|svelte)$/,
    /(^|\/)pages\/.+\.(tsx|jsx|ts|js|vue|svelte)$/,
    /(^|\/)routes\/.+\.(tsx|jsx|ts|js|vue|svelte)$/,
    /(^|\/)router\.(tsx|jsx|ts|js)$/,
    /(^|\/)app\.tsx$/,
  ]

  return allFiles.filter((file) => routePatterns.some((pattern) => pattern.test(file))).slice(0, 20)
}

function countPatternInFiles(repoRoot, files, pattern) {
  let count = 0
  for (const relativePath of files) {
    const text = safeReadFile(path.join(repoRoot, relativePath))
    if (!text) continue
    const matches = text.match(pattern)
    if (matches) {
      count += matches.length
    }
  }
  return count
}

function findTokenFiles(repoRoot, files) {
  return files.filter((relativePath) => /--[a-z0-9-]+\s*:/.test(safeReadFile(path.join(repoRoot, relativePath)))).slice(0, 20)
}

function detectBackendHints(repoRoot, allFiles, packageDeps) {
  const hints = []

  if (fileExists(path.join(repoRoot, 'pyproject.toml')) || allFiles.some((file) => /^requirements.*\.txt$/.test(path.basename(file)))) {
    hints.push('Python')
  }
  if (fileExists(path.join(repoRoot, 'go.mod'))) {
    hints.push('Go')
  }
  if (fileExists(path.join(repoRoot, 'Cargo.toml'))) {
    hints.push('Rust')
  }
  if (fileExists(path.join(repoRoot, 'pom.xml')) || fileExists(path.join(repoRoot, 'build.gradle')) || fileExists(path.join(repoRoot, 'build.gradle.kts'))) {
    hints.push('Java/Kotlin')
  }
  if (
    hasDependency(packageDeps, 'express') ||
    hasDependency(packageDeps, 'fastify') ||
    hasDependency(packageDeps, '@nestjs/core') ||
    hasDependency(packageDeps, 'koa') ||
    hasDependency(packageDeps, 'hono')
  ) {
    hints.push('Node.js backend')
  }

  return unique(hints)
}

function summarizeStack(frontendFrameworks, styling, componentLibraries, backendHints) {
  const frontendParts = unique([...frontendFrameworks, ...styling, ...componentLibraries])
  return {
    frontendStack: frontendParts.length > 0 ? frontendParts.join(', ') : 'not clearly detected',
    backendStack: backendHints.length > 0 ? backendHints.join(', ') : 'not clearly detected',
  }
}

function findPreserveCandidates(allFiles, routeHints) {
  const candidates = []
  const preservePatterns = [
    /^package(-lock)?\.json$/,
    /^pnpm-lock\.yaml$/,
    /^yarn\.lock$/,
    /^tsconfig.*\.json$/,
    /^vite\.config\./,
    /^next\.config\./,
    /^tailwind\.config\./,
    /openapi/i,
    /swagger/i,
    /routes?\//i,
    /router/i,
    /api\/.*\.(yaml|yml|json|ts|js)$/i,
  ]

  for (const file of allFiles) {
    if (preservePatterns.some((pattern) => pattern.test(file))) {
      candidates.push(file)
    }
  }

  for (const routeHint of routeHints) {
    candidates.push(routeHint)
  }

  return unique(candidates).slice(0, 20)
}

function loadQualityConfig(repoRoot) {
  const configPath = fileExists(path.join(repoRoot, 'quality/pipeline.config.json'))
    ? path.join(repoRoot, 'quality/pipeline.config.json')
    : fileExists(path.join(repoRoot, 'quality/pipeline.config.template.json'))
      ? path.join(repoRoot, 'quality/pipeline.config.template.json')
      : ''

  if (!configPath) {
    return { path: '', config: null }
  }

  return {
    path: path.relative(repoRoot, configPath).replace(/\\/g, '/'),
    config: safeReadJson(configPath),
  }
}

function configuredCommand(config, gateName) {
  const command = config?.commands?.[gateName]?.command
  return Boolean(command && command !== 'replace-me')
}

function selectPrimaryPackage(repoRoot, packages) {
  if (packages.length === 0) {
    return null
  }

  const rootPackage = packages.find((entry) => entry.relativeDir === '.')
  if (rootPackage) {
    return rootPackage
  }

  const frontendPackage = packages.find((entry) => entry.frontendDetected)
  if (frontendPackage) {
    return frontendPackage
  }

  return packages[0]
}

function buildExistingSystemContext(repoName, primaryPackage, frontendRoots, stack) {
  const parts = [`Existing repository \`${repoName}\``]

  if (primaryPackage) {
    parts.push(`primary package at \`${primaryPackage.relativeDir}\``)
  }
  if (stack.frontendStack !== 'not clearly detected') {
    parts.push(`frontend stack: ${stack.frontendStack}`)
  }
  if (stack.backendStack !== 'not clearly detected') {
    parts.push(`backend stack: ${stack.backendStack}`)
  }
  if (frontendRoots.length > 0) {
    parts.push(`frontend roots: ${frontendRoots.join(', ')}`)
  }

  return parts.join('; ')
}

function buildToolingConstraints(packageManager, primaryPackage, qualityConfig, commandHints) {
  const parts = []
  parts.push(`package manager: ${packageManager}`)
  if (primaryPackage && primaryPackage.relativeDir !== '.') {
    parts.push(`primary app directory: ${primaryPackage.relativeDir}`)
  }
  if (qualityConfig.path) {
    parts.push(`quality config path: ${qualityConfig.path}`)
  }
  const configuredCommands = Object.entries(commandHints)
    .filter(([, value]) => value.command)
    .map(([name, value]) => `${name} via "${value.command}"`)
  if (configuredCommands.length > 0) {
    parts.push(`detected scripts: ${configuredCommands.join(', ')}`)
  }
  return parts.join('; ')
}

function inspect(repoRoot) {
  const allFiles = walkFiles(repoRoot)
  const packageJsonFiles = allFiles.filter((file) => path.basename(file) === 'package.json')
  const packages = packageJsonFiles.map((relativePath) => {
    const absolutePath = path.join(repoRoot, relativePath)
    const packageJson = safeReadJson(absolutePath) || {}
    const packageDir = path.dirname(absolutePath)
    const relativeDir = path.relative(repoRoot, packageDir).replace(/\\/g, '/') || '.'
    const dependencies = new Set([
      ...Object.keys(packageJson.dependencies || {}),
      ...Object.keys(packageJson.devDependencies || {}),
    ])
    const scripts = packageJson.scripts || {}
    const frameworks = detectFrameworks(dependencies)
    const frontendDetected = frameworks.length > 0 || allFiles.some((file) => /\.(tsx|jsx|vue|svelte)$/.test(file))

    return {
      relativePath,
      relativeDir,
      name: String(packageJson.name || ''),
      packageManager: detectPackageManager(repoRoot, packageDir, packageJson),
      dependencies,
      scripts,
      frameworks,
      frontendDetected,
    }
  })

  const primaryPackage = selectPrimaryPackage(repoRoot, packages)
  const packageManager = primaryPackage ? primaryPackage.packageManager : 'npm'
  const frontendFrameworks = primaryPackage ? primaryPackage.frameworks : []
  const styling = detectStyling(primaryPackage?.dependencies || new Set(), repoRoot, allFiles)
  const componentLibraries = detectComponentLibraries(primaryPackage?.dependencies || new Set(), allFiles)
  const frontendRoots = findFrontendRoots(repoRoot, primaryPackage ? path.join(repoRoot, primaryPackage.relativeDir) : repoRoot, allFiles)
  const routeHints = findRouteHints(allFiles)
  const codeFiles = allFiles.filter((file) => /\.(tsx|jsx|ts|js|vue|svelte)$/.test(file))
  const cssFiles = allFiles.filter((file) => /\.(css|scss|sass|less)$/.test(file))
  const tokenFileHints = findTokenFiles(repoRoot, cssFiles)
  const inlineStyleCount = countPatternInFiles(repoRoot, codeFiles, /style\s*=\s*\{\{/g)
  const rawHexColorCount = countPatternInFiles(repoRoot, [...codeFiles, ...cssFiles], /#[0-9a-fA-F]{3,8}\b/g)
  const backendHints = detectBackendHints(repoRoot, allFiles, primaryPackage?.dependencies || new Set())
  const stack = summarizeStack(frontendFrameworks, styling, componentLibraries, backendHints)
  const qualityConfig = loadQualityConfig(repoRoot)

  const commandHints = {
    lint: {
      script: primaryPackage ? pickScript(primaryPackage.scripts, ['lint', 'lint:ci']) : '',
      cwd: primaryPackage?.relativeDir || '.',
    },
    typecheck: {
      script: primaryPackage ? pickScript(primaryPackage.scripts, ['typecheck', 'type-check', 'check-types']) : '',
      cwd: primaryPackage?.relativeDir || '.',
    },
    unit: {
      script: primaryPackage ? pickScript(primaryPackage.scripts, ['test:unit', 'unit', 'test']) : '',
      cwd: primaryPackage?.relativeDir || '.',
    },
    e2e: {
      script: primaryPackage ? pickScript(primaryPackage.scripts, ['test:e2e', 'e2e']) : '',
      cwd: primaryPackage?.relativeDir || '.',
    },
    coverage: {
      script: primaryPackage ? pickScript(primaryPackage.scripts, ['test:coverage', 'coverage']) : '',
      cwd: primaryPackage?.relativeDir || '.',
    },
    dependencyScan: {
      script: primaryPackage ? pickScript(primaryPackage.scripts, ['audit:deps', 'deps:audit', 'security:audit']) : '',
      cwd: primaryPackage?.relativeDir || '.',
    },
    start: {
      script: primaryPackage ? pickScript(primaryPackage.scripts, ['preview', 'start', 'dev']) : '',
      cwd: primaryPackage?.relativeDir || '.',
    },
  }

  for (const value of Object.values(commandHints)) {
    value.command = value.script ? scriptCommand(packageManager, value.script) : ''
  }

  const frontendDetected = frontendFrameworks.length > 0 || codeFiles.some((file) => /\.(tsx|jsx|vue|svelte)$/.test(file))
  const frontendDocs = {
    architecture: fileExists(path.join(repoRoot, 'docs/architecture/frontend-architecture.md')),
    designSystem: fileExists(path.join(repoRoot, 'docs/specs/design-system.md')),
    qualityGates: fileExists(path.join(repoRoot, 'docs/specs/frontend-quality-gates.md')),
    uxJourneys: fileExists(path.join(repoRoot, 'docs/specs/ux-research-and-journeys.md')),
  }
  const frontendEvidenceEnabled = Boolean(qualityConfig.config?.frontendEvidence?.enabled)
  const routeConfigReady = Array.isArray(qualityConfig.config?.frontendEvidence?.routes)
    && qualityConfig.config.frontendEvidence.routes.length > 0
    && qualityConfig.config.frontendEvidence.routes.every((route) => route.id && route.id !== 'replace-me')

  const repoName = primaryPackage?.name || path.basename(repoRoot)
  const preserveCandidates = findPreserveCandidates(allFiles, routeHints)

  const concerns = []
  if (frontendDetected && !styling.includes('Tailwind CSS')) {
    concerns.push('frontend styling is not yet aligned to the Tailwind-first baseline')
  }
  if (frontendDetected && tokenFileHints.length === 0) {
    concerns.push('design tokens or CSS custom property files were not detected')
  }
  if (frontendDetected && !frontendDocs.architecture) {
    concerns.push('frontend architecture doc is missing')
  }
  if (frontendDetected && !frontendEvidenceEnabled) {
    concerns.push('frontend evidence is not enabled in the quality config')
  }
  if (frontendDetected && inlineStyleCount > 0) {
    concerns.push(`inline style patterns detected (${inlineStyleCount})`)
  }
  if (frontendDetected && rawHexColorCount > 10) {
    concerns.push(`raw color literals detected (${rawHexColorCount})`)
  }
  if (!configuredCommand(qualityConfig.config, 'lint') && !commandHints.lint.command) {
    concerns.push('lint command is not configured')
  }
  if (!configuredCommand(qualityConfig.config, 'e2e') && !commandHints.e2e.command) {
    concerns.push('e2e command is not configured')
  }

  const recommendedSlices = []
  if (frontendDetected && (!frontendDocs.architecture || !frontendDocs.designSystem || !frontendDocs.qualityGates || !frontendDocs.uxJourneys)) {
    recommendedSlices.push('document frontend governance before large UI refactors')
  }
  if (frontendDetected && !frontendEvidenceEnabled) {
    recommendedSlices.push('configure frontend evidence routes, viewports, and startup command')
  }
  if (frontendDetected && !styling.includes('Tailwind CSS')) {
    recommendedSlices.push('introduce a tokenized Tailwind-based styling layer or document an explicit equivalent')
  }
  if (frontendDetected && (inlineStyleCount > 0 || rawHexColorCount > 10)) {
    recommendedSlices.push('extract inline styles and raw color literals into shared tokens and primitives')
  }
  if (!configuredCommand(qualityConfig.config, 'lint') || !configuredCommand(qualityConfig.config, 'typecheck') || !configuredCommand(qualityConfig.config, 'unit')) {
    recommendedSlices.push('wire baseline quality commands into quality/pipeline.config.json')
  }
  if (frontendDetected && (!configuredCommand(qualityConfig.config, 'e2e') || !configuredCommand(qualityConfig.config, 'coverage'))) {
    recommendedSlices.push('add frontend proving commands for e2e and coverage')
  }

  return {
    inspectedAt: new Date().toISOString(),
    repoName,
    deliveryModeSuggestion: 'existing-product-evolution',
    packageManager,
    primaryPackage: primaryPackage ? {
      path: primaryPackage.relativePath,
      relativeDir: primaryPackage.relativeDir,
      name: primaryPackage.name,
      frameworks: primaryPackage.frameworks,
    } : null,
    commandHints,
    qualityConfig: {
      path: qualityConfig.path,
      exists: Boolean(qualityConfig.path),
      frontendEvidenceEnabled,
      routeConfigReady,
      commands: qualityConfig.config ? {
        lint: configuredCommand(qualityConfig.config, 'lint'),
        typecheck: configuredCommand(qualityConfig.config, 'typecheck'),
        unit: configuredCommand(qualityConfig.config, 'unit'),
        e2e: configuredCommand(qualityConfig.config, 'e2e'),
        coverage: configuredCommand(qualityConfig.config, 'coverage'),
      } : null,
    },
    frontend: {
      detected: frontendDetected,
      frameworks: frontendFrameworks,
      styling,
      componentLibraries,
      roots: frontendRoots,
      routeHints,
      tokenFileHints,
      codeFileCount: codeFiles.length,
      cssFileCount: cssFiles.length,
      inlineStyleCount,
      rawHexColorCount,
      docs: frontendDocs,
      concerns,
      recommendedSlices: unique(recommendedSlices),
    },
    backend: {
      stackHints: backendHints,
    },
    preserveCandidates,
    questionnairePrefill: {
      projectName: repoName,
      deliveryMode: 'existing-product-evolution',
      frontendStack: stack.frontendStack,
      backendStack: stack.backendStack,
      existingCodebaseContext: buildExistingSystemContext(repoName, primaryPackage, frontendRoots, stack),
      mustPreserveSystemsOrContracts: preserveCandidates.length > 0
        ? preserveCandidates.join(', ')
        : 'existing routes, authentication flow, public APIs, and production deployment contracts',
      toolingConstraints: buildToolingConstraints(packageManager, primaryPackage, qualityConfig, commandHints),
    },
  }
}

function main() {
  const args = parseArgs(process.argv)
  const repoRoot = path.resolve(args.repoRoot)
  const inspection = inspect(repoRoot)
  const json = `${JSON.stringify(inspection, null, 2)}\n`

  if (args.output) {
    fs.writeFileSync(path.resolve(args.output), json)
    return
  }

  process.stdout.write(json)
}

main()
