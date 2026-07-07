#!/usr/bin/env node
import { access, readFile, readdir } from 'node:fs/promises';
import { basename, join } from 'node:path';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, 'utf8'));
}

async function fileExists(filePath) {
  await access(filePath);
}

async function listSourceFiles() {
  const entries = await readdir('legacy/node/src', { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.mjs'))
    .map((entry) => join('legacy', 'node', 'src', entry.name).replaceAll('\\', '/'))
    .sort();
}

async function listDocFiles() {
  const entries = await readdir('docs', { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
    .map((entry) => join('docs', entry.name).replaceAll('\\', '/'))
    .sort();
}

function waitAfter(sequence, label) {
  const index = sequence.findIndex((step) => step.type === 'tap' && step.label === label);
  if (index < 0) {
    return null;
  }
  const nextStep = sequence[index + 1];
  return nextStep?.type === 'wait' ? nextStep.ms : null;
}

async function assertDocsExist() {
  const requiredDocs = [
    'README.md',
    'AI_PROJECT_CONTEXT.md',
    'AGENTS.md',
    'docs/README.md',
    'docs/iOS Assist Studio项目文档v1.0.md',
    'docs/产品与工程边界v1.0.md',
    'docs/三阶段开发计划v1.0.md',
    'docs/Web控制台UIUX规范v1.0.md',
    'docs/产品定位与旗舰化方向v1.0.md',
    'docs/视觉状态驱动编排架构路线v1.0.md',
  ];

  await Promise.all(requiredDocs.map(fileExists));

  const readme = await readFile('README.md', 'utf8');
  assert(readme.includes('docs/README.md'), 'README should point to the docs index');
  assert(readme.includes('AI_PROJECT_CONTEXT.md'), 'README should point to the AI project context');

  const docsIndex = await readFile('docs/README.md', 'utf8');
  assert(docsIndex.includes('Task Router'), 'Docs index should keep the task router');
  assert(docsIndex.includes('Source of Truth'), 'Docs index should identify source-of-truth documents');

  const projectDoc = await readFile('docs/iOS Assist Studio项目文档v1.0.md', 'utf8');
  assert(projectDoc.includes('config/connected-device.sequence.json'), 'Project doc should identify connected config as runtime truth');
  assert(projectDoc.includes('ABCDEF -> ABCDEF'), 'Project doc should preserve serial loop semantics');

  const boundaryDoc = await readFile('docs/产品与工程边界v1.0.md', 'utf8');
  assert(boundaryDoc.includes('fire-and-forget'), 'Boundary doc should describe evidence queue ordering');
  assert(boundaryDoc.includes('Flutter Desktop'), 'Boundary doc should identify the current V2 product entry');
}

async function assertConnectedSequence() {
  const config = await readJson('config/connected-device.sequence.json');
  const sequence = config.sequence ?? [];
  const tapLabels = sequence
    .filter((step) => step.type === 'tap')
    .map((step) => step.label);

  assert(JSON.stringify(tapLabels) === JSON.stringify(['A', 'B', 'C', 'D', 'E', 'F']), 'Connected sequence should contain A-F taps in order');
  assert(waitAfter(sequence, 'A') === 50, 'A wait should be 50ms');
  assert(waitAfter(sequence, 'B') === 50, 'B wait should be 50ms');
  assert(waitAfter(sequence, 'C') === 50, 'C wait should be 50ms');
  assert(waitAfter(sequence, 'D') === 4000, 'D wait should be 4000ms');
  assert(waitAfter(sequence, 'E') === 50, 'E wait should be 50ms');
  assert(waitAfter(sequence, 'F') === null, 'F should not have a wait after it');
  assert(config.run?.tapDurationMs === 80, 'Connected run tapDurationMs should stay at 80ms');
  assert(config.run?.stopOnError !== false, 'Connected run should stop on error by default');
  assert(config.appium?.requireInitBeforeClick === true, 'Connected CLI click should require init first');
}

async function assertScriptCoverage() {
  const pkg = await readJson('package.json');
  const scripts = pkg.scripts ?? {};
  const sourceFiles = await listSourceFiles();
  const migratedSmokeFiles = new Set([
    'ios-assist-macos-build-smoke.mjs',
    'ios-assist-v2-boundary-smoke.mjs',
  ]);
  const smokeFiles = sourceFiles
    .filter((filePath) => filePath.endsWith('-smoke.mjs'))
    .filter((filePath) => !migratedSmokeFiles.has(basename(filePath)));
  const clickSource = await readFile('legacy/node/src/ios-coordinate-click.mjs', 'utf8');

  assert(!scripts['init:connected'], 'init:connected should not remain a primary script after Node archive');
  assert(!scripts['console:connected'], 'console:connected should not remain a primary script after Node archive');
  assert(!scripts['click:connected'], 'click:connected should not remain a primary script after Node archive');
  assert(scripts.check === 'fvm dart run tool/v2_boundary_check.dart', 'check should use the V2 Dart boundary check');
  assert(scripts['verify:all'] === 'fvm dart run tool/v2_verify.dart', 'verify:all should use the V2 Dart verifier');
  assert(scripts['smoke:v2-boundary'] === 'fvm dart run tool/v2_boundary_check.dart', 'V2 boundary smoke should use Dart');
  assert(scripts['smoke:macos-build'] === 'fvm dart run tool/macos_build_smoke.dart', 'macOS build smoke should use Dart');

  assert(scripts['legacy:init:connected'] === 'node legacy/node/src/ios-coordinate-init.mjs --config config/connected-device.sequence.json', 'legacy:init:connected should initialize the connected config');
  assert(scripts['legacy:console:connected'] === 'node legacy/node/src/ios-assist-console.mjs --config config/connected-device.sequence.json', 'legacy:console:connected should remain the archived Web console entry');
  assert(scripts['legacy:click:connected'] === 'node legacy/node/src/ios-coordinate-click.mjs --config config/connected-device.sequence.json --start-appium', 'legacy:click:connected should remain the archived CLI compatibility entry with explicit Appium startup');
  assert(scripts['legacy:dry-run:connected'] === 'node legacy/node/src/ios-coordinate-click.mjs --config config/connected-device.sequence.json --dry-run --loops 1', 'legacy:dry-run:connected should validate the connected config without starting Appium');
  assert(!scripts['legacy:dry-run:connected'].includes('--start-appium'), 'legacy:dry-run:connected must not start Appium');
  assert(scripts['legacy:validate:connected'] === 'node legacy/node/src/ios-assist-validate.mjs --config config/connected-device.sequence.json', 'legacy:validate:connected should validate the connected config offline');
  assert(scripts['legacy:check'] === 'node legacy/node/src/ios-assist-legacy-check.mjs', 'legacy:check should use the archived Node checker');
  assert(scripts['legacy:verify']?.includes('npm run legacy:check'), 'legacy:verify should include legacy:check');
  assert(scripts['legacy:verify']?.includes('npm run legacy:smoke:acceptance'), 'legacy:verify should include acceptance smoke');

  const initIndex = clickSource.indexOf('assertInitializedForClick(config, options);');
  const preflightIndex = clickSource.indexOf('await preflightRealDevice(config, options);');
  const appiumIndex = clickSource.indexOf('appiumProcess = await ensureAppium');
  assert(initIndex >= 0 && preflightIndex >= 0 && appiumIndex >= 0, 'click runner should keep init, preflight and Appium startup guards');
  assert(initIndex < appiumIndex, 'click runner must check init before starting Appium');
  assert(preflightIndex < appiumIndex, 'click runner must check connected device before starting Appium');
  assert(clickSource.includes('if (options.dryRun || config.appium?.requireInitBeforeClick !== true)'), 'dry-run should bypass the connected init gate');

  for (const filePath of sourceFiles) {
    assert(sourceFiles.includes(filePath), `${filePath} should be discoverable by legacy:check`);
  }

  for (const filePath of smokeFiles) {
    const scriptEntry = Object.entries(scripts)
      .find(([name, value]) => name.startsWith('legacy:smoke:') && value === `node ${filePath}`);
    assert(scriptEntry, `${filePath} should have an npm smoke script`);
    assert(scripts['legacy:verify'].includes(`npm run ${scriptEntry[0]}`), `${scriptEntry[0]} should be included in legacy:verify`);
  }
}

async function assertPublicTextPrivacy() {
  const docFiles = await listDocFiles();
  const sourceFiles = await listSourceFiles();
  const files = [
    'README.md',
    'AI_PROJECT_CONTEXT.md',
    'AGENTS.md',
    ...docFiles,
    ...sourceFiles,
  ];
  const certificateWordA = ['Hang', 'zhou'].join('');
  const certificateWordB = ['Xi', 'teng'].join('');
  const accountLikeWord = ['4027', '69411'].join('');
  const forbidden = [
    [/\/Users\//, 'local absolute user path'],
    [new RegExp(certificateWordA, 'i'), 'certificate organization name'],
    [new RegExp(certificateWordB, 'i'), 'certificate organization name'],
    [new RegExp(accountLikeWord), 'account identifier'],
    [/\b[0-9A-Fa-f]{24,40}\b/, 'full unhyphenated device identifier'],
  ];

  for (const filePath of files) {
    const text = await readFile(filePath, 'utf8');
    for (const [pattern, label] of forbidden) {
      assert(!pattern.test(text), `${filePath} should not contain ${label}`);
    }
  }
}

async function main() {
  await assertDocsExist();
  await assertConnectedSequence();
  await assertScriptCoverage();
  await assertPublicTextPrivacy();
  console.log('Acceptance smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
