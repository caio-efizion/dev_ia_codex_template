#!/usr/bin/env node
import fs from 'fs';
import path from 'path';
import { spawn } from 'child_process';
import { createRequire } from 'module';
import http from 'http';
import https from 'https';

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const arg = argv[i];
    if (!arg.startsWith('--')) continue;
    args[arg.slice(2)] = argv[i + 1];
    i += 1;
  }
  return args;
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function fileExists(file) {
  try {
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
}

async function waitForUrl(url, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const ok = await new Promise((resolve) => {
      const client = url.startsWith('https://') ? https : http;
      const req = client.get(url, (res) => {
        res.resume();
        resolve(res.statusCode && res.statusCode < 500);
      });
      req.on('error', () => resolve(false));
      req.setTimeout(1500, () => {
        req.destroy();
        resolve(false);
      });
    });
    if (ok) return true;
    await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  return false;
}

function createScopedRequire(appDir) {
  return createRequire(path.join(appDir, 'package.json'));
}

function normalizeStateEntries(route) {
  if (Array.isArray(route.states) && route.states.length > 0) {
    return route.states;
  }
  return [{ id: 'default', path: route.path }];
}

async function main() {
  const args = parseArgs(process.argv);
  const configFile = path.resolve(args.config);
  const sliceId = args.slice;
  const reportDir = path.resolve(args['report-dir']);
  if (!configFile || !sliceId || !reportDir) {
    throw new Error('missing required arguments: --config --slice --report-dir');
  }

  const repoRoot = process.cwd();
  const config = readJson(configFile);
  const frontend = config.frontendEvidence || {};
  if (!frontend.enabled) {
    fs.writeFileSync(path.join(reportDir, 'frontend-evidence-summary.json'), JSON.stringify({ enabled: false }, null, 2) + '\n');
    return;
  }

  const appDir = path.resolve(repoRoot, frontend.cwd || '.');
  const requireFromApp = createScopedRequire(appDir);
  const { chromium } = requireFromApp('playwright');
  const AxeBuilder = requireFromApp('@axe-core/playwright').default;
  const lighthouseModule = requireFromApp('lighthouse');
  const lighthouse = lighthouseModule.default || lighthouseModule;
  const chromeLauncher = requireFromApp('chrome-launcher');
  const pixelmatchModule = requireFromApp('pixelmatch');
  const pixelmatch = pixelmatchModule.default || pixelmatchModule;
  const { PNG } = requireFromApp('pngjs');

  ensureDir(reportDir);
  const screenshotDir = path.join(reportDir, 'screenshots');
  const diffDir = path.join(reportDir, 'visual-diff');
  ensureDir(screenshotDir);
  ensureDir(diffDir);

  const baseUrl = frontend.baseUrl;
  const startupTimeoutMs = Number(frontend.startupTimeoutMs || 120000);
  let serverProcess = null;
  const serverLog = path.join(reportDir, 'frontend-server.log');

  const alreadyUp = await waitForUrl(baseUrl, 2000);
  if (!alreadyUp && frontend.startCommand) {
    serverProcess = spawn('bash', ['-lc', frontend.startCommand], {
      cwd: appDir,
      stdio: ['ignore', 'pipe', 'pipe']
    });
    const logStream = fs.createWriteStream(serverLog, { flags: 'a' });
    serverProcess.stdout.pipe(logStream);
    serverProcess.stderr.pipe(logStream);
    const ready = await waitForUrl(baseUrl, startupTimeoutMs);
    if (!ready) {
      throw new Error(`frontend server did not become reachable at ${baseUrl}`);
    }
  }

  const viewports = frontend.viewports || [];
  const routes = frontend.routes || [];
  if (viewports.length === 0 || routes.length === 0) {
    throw new Error('frontend evidence is enabled but routes or viewports are not configured');
  }
  const axeMaxSerious = Number(frontend.axeMaxSeriousViolations ?? 0);
  const visualConfig = frontend.visualRegression || { enabled: false };
  const baselineDir = path.resolve(repoRoot, visualConfig.baselineDir || 'quality/baselines');
  const baselineMode = process.env.AI_VISUAL_BASELINE_MODE || 'compare';
  const lighthouseThresholds = frontend.lighthouse || { performance: 85, accessibility: 95 };

  const browser = await chromium.launch();
  const screenshotEntries = [];
  const a11yResults = [];
  const visualResults = [];
  let accessibilityPassed = true;
  let visualRegressionPassed = true;

  try {
    for (const route of routes) {
      const states = normalizeStateEntries(route);
      for (const viewport of viewports) {
        for (const state of states) {
          const url = new URL(state.path, baseUrl).toString();
          const context = await browser.newContext({ viewport: { width: viewport.width, height: viewport.height } });
          const page = await context.newPage();
          await page.goto(url, { waitUntil: 'networkidle' });
          const screenshotName = `${route.id}-${state.id}-${viewport.id}.png`;
          const screenshotPath = path.join(screenshotDir, screenshotName);
          await page.screenshot({ path: screenshotPath, fullPage: true });
          screenshotEntries.push({ route: route.id, state: state.id, viewport: viewport.id, file: path.relative(repoRoot, screenshotPath) });

          if (viewport.id === 'desktop') {
            const axeResult = await new AxeBuilder({ page }).analyze();
            const seriousCount = axeResult.violations.filter((v) => ['serious', 'critical'].includes(v.impact)).length;
            const passed = seriousCount <= axeMaxSerious;
            if (!passed) accessibilityPassed = false;
            const axeFile = path.join(reportDir, `axe-${route.id}-${state.id}.json`);
            fs.writeFileSync(axeFile, JSON.stringify(axeResult, null, 2) + '\n');
            a11yResults.push({ route: route.id, state: state.id, seriousCount, passed, file: path.relative(repoRoot, axeFile) });
          }

          if (visualConfig.enabled) {
            ensureDir(baselineDir);
            const baselinePath = path.join(baselineDir, screenshotName);
            const diffPath = path.join(diffDir, screenshotName);
            const baselineMissing = !fileExists(baselinePath);
            if ((baselineMode === 'record' || baselineMode === 'update') || baselineMissing) {
              fs.copyFileSync(screenshotPath, baselinePath);
              visualResults.push({ route: route.id, state: state.id, viewport: viewport.id, baseline: path.relative(repoRoot, baselinePath), diffPixels: 0, passed: baselineMode !== 'compare' });
              if (baselineMode === 'compare' && baselineMissing) {
                visualRegressionPassed = false;
              }
            } else {
              const baseline = PNG.sync.read(fs.readFileSync(baselinePath));
              const current = PNG.sync.read(fs.readFileSync(screenshotPath));
              const { width, height } = baseline;
              const diff = new PNG({ width, height });
              const diffPixels = pixelmatch(baseline.data, current.data, diff.data, width, height, { threshold: 0.1 });
              fs.writeFileSync(diffPath, PNG.sync.write(diff));
              const passed = diffPixels === 0;
              if (!passed) visualRegressionPassed = false;
              visualResults.push({ route: route.id, state: state.id, viewport: viewport.id, baseline: path.relative(repoRoot, baselinePath), diff: path.relative(repoRoot, diffPath), diffPixels, passed });
            }
          }

          await context.close();
        }
      }
    }
  } finally {
    await browser.close();
  }

  const lighthouseResults = [];
  let performancePassed = true;
  for (const route of routes) {
    const chrome = await chromeLauncher.launch({ chromeFlags: ['--headless', '--no-sandbox'] });
    try {
      const result = await lighthouse(new URL(route.path, baseUrl).toString(), {
        port: chrome.port,
        output: 'json',
        logLevel: 'error'
      });
      const lhr = result.lhr;
      const scores = {
        performance: Math.round((lhr.categories.performance?.score || 0) * 100),
        accessibility: Math.round((lhr.categories.accessibility?.score || 0) * 100)
      };
      const passed = scores.performance >= lighthouseThresholds.performance && scores.accessibility >= lighthouseThresholds.accessibility;
      if (!passed) performancePassed = false;
      const reportFile = path.join(reportDir, `lighthouse-${route.id}.json`);
      fs.writeFileSync(reportFile, JSON.stringify(lhr, null, 2) + '\n');
      lighthouseResults.push({ route: route.id, ...scores, passed, file: path.relative(repoRoot, reportFile) });
    } finally {
      await chrome.kill();
    }
  }

  const summary = {
    generated_at: new Date().toISOString(),
    slice_id: sliceId,
    screenshot_count: screenshotEntries.length,
    routes: routes.map((route) => route.id),
    states: routes.flatMap((route) => normalizeStateEntries(route).map((state) => `${route.id}:${state.id}`)),
    accessibility_passed: accessibilityPassed,
    performance_passed: performancePassed,
    visual_regression_passed: visualRegressionPassed,
    screenshots: screenshotEntries,
    accessibility: a11yResults,
    lighthouse: lighthouseResults,
    visual_regression: visualResults,
    server_log: fileExists(serverLog) ? path.relative(repoRoot, serverLog) : null
  };

  fs.writeFileSync(path.join(reportDir, 'routes.json'), JSON.stringify(routes, null, 2) + '\n');
  fs.writeFileSync(path.join(reportDir, 'screenshots.json'), JSON.stringify(screenshotEntries, null, 2) + '\n');
  fs.writeFileSync(path.join(reportDir, 'accessibility-summary.json'), JSON.stringify(a11yResults, null, 2) + '\n');
  fs.writeFileSync(path.join(reportDir, 'lighthouse-summary.json'), JSON.stringify(lighthouseResults, null, 2) + '\n');
  fs.writeFileSync(path.join(reportDir, 'visual-regression-summary.json'), JSON.stringify(visualResults, null, 2) + '\n');
  fs.writeFileSync(path.join(reportDir, 'frontend-evidence-summary.json'), JSON.stringify(summary, null, 2) + '\n');

  const lines = [
    '# Frontend Evidence',
    '',
    `- slice_id: \`${sliceId}\``,
    `- screenshots: ${summary.screenshot_count}`,
    `- accessibility_passed: ${summary.accessibility_passed}`,
    `- performance_passed: ${summary.performance_passed}`,
    `- visual_regression_passed: ${summary.visual_regression_passed}`,
    '',
    '## Routes',
    ''
  ];
  for (const route of routes) {
    lines.push(`- ${route.id}: ${route.path}`);
  }
  lines.push('', '## States', '');
  for (const entry of summary.states) {
    lines.push(`- ${entry}`);
  }
  fs.writeFileSync(path.join(reportDir, 'frontend-evidence.md'), `${lines.join('\n')}\n`);

  if (!accessibilityPassed || !performancePassed || !visualRegressionPassed) {
    process.exitCode = 1;
  }

  if (serverProcess) {
    serverProcess.kill('SIGTERM');
  }
}

main().catch((error) => {
  console.error(error.stack || error.message);
  process.exitCode = 1;
});
