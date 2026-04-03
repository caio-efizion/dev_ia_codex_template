#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
DRY_RUN=0

fail() {
  printf 'ai-adopt-existing: %s\n' "$1" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage:
  ai-adopt-existing.sh [--dry-run]

Purpose:
  Prepare an existing project repository to adopt the Efizion template controls.

What it does:
  - runs ai-init-project.sh safely
  - inspects the current repository stack
  - seeds quality/pipeline.config.json when missing
  - prefills safe questionnaire fields for existing-product-evolution
  - writes docs/adoption/existing-system-inventory.md
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
  node - "$inventory_json" <<'NODE'
const fs = require('fs');
const inventory = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

console.log('ai-adopt-existing dry-run');
console.log(`- repo: ${inventory.repoName}`);
console.log(`- suggested delivery mode: ${inventory.deliveryModeSuggestion}`);
console.log(`- package manager: ${inventory.packageManager}`);
console.log(`- frontend detected: ${inventory.frontend.detected}`);
console.log(`- frontend stack: ${inventory.questionnairePrefill.frontendStack}`);
console.log(`- backend stack: ${inventory.questionnairePrefill.backendStack}`);
console.log(`- quality config exists: ${inventory.qualityConfig.exists}`);
console.log(`- inventory file to write: docs/adoption/existing-system-inventory.md`);
console.log(`- questionnaire fields to prefill: Delivery mode, Project name, Frontend stack, Backend stack, Existing codebase or system context, Must-preserve systems or contracts, Tooling constraints`);
console.log(`- next recommended commands: make ai-audit-security, make ai-audit-frontend, make ai-define, make ai-build, make ai-prove`);
NODE
  exit 0
fi

bash "${SCRIPT_DIR}/ai-init-project.sh"
mkdir -p "${REPO_ROOT}/docs/adoption" "${REPO_ROOT}/quality"

if [[ ! -f "${REPO_ROOT}/quality/pipeline.config.json" && -f "${REPO_ROOT}/quality/pipeline.config.template.json" ]]; then
  cp "${REPO_ROOT}/quality/pipeline.config.template.json" "${REPO_ROOT}/quality/pipeline.config.json"
fi

node - "$inventory_json" "${REPO_ROOT}/docs/prd-questionnaire.md" "${REPO_ROOT}/quality/pipeline.config.json" "${REPO_ROOT}/docs/adoption/existing-system-inventory.md" <<'NODE'
const fs = require('fs');
const path = require('path');

const [, , inventoryFile, questionnaireFile, qualityConfigFile, inventoryMarkdownFile] = process.argv;
const inventory = JSON.parse(fs.readFileSync(inventoryFile, 'utf8'));

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function fillBlankBullet(text, label, value) {
  if (!value) {
    return text;
  }

  const pattern = new RegExp(`^- ${escapeRegExp(label)}:\\s*$`, 'm');
  if (pattern.test(text)) {
    return text.replace(pattern, `- ${label}: ${value}`);
  }

  return text;
}

function suggestBaseUrl(inventoryData) {
  const frameworks = inventoryData.frontend.frameworks.map((value) => value.toLowerCase());
  const startScript = inventoryData.commandHints.start.script;

  if (frameworks.includes('next.js')) {
    return 'http://127.0.0.1:3000';
  }

  if (frameworks.includes('vite')) {
    if (startScript === 'dev') {
      return 'http://127.0.0.1:5173';
    }
    return 'http://127.0.0.1:4173';
  }

  return 'http://127.0.0.1:3000';
}

function applyQuestionnairePrefill() {
  if (!fs.existsSync(questionnaireFile)) {
    return;
  }

  let questionnaire = fs.readFileSync(questionnaireFile, 'utf8');
  const replacements = new Map([
    ['Delivery mode', inventory.questionnairePrefill.deliveryMode],
    ['Project name', inventory.questionnairePrefill.projectName],
    ['Frontend stack', inventory.questionnairePrefill.frontendStack],
    ['Backend stack', inventory.questionnairePrefill.backendStack],
    ['Existing codebase or system context', inventory.questionnairePrefill.existingCodebaseContext],
    ['Must-preserve systems or contracts', inventory.questionnairePrefill.mustPreserveSystemsOrContracts],
    ['Tooling constraints', inventory.questionnairePrefill.toolingConstraints],
  ]);

  for (const [label, value] of replacements.entries()) {
    questionnaire = fillBlankBullet(questionnaire, label, value);
  }

  fs.writeFileSync(questionnaireFile, questionnaire);
}

function applyQualityConfigHints() {
  if (!fs.existsSync(qualityConfigFile)) {
    return;
  }

  const config = JSON.parse(fs.readFileSync(qualityConfigFile, 'utf8'));
  config.commands = config.commands || {};

  for (const gateName of ['lint', 'typecheck', 'unit', 'e2e', 'coverage']) {
    config.commands[gateName] = config.commands[gateName] || {};
    const hint = inventory.commandHints[gateName];
    if (!hint) continue;

    if ((!config.commands[gateName].command || config.commands[gateName].command === 'replace-me') && hint.command) {
      config.commands[gateName].command = hint.command;
    }
    if ((!config.commands[gateName].cwd || config.commands[gateName].cwd === '.') && hint.cwd && hint.cwd !== '.') {
      config.commands[gateName].cwd = hint.cwd;
    }
  }

  config.security = config.security || {};
  config.security.dependencyScan = config.security.dependencyScan || {};
  if (
    (!config.security.dependencyScan.command || config.security.dependencyScan.command === 'replace-me')
    && inventory.commandHints.dependencyScan.command
  ) {
    config.security.dependencyScan.command = inventory.commandHints.dependencyScan.command;
  }
  if (
    (!config.security.dependencyScan.cwd || config.security.dependencyScan.cwd === '.')
    && inventory.commandHints.dependencyScan.cwd
    && inventory.commandHints.dependencyScan.cwd !== '.'
  ) {
    config.security.dependencyScan.cwd = inventory.commandHints.dependencyScan.cwd;
  }

  config.frontendEvidence = config.frontendEvidence || {};

  if (!inventory.frontend.detected) {
    config.frontendEvidence.enabled = false;
  } else {
    config.frontendEvidence.enabled = true;
    if ((!config.frontendEvidence.cwd || config.frontendEvidence.cwd === '.') && inventory.commandHints.start.cwd && inventory.commandHints.start.cwd !== '.') {
      config.frontendEvidence.cwd = inventory.commandHints.start.cwd;
    }
    if ((!config.frontendEvidence.startCommand || config.frontendEvidence.startCommand === 'replace-me') && inventory.commandHints.start.command) {
      config.frontendEvidence.startCommand = inventory.commandHints.start.command;
    }
    if (!config.frontendEvidence.baseUrl || config.frontendEvidence.baseUrl === 'http://127.0.0.1:4173') {
      config.frontendEvidence.baseUrl = suggestBaseUrl(inventory);
    }
  }

  fs.writeFileSync(qualityConfigFile, `${JSON.stringify(config, null, 2)}\n`);
}

function writeInventoryMarkdown() {
  const lines = [
    '# Existing System Inventory',
    '',
    `- generated_at: \`${inventory.inspectedAt}\``,
    `- project_name: \`${inventory.repoName}\``,
    `- delivery_mode_suggestion: \`${inventory.deliveryModeSuggestion}\``,
    `- package_manager: \`${inventory.packageManager}\``,
    '',
    '## Stack Summary',
    '',
    `- frontend_stack: ${inventory.questionnairePrefill.frontendStack}`,
    `- backend_stack: ${inventory.questionnairePrefill.backendStack}`,
    '',
    '## Existing System Context',
    '',
    `- ${inventory.questionnairePrefill.existingCodebaseContext}`,
    '',
    '## Preserve First',
    '',
  ];

  if (inventory.preserveCandidates.length === 0) {
    lines.push('- no concrete preserve candidates were detected automatically; validate routes, auth, public APIs, and deployment contracts manually');
  } else {
    for (const candidate of inventory.preserveCandidates) {
      lines.push(`- \`${candidate}\``);
    }
  }

  lines.push('', '## Frontend Signals', '');
  lines.push(`- frontend_detected: ${inventory.frontend.detected}`);
  lines.push(`- frameworks: ${inventory.frontend.frameworks.join(', ') || 'none detected'}`);
  lines.push(`- styling: ${inventory.frontend.styling.join(', ') || 'none detected'}`);
  lines.push(`- component_libraries: ${inventory.frontend.componentLibraries.join(', ') || 'none detected'}`);
  lines.push(`- roots: ${inventory.frontend.roots.join(', ') || 'none detected'}`);
  lines.push(`- route_hints: ${inventory.frontend.routeHints.join(', ') || 'none detected'}`);
  lines.push(`- token_files: ${inventory.frontend.tokenFileHints.join(', ') || 'none detected'}`);
  lines.push(`- inline_style_count: ${inventory.frontend.inlineStyleCount}`);
  lines.push(`- raw_hex_color_count: ${inventory.frontend.rawHexColorCount}`);
  lines.push('', '## Quality Config Seeding', '');
  lines.push(`- config_path: \`${inventory.qualityConfig.path || 'quality/pipeline.config.json'}\``);
  lines.push(`- frontend_evidence_enabled: ${inventory.qualityConfig.frontendEvidenceEnabled}`);
  lines.push(`- route_config_ready: ${inventory.qualityConfig.routeConfigReady}`);
  lines.push(`- lint_command_configured: ${inventory.qualityConfig.commands ? inventory.qualityConfig.commands.lint : false}`);
  lines.push(`- typecheck_command_configured: ${inventory.qualityConfig.commands ? inventory.qualityConfig.commands.typecheck : false}`);
  lines.push(`- unit_command_configured: ${inventory.qualityConfig.commands ? inventory.qualityConfig.commands.unit : false}`);
  lines.push(`- e2e_command_configured: ${inventory.qualityConfig.commands ? inventory.qualityConfig.commands.e2e : false}`);
  lines.push(`- coverage_command_configured: ${inventory.qualityConfig.commands ? inventory.qualityConfig.commands.coverage : false}`);
  lines.push('', '## Suggested Next Slices', '');

  if (inventory.frontend.recommendedSlices.length === 0) {
    lines.push('- review the inventory, then run `make ai-define`, `make ai-build`, and `make ai-prove`');
  } else {
    for (const slice of inventory.frontend.recommendedSlices) {
      lines.push(`- ${slice}`);
    }
  }

  lines.push('', '## Next Commands', '');
  lines.push('- `make ai-audit-security`');
  lines.push('- `make ai-audit-frontend`');
  lines.push('- `make ai-define`');
  lines.push('- `make ai-build`');
  lines.push('- `make ai-prove`');

  fs.mkdirSync(path.dirname(inventoryMarkdownFile), { recursive: true });
  fs.writeFileSync(inventoryMarkdownFile, `${lines.join('\n')}\n`);
}

applyQuestionnairePrefill();
applyQualityConfigHints();
writeInventoryMarkdown();
NODE

printf '%s\n' "existing project adoption scaffolded"
printf '%s\n' "inventory: docs/adoption/existing-system-inventory.md"
printf '%s\n' "next: make ai-audit-security && make ai-audit-frontend && make ai-define"
