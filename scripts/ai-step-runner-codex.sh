#!/usr/bin/env bash
set -euo pipefail

STEP=""
AGENT_FILE=""
PROMPT_FILE=""
REPO_ROOT=""
BRIEF_FILE=""
GRAPH_FILE=""
POLICY_FILE=""
CONTEXT_MANIFEST_FILE=""
CONTEXT_MAX_FILES="${AI_CONTEXT_MAX_FILES:-24}"
CONTEXT_MAX_BYTES="${AI_CONTEXT_MAX_BYTES:-120000}"
CONTEXT_MAX_TOKENS="${AI_CONTEXT_MAX_TOKENS:-}"
FRONTEND_SKILL_FILE=""
STEP_TIMEOUT_SECONDS=""

fail() {
  printf 'ai-step-runner-codex: %s\n' "$1" >&2
  exit 1
}

validate_runner_output() {
  if [[ ! -s "$LOG_FILE" ]]; then
    fail "step ${STEP} did not produce a final output message in $(basename "$LOG_FILE")"
  fi

  if rg -qi 'hit your usage limit|purchase more credits|rate limit|authentication|invalid api key|OpenAI API error|^ERROR:' "$LOG_FILE"; then
    fail "step ${STEP} produced an operational Codex error; inspect $(basename "$LOG_FILE")"
  fi
}

timestamp_utc() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

usage() {
  cat <<'EOF'
Usage:
  ai-step-runner-codex.sh \
    --step <step> \
    --agent <agent_file> \
    --prompt <prompt_file> \
    --repo-root <repo_root> \
    --brief <brief_file> \
    --graph <graph_file>

Modes:
  SAFE mode is the default and runs Codex with --full-auto.
  PRIVILEGED mode requires CODEX_PRIVILEGED=true and CODEX_PRIVILEGED_REASON.

Context routing:
  If ai/context-policy.yaml exists, the runner builds a selective context manifest.
  Use AI_DEBUG_CONTEXT=1 to print applied routing rules and selected files.
  Use AI_CONTEXT_MAX_FILES and AI_CONTEXT_MAX_BYTES to tune the context budget.
  AI_CONTEXT_MAX_TOKENS can override the derived token budget directly.
EOF
}

resolve_task_id() {
  local backlog_file="${REPO_ROOT}/tasks/backlog.md"
  local task_id=""

  if [[ -f "$backlog_file" ]]; then
    task_id=$(awk -F'`' '/Active task:/ { print $2; exit }' "$backlog_file")
  fi

  printf '%s\n' "${task_id:-$STEP}"
}

log_privileged_use() {
  local task_id="$1"
  local privileged_log="${REPO_ROOT}/runtime/logs/privileged-runner.log"

  mkdir -p "$(dirname "$privileged_log")"

  if [[ ! -f "$privileged_log" ]]; then
    cat > "$privileged_log" <<'EOF'
# Privileged Runner Audit Log

EOF
  fi

  cat >> "$privileged_log" <<EOF
- timestamp: $(timestamp_utc)
  run_id: ${RUN_ID}
  step: ${STEP}
  task_id: ${task_id}
  reason: ${CODEX_PRIVILEGED_REASON}
EOF
}

resolve_frontend_skill_file() {
  local repo_skill="${REPO_ROOT}/skills/efizion-frontend-excellence/SKILL.md"

  case "$STEP" in
    builder|ux-ui-designer)
      if [[ -f "$repo_skill" ]]; then
        FRONTEND_SKILL_FILE="$repo_skill"
      else
        FRONTEND_SKILL_FILE=""
      fi
      ;;
    *)
      FRONTEND_SKILL_FILE=""
      ;;
  esac
}

resolve_step_timeout_seconds() {
  if [[ -n "${AI_STEP_TIMEOUT_SECONDS:-}" ]]; then
    STEP_TIMEOUT_SECONDS="${AI_STEP_TIMEOUT_SECONDS}"
    return 0
  fi

  case "$STEP" in
    planner)
      STEP_TIMEOUT_SECONDS=180
      ;;
    spec-generator)
      STEP_TIMEOUT_SECONDS=240
      ;;
    ux-ui-designer)
      STEP_TIMEOUT_SECONDS=240
      ;;
    builder)
      STEP_TIMEOUT_SECONDS=600
      ;;
    reviewer)
      STEP_TIMEOUT_SECONDS=300
      ;;
    tester)
      STEP_TIMEOUT_SECONDS=480
      ;;
    frontend-auditor)
      STEP_TIMEOUT_SECONDS=300
      ;;
    security)
      STEP_TIMEOUT_SECONDS=240
      ;;
    prd-writer)
      STEP_TIMEOUT_SECONDS=240
      ;;
    prd-reviewer|prd-auditor)
      STEP_TIMEOUT_SECONDS=120
      ;;
    *)
      STEP_TIMEOUT_SECONDS=300
      ;;
  esac
}

