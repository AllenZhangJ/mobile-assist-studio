#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { mkdtemp, readFile, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function runClick(configPath) {
  return new Promise((resolveRun) => {
    const child = spawn(process.execPath, [
      'legacy/node/src/ios-coordinate-click.mjs',
      '--config',
      configPath,
      '--dry-run',
      '--log-level',
      'verbose',
    ], {
      cwd: process.cwd(),
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    child.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });
    child.once('exit', (code) => resolveRun({ code, stdout, stderr }));
  });
}

function baseConfig(workflow) {
  return {
    appium: {
      capabilities: {
        'appium:automationName': 'XCUITest',
      },
    },
    run: {
      loops: 1,
      tapDurationMs: 1,
    },
    sequence: [
      { type: 'tap', label: 'legacy', x: 9, y: 9 },
    ],
    workflow,
  };
}

async function main() {
  const clickSource = await readFile('legacy/node/src/ios-coordinate-click.mjs', 'utf8');
  assert(clickSource.includes('const DELETE_SESSION_TIMEOUT_MS = 5000'), 'Click CLI should bound Appium session deletion');
  assert(clickSource.includes('const ACTION_RELEASE_TIMEOUT_MS = 3000'), 'Click CLI should bound pointer release');
  assert(clickSource.includes('Appium session delete timed out after'), 'Click CLI should report deleteSession timeout');
  assert(clickSource.includes('Pointer action release timed out after'), 'Click CLI should report releaseActions timeout');
  assert(clickSource.includes('new AbortController()'), 'Click CLI should bound Appium status probes');
  assert(clickSource.includes('fetch(appiumStatusUrl(appium), { signal: controller.signal })'), 'Click CLI should pass an abort signal to Appium status fetch');
  assert(
    /withTimeout\(\s*driver\.deleteSession\(\)/.test(clickSource),
    'Click CLI should not call deleteSession without a timeout'
  );
  assert(
    /withTimeout\(\s*driver\.releaseActions\(\)/.test(clickSource),
    'Click CLI should not call releaseActions without a timeout'
  );

  const tempDir = await mkdtemp(join(tmpdir(), 'ios-click-smoke-'));
  const linearPath = join(tempDir, 'linear.json');
  await writeFile(linearPath, JSON.stringify(baseConfig({
    version: 1,
    id: 'linear',
    entry: 'tapA',
    nodes: [
      { id: 'tapA', type: 'Tap', params: { label: 'workflow', x: 1, y: 2 }, next: 'waitA' },
      { id: 'waitA', type: 'Wait', params: { ms: 1 } },
    ],
  }), null, 2), 'utf8');

  const linear = await runClick(linearPath);
  assert(linear.code === 0, `Linear workflow dry-run should pass: ${linear.stderr}`);
  assert(linear.stdout.includes('Dry run: Appium session will not be opened.'), 'Dry-run should not open an Appium session');
  assert(linear.stdout.includes('taps=1'), 'Linear workflow dry-run should report one workflow tap');
  assert(linear.stdout.includes('workflow'), 'Linear workflow dry-run should use workflow over legacy sequence');
  assert(!linear.stdout.includes('legacy'), 'Linear workflow dry-run should not fall back to legacy sequence');

  const branchingPath = join(tempDir, 'branching.json');
  await writeFile(branchingPath, JSON.stringify(baseConfig({
    version: 1,
    id: 'branching',
    entry: 'branch',
    nodes: [
      {
        id: 'branch',
        type: 'If_Else',
        condition: { op: 'equals', left: 'context.loopNumber', right: 1 },
        trueNext: 'tapA',
        falseNext: 'tapB',
      },
      { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2 } },
      { id: 'tapB', type: 'Tap', params: { label: 'B', x: 3, y: 4 } },
    ],
  }), null, 2), 'utf8');

  const branching = await runClick(branchingPath);
  assert(branching.code !== 0, 'Graph workflow should be rejected by CLI click runner');
  assert(
    branching.stderr.includes('Web console runner'),
    'Graph workflow error should point users to the Web console runner'
  );

  console.log('Click CLI smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
