#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DRY_RUN=0
MIN_SCORE="${AI_FRONTEND_AUDIT_MIN_SCORE:-70}"

fail() {
  printf 'ai-audit-frontend: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ai-audit-frontend.sh [--dry-run]

Purpose:
  Audit an existing frontend against the Efizion quality baseline and write
  docs/audit/frontend-audit.md.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      fail "unsupported argument: $1"
      ;;
  esac
done

INSPECTOR_FILE="${REPO_ROOT}/scripts/ai-inspect-existing-project.mjs"
[[ -f "$INSPECTOR_FILE" ]] || fail "missing inspector file: ${INSPECTOR_FILE}"
command -v node >/dev/null 2>&1 || fail "node binary not found in PATH"

inventory_json=$(mktemp)
trap 'rm -f "$inventory_json"' EXIT

node "$INSPECTOR_FILE" --repo-root "$REPO_ROOT" --output "$inventory_json"

if [[ "$DRY_RUN" == "1" ]]; then
  node - "$inventory_json" "$MIN_SCORE" <<'NODE'
const fs = require('fs');
const inventory = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const minScore = Number(process.argv[3] || '70');

console.log('ai-audit-frontend dry-run');
console.log(`- frontend detected: ${inventory.frontend.detected}`);
console.log(`- frameworks: ${inventory.frontend.frameworks.join(', ') || 'none detected'}`);
console.log(`- styling: ${inventory.frontend.styling.join(', ') || 'none detected'}`);
console.log(`- roots: ${inventory.frontend.roots.join(', ') || 'none detected'}`);
console.log(`- route hints: ${inventory.frontend.routeHints.join(', ') || 'none detected'}`);
console.log(`- concerns: ${inventory.frontend.concerns.join('; ') || 'none detected'}`);
console.log(`- min score: ${minScore}`);
console.log(`- report file to write: docs/audit/frontend-audit.md`);
NODE
  exit 0
fi

mkdir -p "${REPO_ROOT}/docs/audit"

node - "$inventory_json" "${REPO_ROOT}/docs/audit/frontend-audit.md" "$MIN_SCORE" <<'NODE'
const fs = require('fs');

const [, , inventoryFile, reportFile, minScoreRaw] = process.argv;
const inventory = JSON.parse(fs.readFileSync(inventoryFile, 'utf8'));
const minScore = Number.parseInt(minScoreRaw || '70', 10);

if (!inventory.frontend.detected) {
  const lines = [
    '# Frontend Audit',
    '',
    '- status: `not-applicable`',
    '- overall_score: 100',
    '- reason: `No browser UI was detected in the inspected repository.`',
    '',
    '## Notes',
    '',
    '- Use `make ai-audit-security` and the project PRD flow instead of frontend refactor slices.',
  ];
  fs.writeFileSync(reportFile, `${lines.join('\n')}\n`);
  process.exit(0);
}

function pass(id, criterion, evidence) {
  return { id, criterion, status: 'pass', evidence };
}

function failCheck(id, criterion, evidence) {
  return { id, criterion, status: 'fail', evidence };
}

const checks = [];
checks.push(
  inventory.frontend.docs.architecture
    ? pass('frontend-architecture-doc', 'frontend architecture doc exists', 'docs/architecture/frontend-architecture.md')
    : failCheck('frontend-architecture-doc', 'frontend architecture doc exists', 'missing docs/architecture/frontend-architecture.md')
);
checks.push(
  inventory.frontend.docs.designSystem
    ? pass('design-system-doc', 'design system doc exists', 'docs/specs/design-system.md')
    : failCheck('design-system-doc', 'design system doc exists', 'missing docs/specs/design-system.md')
);
checks.push(
  inventory.frontend.docs.qualityGates
    ? pass('quality-gates-doc', 'frontend quality gates doc exists', 'docs/specs/frontend-quality-gates.md')
    : failCheck('quality-gates-doc', 'frontend quality gates doc exists', 'missing docs/specs/frontend-quality-gates.md')
);
checks.push(
  inventory.frontend.docs.uxJourneys
    ? pass('ux-journeys-doc', 'UX journeys doc exists', 'docs/specs/ux-research-and-journeys.md')
    : failCheck('ux-journeys-doc', 'UX journeys doc exists', 'missing docs/specs/ux-research-and-journeys.md')
);
checks.push(
  inventory.qualityConfig.exists
    ? pass('quality-config', 'quality config exists', inventory.qualityConfig.path)
    : failCheck('quality-config', 'quality config exists', 'missing quality/pipeline.config.json')
);
checks.push(
  inventory.qualityConfig.frontendEvidenceEnabled
    ? pass('frontend-evidence-enabled', 'frontend evidence is enabled', inventory.qualityConfig.path || 'quality/pipeline.config.json')
    : failCheck('frontend-evidence-enabled', 'frontend evidence is enabled', 'frontendEvidence.enabled is false or missing')
);
checks.push(
  inventory.qualityConfig.commands?.lint || inventory.commandHints.lint.command
    ? pass('lint-command', 'lint command is configured or detectable', inventory.commandHints.lint.command || 'quality config')
    : failCheck('lint-command', 'lint command is configured or detectable', 'no lint script or quality gate command detected')
);
checks.push(
  inventory.qualityConfig.commands?.typecheck || inventory.commandHints.typecheck.command
    ? pass('typecheck-command', 'typecheck command is configured or detectable', inventory.commandHints.typecheck.command || 'quality config')
    : failCheck('typecheck-command', 'typecheck command is configured or detectable', 'no typecheck script or quality gate command detected')
);
checks.push(
  inventory.qualityConfig.commands?.unit || inventory.commandHints.unit.command
    ? pass('unit-command', 'unit command is configured or detectable', inventory.commandHints.unit.command || 'quality config')
    : failCheck('unit-command', 'unit command is configured or detectable', 'no unit script or quality gate command detected')
);
checks.push(
  inventory.qualityConfig.commands?.e2e || inventory.commandHints.e2e.command
    ? pass('e2e-command', 'e2e command is configured or detectable', inventory.commandHints.e2e.command || 'quality config')
    : failCheck('e2e-command', 'e2e command is configured or detectable', 'no e2e script or quality gate command detected')
);
checks.push(
  inventory.qualityConfig.commands?.coverage || inventory.commandHints.coverage.command
    ? pass('coverage-command', 'coverage command is configured or detectable', inventory.commandHints.coverage.command || 'quality config')
    : failCheck('coverage-command', 'coverage command is configured or detectable', 'no coverage script or quality gate command detected')
);
checks.push(
  inventory.frontend.styling.includes('Tailwind CSS')
    ? pass('tailwind-baseline', 'styling is aligned to the Tailwind-first baseline', inventory.frontend.styling.join(', '))
    : failCheck('tailwind-baseline', 'styling is aligned to the Tailwind-first baseline', inventory.frontend.styling.join(', ') || 'no Tailwind CSS detected')
);
checks.push(
  inventory.frontend.componentLibraries.length > 0
    ? pass('component-primitives', 'shared component primitives are detectable', inventory.frontend.componentLibraries.join(', '))
    : failCheck('component-primitives', 'shared component primitives are detectable', 'no shared component primitive signal detected')
);
checks.push(
  inventory.frontend.tokenFileHints.length > 0
    ? pass('design-tokens', 'design token files are detectable', inventory.frontend.tokenFileHints.join(', '))
    : failCheck('design-tokens', 'design token files are detectable', 'no token-like CSS custom property file detected')
);
checks.push(
  inventory.frontend.inlineStyleCount <= 5
    ? pass('inline-style-usage', 'inline styles remain limited', `inline style count: ${inventory.frontend.inlineStyleCount}`)
    : failCheck('inline-style-usage', 'inline styles remain limited', `inline style count: ${inventory.frontend.inlineStyleCount}`)
);
checks.push(
  inventory.frontend.rawHexColorCount <= 10
    ? pass('raw-color-usage', 'raw color literals remain limited', `raw hex color count: ${inventory.frontend.rawHexColorCount}`)
    : failCheck('raw-color-usage', 'raw color literals remain limited', `raw hex color count: ${inventory.frontend.rawHexColorCount}`)
);

const passCount = checks.filter((check) => check.status === 'pass').length;
const overallScore = Math.round((passCount / checks.length) * 100);
const failingChecks = checks.filter((check) => check.status === 'fail');
const status = overallScore >= minScore ? 'aligned' : 'needs-refactor';

const recommendedSlices = [...new Set([
  ...inventory.frontend.recommendedSlices,
  ...failingChecks.map((check) => {
    switch (check.id) {
      case 'frontend-architecture-doc':
      case 'design-system-doc':
      case 'quality-gates-doc':
      case 'ux-journeys-doc':
        return 'create and align the missing frontend governance docs before broad refactors';
      case 'quality-config':
      case 'frontend-evidence-enabled':
        return 'configure quality/pipeline.config.json for frontend evidence and route coverage';
      case 'lint-command':
      case 'typecheck-command':
      case 'unit-command':
      case 'e2e-command':
      case 'coverage-command':
        return 'wire deterministic lint, typecheck, unit, e2e, and coverage commands into the quality config';
      case 'tailwind-baseline':
      case 'component-primitives':
      case 'design-tokens':
        return 'introduce a tokenized design-system layer and shared primitives before visual refactors';
      case 'inline-style-usage':
      case 'raw-color-usage':
        return 'extract inline styles and raw color literals into reusable primitives and tokens';
      default:
        return 'open a frontend adoption slice for the missing requirement';
    }
  }),
])];

const lines = [
  '# Frontend Audit',
  '',
  `- status: \`${status}\``,
  `- overall_score: ${overallScore}`,
  `- minimum_recommended_score: ${minScore}`,
  `- frontend_stack: ${inventory.questionnairePrefill.frontendStack}`,
  '',
  '## Inventory',
  '',
  `- roots: ${inventory.frontend.roots.join(', ') || 'none detected'}`,
  `- route_hints: ${inventory.frontend.routeHints.join(', ') || 'none detected'}`,
  `- token_files: ${inventory.frontend.tokenFileHints.join(', ') || 'none detected'}`,
  `- inline_style_count: ${inventory.frontend.inlineStyleCount}`,
  `- raw_hex_color_count: ${inventory.frontend.rawHexColorCount}`,
  '',
  '## Checks',
  '',
];

for (const check of checks) {
  lines.push(`- [${check.status}] ${check.criterion} (${check.evidence})`);
}

lines.push('', '## Existing Concerns', '');
if (inventory.frontend.concerns.length === 0) {
  lines.push('- none');
} else {
  for (const concern of inventory.frontend.concerns) {
    lines.push(`- ${concern}`);
  }
}

lines.push('', '## Recommended Slices', '');
if (recommendedSlices.length === 0) {
  lines.push('- none');
} else {
  for (const slice of recommendedSlices) {
    lines.push(`- ${slice}`);
  }
}

fs.writeFileSync(reportFile, `${lines.join('\n')}\n`);

if (overallScore < minScore) {
  process.exit(1);
}
NODE

printf '%s\n' "frontend audit written to docs/audit/frontend-audit.md"