prepare_context_manifest() {
  local debug_flag="${AI_DEBUG_CONTEXT:-0}"

  if [[ ! -f "$POLICY_FILE" ]]; then
    return 1
  fi

  command -v node >/dev/null 2>&1 || fail "node binary not found in PATH"
  mkdir -p "$(dirname "$CONTEXT_MANIFEST_FILE")"

  set +e
  node - \
    "$REPO_ROOT" \
    "$STEP" \
    "$AGENT_FILE" \
    "$PROMPT_FILE" \
    "$BRIEF_FILE" \
    "$GRAPH_FILE" \
    "$POLICY_FILE" \
    "$CONTEXT_MANIFEST_FILE" \
    "$CONTEXT_MAX_FILES" \
    "$CONTEXT_MAX_BYTES" \
    "$CONTEXT_MAX_TOKENS" \
    "$debug_flag" <<'NODE'
const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');

const [
  ,
  ,
  repoRoot,
  step,
  agentFile,
  promptFile,
  briefFile,
  graphFile,
  policyFile,
  manifestFile,
  maxFilesRaw,
  maxBytesRaw,
  maxTokensRaw,
  debugRaw
] = process.argv;

const debug = debugRaw === '1' || debugRaw === 'true';
const maxFiles = Number.parseInt(maxFilesRaw, 10) || 24;
const maxBytes = Number.parseInt(maxBytesRaw, 10) || 120000;
const explicitMaxTokens = Number.parseInt(maxTokensRaw, 10);

const stepToPolicy = {
  planner: 'PLANNER',
  'spec-generator': 'SPEC_GENERATOR',
  'ux-ui-designer': 'UX_UI_DESIGNER',
  builder: 'BUILDER',
  reviewer: 'REVIEWER',
  tester: 'TESTER',
  'frontend-auditor': 'FRONTEND_AUDITOR',
  security: 'SECURITY',
  'prd-writer': 'PRD_WRITER',
  'prd-reviewer': 'PRD_REVIEWER',
  'prd-auditor': 'PRD_AUDITOR'
};

function toRelative(targetPath) {
  if (!targetPath) {
    return '';
  }

  if (path.isAbsolute(targetPath)) {
    return path.relative(repoRoot, targetPath).replace(/\\/g, '/');
  }

  return targetPath.replace(/\\/g, '/').replace(/^\.\//, '');
}

function normalizeRepoPath(targetPath) {
  const relative = toRelative(targetPath);
  if (!relative || relative.startsWith('..')) {
    return null;
  }

  return relative;
}

function absoluteRepoPath(relativePath) {
  return path.join(repoRoot, relativePath);
}

function isTemplatePath(relativePath) {
  return /\.template\.md$/i.test(relativePath);
}

function existsFile(relativePath) {
  try {
    return fs.statSync(absoluteRepoPath(relativePath)).isFile();
  } catch {
    return false;
  }
}

function existsDirectory(relativePath) {
  try {
    return fs.statSync(absoluteRepoPath(relativePath)).isDirectory();
  } catch {
    return false;
  }
}

function isAllowedRelativePath(relativePath) {
  if (!relativePath) {
    return false;
  }

  if (relativePath === 'none' || relativePath === 'null') {
    return false;
  }

  if (relativePath.startsWith('runtime/')) {
    return false;
  }

  if (isTemplatePath(relativePath)) {
    return false;
  }

  return true;
}

function estimateTokensFromBytes(bytes) {
  return Math.max(1, Math.ceil(bytes / 4));
}

const maxTokens = Number.isFinite(explicitMaxTokens) && explicitMaxTokens > 0
  ? explicitMaxTokens
  : estimateTokensFromBytes(maxBytes);

function isCodeFile(relativePath) {
  return /\.(ts|tsx|js|jsx|mjs|cjs|py|rb|go|rs|java|kt|cs|php|swift|scala|sql|sh|bash|zsh|yaml|yml|toml|json|mdx|html|css|scss)$/i.test(relativePath);
}

function isTestFile(relativePath) {
  return /(^|\/)(test|tests|__tests__)\//.test(relativePath)
    || /\.(test|spec)\.[^.]+$/i.test(relativePath);
}

function parseSimpleYamlPolicy(source) {
  const policy = {};
  let currentAgent = null;
  let currentList = null;

  for (const rawLine of source.split('\n')) {
    const line = rawLine.replace(/\r$/, '');
    if (!line.trim() || line.trim().startsWith('#')) {
      continue;
    }

    const agentMatch = line.match(/^([A-Z_]+):\s*$/);
    if (agentMatch) {
      currentAgent = agentMatch[1];
      currentList = null;
      policy[currentAgent] = { include: [], exclude: [] };
      continue;
    }

    const listMatch = line.match(/^\s{2}(include|exclude):\s*$/);
    if (listMatch && currentAgent) {
      currentList = listMatch[1];
      continue;
    }

    const itemMatch = line.match(/^\s{4}-\s+(.+?)\s*$/);
    if (itemMatch && currentAgent && currentList) {
      policy[currentAgent][currentList].push(itemMatch[1].trim());
    }
  }

  return policy;
}

function parseBriefSections(source) {
  const sections = {};
  const activeSlice = {};
  let currentSection = null;

  for (const rawLine of source.split('\n')) {
    const line = rawLine.replace(/\r$/, '');
    const headingMatch = line.match(/^##\s+(.+)$/);
    if (headingMatch) {
      currentSection = headingMatch[1].trim();
      if (!sections[currentSection]) {
        sections[currentSection] = [];
      }
      continue;
    }

    const bulletMatch = line.match(/^- ([^:]+):\s*(.+)$/);
    if (currentSection === 'Active Slice' && bulletMatch) {
      activeSlice[bulletMatch[1].trim()] = bulletMatch[2].trim();
    }

    const listMatch = line.match(/^- (.+)$/);
    if (currentSection && listMatch) {
      sections[currentSection].push(listMatch[1].trim());
    }
  }

  return { sections, activeSlice };
}

function sanitizeBriefEntry(entry) {
  const cleaned = entry.replace(/\s+\(missing\)$/, '').trim();
  if (!cleaned || cleaned.startsWith('latest_review_checkpoint:')) {
    return null;
  }
  return cleaned;
}

function entriesFromSection(sectionEntries) {
  return (sectionEntries || [])
    .map(sanitizeBriefEntry)
    .filter(Boolean)
    .map(normalizeRepoPath)
    .filter(Boolean)
    .filter(isAllowedRelativePath)
    .filter(existsFile);
}

function filterByPrefix(entries, prefixes) {
  return entries.filter((entry) => prefixes.some((prefix) => entry.startsWith(prefix)));
}

function unique(entries) {
  return [...new Set(entries)];
}

function uniqueArray(values) {
  return [...new Set(values)];
}

function gitChangedFiles() {
  try {
    const output = childProcess.execFileSync(
      'git',
      ['-C', repoRoot, 'status', '--short', '--untracked-files=all'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }
    );

    return unique(
      output
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line) => line.replace(/^..?\s+/, ''))
        .map(normalizeRepoPath)
        .filter(Boolean)
        .filter(isAllowedRelativePath)
        .filter(existsFile)
    );
  } catch {
    return [];
  }
}

function collectFilesFromDirectory(relativeDir, options = {}) {
  const absoluteDir = absoluteRepoPath(relativeDir);
  const collected = [];
  const totalLimit = options.totalLimit ?? 12;
  const perDirectoryLimit = options.perDirectoryLimit ?? 4;
  const preferredTokens = new Set((options.preferredTokens || []).filter(Boolean));

  if (!existsDirectory(relativeDir)) {
    return collected;
  }

  function candidateScore(relativePath) {
    const baseName = path.basename(relativePath, path.extname(relativePath)).toLowerCase();
    let preferredHits = 0;

    for (const token of preferredTokens) {
      if (token.length >= 3 && baseName.includes(token)) {
        preferredHits += 1;
      }
    }

    let mtimeMs = 0;
    try {
      mtimeMs = fs.statSync(absoluteRepoPath(relativePath)).mtimeMs;
    } catch {
      mtimeMs = 0;
    }

    return { preferredHits, mtimeMs };
  }

  function walk(currentDir, bucket) {
    const entries = fs.readdirSync(currentDir, { withFileTypes: true })
      .sort((left, right) => left.name.localeCompare(right.name));

    for (const entry of entries) {
      const absolutePath = path.join(currentDir, entry.name);
      const relativePath = normalizeRepoPath(path.relative(repoRoot, absolutePath));

      if (!relativePath || !isAllowedRelativePath(relativePath)) {
        continue;
      }

      if (entry.isDirectory()) {
        if (!relativePath.startsWith('runtime/')) {
          walk(absolutePath, bucket);
        }
        continue;
      }

      if (entry.isFile() && isCodeFile(relativePath)) {
        bucket.push(relativePath);
      }
    }
  }

  const perDirectoryBuckets = new Map();

  function scanDir(currentDir) {
    const relativeCurrent = normalizeRepoPath(path.relative(repoRoot, currentDir)) || relativeDir;
    const bucket = [];
    walk(currentDir, bucket);
    if (bucket.length > 0) {
      perDirectoryBuckets.set(relativeCurrent, bucket);
    }
  }

  scanDir(absoluteDir);

  for (const [, bucket] of perDirectoryBuckets) {
    bucket.sort((left, right) => {
      const leftScore = candidateScore(left);
      const rightScore = candidateScore(right);
      if (rightScore.preferredHits !== leftScore.preferredHits) {
        return rightScore.preferredHits - leftScore.preferredHits;
      }
      if (rightScore.mtimeMs !== leftScore.mtimeMs) {
        return rightScore.mtimeMs - leftScore.mtimeMs;
      }
      return left.localeCompare(right);
    });

    for (const relativePath of bucket.slice(0, perDirectoryLimit)) {
      if (collected.length >= totalLimit) {
        break;
      }
      if (!collected.includes(relativePath)) {
        collected.push(relativePath);
      }
    }
  }

  return collected;
}

function parseContextIndex(contextIndexPath, activeModuleName) {
  if (!existsFile(contextIndexPath)) {
    return [];
  }

  let data;
  try {
    data = JSON.parse(fs.readFileSync(absoluteRepoPath(contextIndexPath), 'utf8'));
  } catch {
    return [];
  }

  const moduleEntry = (data.modules || []).find((entry) => entry.name === activeModuleName);
  if (!moduleEntry) {
    return [];
  }

  const specs = new Map((data.specs || []).map((entry) => [entry.id, entry.path]));
  const apis = new Map((data.apis || []).map((entry) => [entry.id, entry.path]));
  const schemas = new Map((data.schemas || []).map((entry) => [entry.id, entry.path]));
  const ordered = [];

  for (const specId of moduleEntry.specs || []) {
    const specPath = normalizeRepoPath(specs.get(specId));
    if (specPath && isAllowedRelativePath(specPath) && existsFile(specPath)) {
      ordered.push(specPath);
    }
  }

  for (const apiId of moduleEntry.apis || []) {
    const apiPath = normalizeRepoPath(apis.get(apiId));
    if (apiPath && isAllowedRelativePath(apiPath) && existsFile(apiPath)) {
      ordered.push(apiPath);
    }
  }

  for (const schemaId of moduleEntry.schemas || []) {
    const schemaPath = normalizeRepoPath(schemas.get(schemaId));
    if (schemaPath && isAllowedRelativePath(schemaPath) && existsFile(schemaPath)) {
      ordered.push(schemaPath);
    }
  }

  return unique(ordered);
}

function dependencyFiles() {
  const candidates = [
    'package.json',
    'pnpm-lock.yaml',
    'package-lock.json',
    'yarn.lock',
    'bun.lockb',
    'pyproject.toml',
    'poetry.lock',
    'requirements.txt',
    'Cargo.toml',
    'Cargo.lock',
    'go.mod',
    'go.sum'
  ];

  return candidates.filter(existsFile);
}

function priorityLabelToRank(label) {
  switch (label) {
    case 'HIGH':
      return 3;
    case 'MEDIUM':
      return 2;
    default:
      return 1;
  }
}

function categoryDefaultPriority(category) {
  if (category === 'changed-files' || category === 'diff') {
    return 'HIGH';
  }
  if (
    category === 'context-index'
    || category === 'specs'
    || category === 'contracts'
    || category === 'linked-spec'
    || category === 'relevant-module-sources'
    || category === 'security-context'
    || category === 'dependencies'
    || category === 'tasks'
    || category === 'test-files'
  ) {
    return 'MEDIUM';
  }
  return 'LOW';
}

function describeCategoryReason(category) {
  switch (category) {
    case 'changed-files':
    case 'diff':
      return 'changed in git working tree';
    case 'context-index':
      return 'selected from context index or spec registry';
    case 'specs':
      return 'selected from linked specs or API/schema docs';
    case 'contracts':
      return 'selected from agent contracts';
    case 'linked-spec':
      return 'linked spec for active slice';
    case 'relevant-module-sources':
      return 'linked to active module via context index';
    case 'context-accelerators':
      return 'compressed context accelerator';
    case 'relevant-code':
    case 'code':
      return 'general code candidate';
    case 'test-files':
    case 'relevant-tests':
      return 'test-related candidate';
    case 'security-context':
      return 'security context for trust-boundary review';
    case 'dependencies':
      return 'dependency manifest or lockfile';
    case 'tasks':
      return 'task planning artifact';
    case 'docs':
      return 'durable project documentation';
    default:
      return `selected by policy category ${category}`;
  }
}

const policySource = fs.readFileSync(policyFile, 'utf8');
const policy = parseSimpleYamlPolicy(policySource);
const policyAgent = stepToPolicy[step] || step.toUpperCase().replace(/-/g, '_');
const agentPolicy = policy[policyAgent];

if (!agentPolicy) {
  process.stderr.write(`ai-step-runner-codex: no context policy found for ${policyAgent}; falling back to minimal prompt\n`);
  process.exit(10);
}

const briefSource = fs.readFileSync(briefFile, 'utf8');
const { sections, activeSlice } = parseBriefSections(briefSource);
const primarySources = entriesFromSection(sections['Primary Sources']);
const moduleSources = entriesFromSection(sections['Active Module Sources']);
const contextAccelerators = entriesFromSection(sections['Context Accelerators']);
const codeHints = entriesFromSection(sections['Active Module Code Hints']);
const changedFiles = gitChangedFiles();
const linkedSpec = normalizeRepoPath(activeSlice['linked_spec']);
const activeModuleName = activeSlice['module'] || '';
const explicitBriefFiles = unique([
  ...primarySources,
  ...moduleSources,
  ...contextAccelerators,
  ...codeHints.filter((entry) => existsFile(entry))
]);
const explicitBriefSet = new Set(explicitBriefFiles);
const changedFileSet = new Set(changedFiles);

const contextIndexPath = 'ai/context-index/context-map.json';
const dynamicModuleSources = parseContextIndex(contextIndexPath, activeModuleName);
const changedCodeFiles = changedFiles.filter((entry) => isCodeFile(entry) && !isTestFile(entry));
const changedTestFiles = changedFiles.filter(isTestFile);
const contextIndexFileSet = new Set(dynamicModuleSources);
const preferredNameTokens = uniqueArray(dynamicModuleSources
  .map((entry) => path.basename(entry, path.extname(entry)).toLowerCase())
  .flatMap((baseName) => baseName.split(/[^a-z0-9]+/))
  .filter((token) => token.length >= 3));

const hintedCodeFiles = unique(codeHints.flatMap((entry) => {
  if (existsFile(entry) && isCodeFile(entry)) {
    return [entry];
  }
  if (existsDirectory(entry)) {
    return collectFilesFromDirectory(entry, {
      totalLimit: 12,
      perDirectoryLimit: 4,
      preferredTokens: preferredNameTokens
    });
  }
  return [];
}));

const allSpecs = unique([
  ...(linkedSpec && existsFile(linkedSpec) && isAllowedRelativePath(linkedSpec) ? [linkedSpec] : []),
  ...filterByPrefix(primarySources, ['docs/specs/', 'docs/api/', 'docs/database/']),
  ...filterByPrefix(moduleSources, ['docs/specs/', 'docs/api/', 'docs/database/']),
  ...dynamicModuleSources
]);

const docsSources = unique([
  ...filterByPrefix(primarySources, ['docs/']),
  ...filterByPrefix(moduleSources, ['docs/'])
]).filter((entry) => !allSpecs.includes(entry));

const categories = {
  'context-index': unique([contextIndexPath, 'ai/spec-registry/specs.yaml']).filter(existsFile),
  specs: allSpecs,
  'relevant-code': unique([...changedCodeFiles, ...hintedCodeFiles]),
  diff: changedFiles,
  'changed-files': changedFiles,
  code: unique([...changedCodeFiles, ...hintedCodeFiles, ...changedTestFiles]),
  'test-files': unique([
    ...changedTestFiles,
    ...(existsFile('docs/testing/test-plan.md') ? ['docs/testing/test-plan.md'] : [])
  ]),
  dependencies: dependencyFiles(),
  docs: docsSources,
  tasks: filterByPrefix(primarySources, ['tasks/']),
  'linked-spec': linkedSpec && existsFile(linkedSpec) && isAllowedRelativePath(linkedSpec) ? [linkedSpec] : [],
  contracts: filterByPrefix(primarySources, ['ai/contracts/']),
  'context-accelerators': contextAccelerators,
  'security-context': unique([
    'ai/context/security-context.md',
    'ai/context/tenancy-context.md'
  ]).filter(existsFile),
  'relevant-module-sources': unique([...moduleSources, ...dynamicModuleSources]),
  'relevant-tests': changedTestFiles,
  graph: existsFile(normalizeRepoPath(graphFile)) ? [normalizeRepoPath(graphFile)] : []
};

const includeRules = agentPolicy.include || [];
const excludeRules = new Set(agentPolicy.exclude || []);
const candidateMap = new Map();
let encounterIndex = 0;

function registerCandidate(relativePath, category) {
  if (!isAllowedRelativePath(relativePath) || !existsFile(relativePath)) {
    return;
  }

  const existing = candidateMap.get(relativePath);
  const sizeBytes = fs.statSync(absoluteRepoPath(relativePath)).size;
  const estTokens = estimateTokensFromBytes(sizeBytes);
  const reasons = [];
  let priority = categoryDefaultPriority(category);

  if (changedFileSet.has(relativePath)) {
    priority = 'HIGH';
    reasons.push('changed in git working tree');
  }

  if (explicitBriefSet.has(relativePath)) {
    priority = 'HIGH';
    reasons.push('explicitly referenced in step brief');
  }

  if (!reasons.length && contextIndexFileSet.has(relativePath)) {
    reasons.push('linked to active module via context index');
  }

  if (!reasons.length) {
    reasons.push(describeCategoryReason(category));
  }

  if (existing) {
    existing.categories = uniqueArray([...existing.categories, category]);
    existing.reasons = uniqueArray([...existing.reasons, ...reasons]);
    if (priorityLabelToRank(priority) > priorityLabelToRank(existing.priority)) {
      existing.priority = priority;
      existing.priorityRank = priorityLabelToRank(priority);
    }
    return;
  }

  candidateMap.set(relativePath, {
    path: relativePath,
    category,
    categories: [category],
    priority,
    priorityRank: priorityLabelToRank(priority),
    reasons: uniqueArray(reasons),
    sizeBytes,
    estTokens,
    encounterIndex: encounterIndex++
  });
}

for (const rule of includeRules) {
  if (excludeRules.has(rule)) {
    continue;
  }

  for (const relativePath of categories[rule] || []) {
    registerCandidate(relativePath, rule);
  }
}

const orderedCandidates = [...candidateMap.values()].sort((left, right) => {
  if (right.priorityRank !== left.priorityRank) {
    return right.priorityRank - left.priorityRank;
  }
  if (left.encounterIndex !== right.encounterIndex) {
    return left.encounterIndex - right.encounterIndex;
  }
  return left.path.localeCompare(right.path);
});

const selected = [];
const deferred = [];
let selectedTokens = 0;

for (const entry of orderedCandidates) {
  const overFileBudget = selected.length >= maxFiles;
  const overTokenBudget = selectedTokens + entry.estTokens > maxTokens && selected.length > 0;

  if (overFileBudget || overTokenBudget) {
    deferred.push({
      ...entry,
      droppedBecause: overFileBudget
        ? 'file budget exceeded'
        : `token budget exceeded (${selectedTokens + entry.estTokens} > ${maxTokens})`
    });
    continue;
  }

  selected.push(entry);
  selectedTokens += entry.estTokens;
}

const manifestLines = [
  '# Selective Context Manifest',
  '',
  `- policy_file: ${toRelative(policyFile)}`,
  `- policy_agent: ${policyAgent}`,
  `- step: ${step}`,
  `- include_rules: ${includeRules.length > 0 ? includeRules.join(', ') : 'none'}`,
  `- exclude_rules: ${excludeRules.size > 0 ? [...excludeRules].join(', ') : 'none'}`,
  `- context_budget_files: ${maxFiles}`,
  `- context_budget_bytes: ${maxBytes}`,
  `- context_budget_tokens: ${maxTokens}`,
  `- selected_files: ${selected.length}`,
  `- deferred_files: ${deferred.length}`,
  `- estimated_tokens: ${selectedTokens}`,
  '',
  '## Selected Files',
  ''
];

if (selected.length === 0) {
  manifestLines.push('- none');
} else {
  for (const entry of selected) {
    manifestLines.push(`- ${entry.path} | priority=${entry.priority} | categories=${entry.categories.join(',')} | est_tokens=${entry.estTokens} | why=${entry.reasons.join('; ')}`);
  }
}

manifestLines.push(
  '',
  '## Deferred Files',
  ''
);

if (deferred.length === 0) {
  manifestLines.push('- none');
} else {
  for (const entry of deferred) {
    manifestLines.push(`- ${entry.path} | priority=${entry.priority} | categories=${entry.categories.join(',')} | est_tokens=${entry.estTokens} | dropped=${entry.droppedBecause} | why=${entry.reasons.join('; ')}`);
  }
}

manifestLines.push(
  '',
  '## Routing Notes',
  '',
  '- Use this manifest as the default context pack for the active step.',
  '- Open selected files before expanding into other repository areas.',
  '- Avoid `*.template.md` files unless no instantiated equivalent exists and the active task explicitly requires them.',
  '- `tasks/task-graph.json` remains the source of truth for execution order.',
  '- Expand beyond this manifest only when the selected context is insufficient for the active slice.'
);

fs.writeFileSync(manifestFile, `${manifestLines.join('\n')}\n`);

if (debug) {
  process.stderr.write(`ai-step-runner-codex: context policy ${toRelative(policyFile)} applied for ${policyAgent}\n`);
  process.stderr.write(`ai-step-runner-codex: selected ${selected.length} files, deferred ${deferred.length}, est_tokens=${selectedTokens}, token_budget=${maxTokens}\n`);
  for (const entry of selected) {
    process.stderr.write(`ai-step-runner-codex: + ${entry.path} [priority=${entry.priority}] [${entry.categories.join(',')}] ~${entry.estTokens}t because ${entry.reasons.join('; ')}\n`);
  }
  for (const entry of deferred) {
    process.stderr.write(`ai-step-runner-codex: - ${entry.path} [priority=${entry.priority}] [${entry.categories.join(',')}] ~${entry.estTokens}t dropped: ${entry.droppedBecause}\n`);
  }
}
NODE

  local node_exit=$?
  set -e
  if [[ $node_exit -eq 10 ]]; then
    rm -f "$CONTEXT_MANIFEST_FILE"
    return 1
  fi
  if [[ $node_exit -ne 0 ]]; then
    fail "failed to build selective context manifest"
  fi

  return 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --step)
      STEP="$2"
      shift 2
      ;;
    --agent)
      AGENT_FILE="$2"
      shift 2
      ;;
    --prompt)
      PROMPT_FILE="$2"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --brief)
      BRIEF_FILE="$2"
      shift 2
      ;;
    --graph)
      GRAPH_FILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unsupported argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

