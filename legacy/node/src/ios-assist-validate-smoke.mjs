#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { mkdtemp, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function runValidate(configPath) {
  return new Promise((resolveRun) => {
    const child = spawn(process.execPath, [
      'legacy/node/src/ios-assist-validate.mjs',
      '--config',
      configPath,
      '--json',
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

async function main() {
  const tempDir = await mkdtemp(join(tmpdir(), 'ios-assist-validate-'));
  const configPath = join(tempDir, 'branching.sequence.json');
  await writeFile(configPath, JSON.stringify({
    appium: {
      capabilities: {
        'appium:automationName': 'XCUITest',
      },
    },
    run: {
      loops: 1,
      tapDurationMs: 1,
    },
    workflow: {
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
    },
  }, null, 2), 'utf8');

  const result = await runValidate(configPath);
  assert(result.code === 0, `Branching workflow should validate offline: ${result.stderr}`);
  const payload = JSON.parse(result.stdout);
  assert(payload.ok === true, 'Branching workflow validation should return ok=true');
  assert(payload.workflow?.linear === false, 'Branching workflow should be reported as non-linear');
  assert(payload.workflow?.nodeCount === 3, 'Branching workflow should report node count');
  console.log('Validate smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