for required in STEP AGENT_FILE PROMPT_FILE REPO_ROOT BRIEF_FILE GRAPH_FILE; do
  if [[ -z "${!required}" ]]; then
    printf 'missing required argument: %s\n' "$required" >&2
    usage >&2
    exit 1
  fi
done

[[ -d "$REPO_ROOT" ]] || fail "repository root does not exist: ${REPO_ROOT}"
[[ -f "$AGENT_FILE" ]] || fail "missing agent file: ${AGENT_FILE}"
[[ -f "$PROMPT_FILE" ]] || fail "missing prompt file: ${PROMPT_FILE}"
[[ -f "$BRIEF_FILE" ]] || fail "missing step brief: ${BRIEF_FILE}"
[[ -f "$GRAPH_FILE" ]] || fail "missing graph file: ${GRAPH_FILE}"

if ! command -v codex >/dev/null 2>&1; then
  fail "codex binary not found in PATH"
fi

RUN_ID=$(basename "$BRIEF_FILE")
RUN_ID="${RUN_ID%.brief.md}"
LOG_FILE="${REPO_ROOT}/runtime/logs/${RUN_ID}.result.md"
TASK_ID=$(resolve_task_id)
POLICY_FILE="${REPO_ROOT}/ai/context-policy.yaml"
CONTEXT_MANIFEST_FILE="${REPO_ROOT}/runtime/context-cache/${RUN_ID}.context.md"
resolve_frontend_skill_file
resolve_step_timeout_seconds

TMP_PROMPT=$(mktemp)
trap 'rm -f "$TMP_PROMPT"' EXIT

READ_FILES=$(cat <<EOF
- \`${AGENT_FILE}\`
- \`${PROMPT_FILE}\`
- \`${BRIEF_FILE}\`
EOF
)

if [[ -n "$FRONTEND_SKILL_FILE" ]]; then
  READ_FILES="${READ_FILES}
- \`${FRONTEND_SKILL_FILE}\`"
fi

ROUTING_REQUIREMENTS=$(cat <<'EOF'
- Use the step brief as the default context pack and expand only when the current task actually requires more detail.
- Work only on the responsibilities of this step.
- Use the repository source of truth and existing working docs before templates.
- Keep runtime outputs under `runtime/`.
- If the step does not require source changes, produce the expected runtime/doc outputs only.
- Prefer referenced files over re-reading broad doc sets.
- Do not inspect git state, runner scripts, Make targets, or unrelated runtime files unless the current step is blocked and the missing information is not present in the routed inputs.
EOF
)

if prepare_context_manifest; then
  READ_FILES="${READ_FILES}
- \`${CONTEXT_MANIFEST_FILE}\`"
  ROUTING_REQUIREMENTS=$(cat <<'EOF'
- Use the selective context manifest as the default routing policy for this step.
- Open selected files from the manifest before exploring other repository areas.
- Do not load full documentation sets or unrelated repository areas unless the selected context is insufficient.
- Avoid `*.template.md` files unless no instantiated equivalent exists and the active task explicitly requires them.
- Work only on the responsibilities of this step.
- Use the repository source of truth and existing working docs before templates.
- Keep runtime outputs under `runtime/`.
- If the step does not require source changes, produce the expected runtime/doc outputs only.
- Do not inspect git state, runner scripts, Make targets, or unrelated runtime files unless the current step is blocked and the missing information is not present in the routed inputs.
EOF
)
fi

SKILL_REQUIREMENTS=""
if [[ -n "$FRONTEND_SKILL_FILE" ]]; then
  SKILL_REQUIREMENTS=$(cat <<'EOF'
- Use the Efizion frontend excellence skill as an explicit implementation and review checklist when the active slice affects UI.
- Follow the skill requirements for Tailwind CSS plus shadcn/ui when the stack supports them, explicit interaction states, WCAG AA accessibility, and responsive verification.
EOF
)
fi

STEP_DISCIPLINE=""
case "$STEP" in
  prd-writer)
    STEP_DISCIPLINE=$(cat <<'EOF'
- For `prd-writer`, the main durable output is `docs/prd.md`. Move from routed inputs to authoring quickly once the questionnaire and current PRD have been read.
EOF
)
    ;;
  prd-reviewer)
    STEP_DISCIPLINE=$(cat <<'EOF'
- For `prd-reviewer`, create `docs/audit/prd-review.md` directly from the PRD and supporting docs. Missing prior review output is expected and is not a blocker.
EOF
)
    ;;
  prd-auditor)
    STEP_DISCIPLINE=$(cat <<'EOF'
- For `prd-auditor`, update `docs/prd-quality-checklist.md` and `docs/audit/prd-score.md` directly from the PRD, checklist, and review when present. Missing review output is allowed.
EOF
)
    ;;
esac

cat > "$TMP_PROMPT" <<EOF
Execute the repository pipeline step \`${STEP}\` for this project.

Repository root: \`${REPO_ROOT}\`
Active task: \`${TASK_ID}\`
Graph file: \`${GRAPH_FILE}\`
Read these files first:
${READ_FILES}

Requirements:
${ROUTING_REQUIREMENTS}
${SKILL_REQUIREMENTS}
${STEP_DISCIPLINE}
- At the end, summarize what you changed, what you verified, and any blockers.
EOF

CODEX_ARGS=(
  exec
  -C "$REPO_ROOT"
  --ephemeral
  -o "$LOG_FILE"
)

if ! git -C "$REPO_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
  CODEX_ARGS+=(--skip-git-repo-check)
fi

case "$STEP" in
  planner|spec-generator|reviewer|tester|frontend-auditor|security|prd-writer|prd-reviewer|prd-auditor)
    CODEX_ARGS+=(-m gpt-5.4-mini)
    ;;
esac

if [[ "${CODEX_PRIVILEGED:-false}" == "true" ]]; then
  if [[ -z "${CODEX_PRIVILEGED_REASON:-}" ]]; then
    printf 'CODEX_PRIVILEGED_REASON is required when CODEX_PRIVILEGED=true\n' >&2
    exit 1
  fi

  log_privileged_use "$TASK_ID"
  CODEX_ARGS+=(--dangerously-bypass-approvals-and-sandbox)
else
  CODEX_ARGS+=(--full-auto)
fi

if [[ ! "$STEP_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]]; then
  fail "invalid step timeout seconds: ${STEP_TIMEOUT_SECONDS}"
fi

timeout --foreground --kill-after=15s "${STEP_TIMEOUT_SECONDS}s" \
  codex "${CODEX_ARGS[@]}" - < "$TMP_PROMPT"

validate_runner_output
