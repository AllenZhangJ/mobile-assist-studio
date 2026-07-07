#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import process from 'node:process';

const LEGACY_TOOL_FILES = [
  'legacy/node/src/ios-coordinate-init.mjs',
  'legacy/node/src/ios-coordinate-record.mjs',
  'legacy/node/src/ios-coordinate-record-server.mjs',
  'legacy/node/src/ios-coordinate-pick-point.mjs',
];

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function runHelp(script) {
  return new Promise((resolveHelp, rejectHelp) => {
    const child = spawn(process.execPath, [script, '--help'], {
      cwd: process.cwd(),
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let output = '';
    const timeout = setTimeout(() => {
      child.kill('SIGKILL');
      rejectHelp(new Error(`${script} --help timed out`));
    }, 3000);

    child.stdout.on('data', (chunk) => {
      output += chunk.toString();
    });
    child.stderr.on('data', (chunk) => {
      output += chunk.toString();
    });
    child.once('exit', (code) => {
      clearTimeout(timeout);
      if (code === 0) {
        resolveHelp(output);
        return;
      }
      rejectHelp(new Error(`${script} --help exited with code ${code}\n${output}`));
    });
  });
}

async function assertFileContains(filePath, checks) {
  const source = await readFile(filePath, 'utf8');
  for (const [pattern, message] of checks) {
    assert(pattern.test(source), message);
  }
}

async function main() {
  for (const filePath of LEGACY_TOOL_FILES) {
    const output = await runHelp(filePath);
    assert(/Usage:/i.test(output), `${filePath} should print help usage`);
  }

  await assertFileContains('legacy/node/src/ios-coordinate-init.mjs', [
    [/function writeJsonAtomic/, 'init should use atomic config writes'],
    [/Initialized connected config: \$\{options\.config\}/, 'init should print the requested config path, not an absolute path'],
    [/summarizeIdentifier\(selected\.udid\)/, 'init should summarize selected device identifiers in logs'],
  ]);

  await assertFileContains('legacy/node/src/ios-coordinate-record.mjs', [
    [/displayCommand/, 'HTML recorder should avoid logging the default absolute Appium binary path'],
    [/function publicPath/, 'HTML recorder should avoid printing absolute output paths'],
    [/Recorder written to: \$\{publicPath\(outputPath\)\}/, 'HTML recorder should print a safe output path'],
    [/new AbortController\(\)/, 'HTML recorder should bound Appium status probes'],
    [/fetch\(appiumStatusUrl\(appium\), \{ signal: controller\.signal \}\)/, 'HTML recorder should pass an abort signal to Appium status fetch'],
    [/const SCREENSHOT_CAPTURE_TIMEOUT_MS = 10_000/, 'HTML recorder should bound screenshot capture time'],
    [/const WINDOW_RECT_TIMEOUT_MS = 5_000/, 'HTML recorder should bound viewport capture time'],
    [/withTimeout\(\s*driver\.takeScreenshot\(\)/, 'HTML recorder should not call takeScreenshot without a timeout'],
    [/withTimeout\(\s*driver\.getWindowRect\(\)/, 'HTML recorder should not call getWindowRect without a timeout'],
  ]);

  for (const filePath of [
    'legacy/node/src/ios-coordinate-record-server.mjs',
    'legacy/node/src/ios-coordinate-pick-point.mjs',
  ]) {
    await assertFileContains(filePath, [
      [/const MAX_BODY_BYTES = 64 \* 1024/, `${filePath} should cap request body size`],
      [/function writeJsonAtomic/, `${filePath} should use atomic config writes`],
      [/server\.requestTimeout = HTTP_REQUEST_TIMEOUT_MS/, `${filePath} should set request timeout`],
      [/server\.headersTimeout = HTTP_HEADERS_TIMEOUT_MS/, `${filePath} should set headers timeout`],
      [/server\.keepAliveTimeout = HTTP_KEEP_ALIVE_TIMEOUT_MS/, `${filePath} should set keep-alive timeout`],
      [/server\.closeAllConnections\?\.\(\)/, `${filePath} should force-close lingering connections during shutdown`],
      [/async function parseJsonBody/, `${filePath} should map malformed JSON bodies to a client error`],
      [/Request body must be valid JSON/, `${filePath} should return an actionable malformed JSON error`],
      [/\{ statusCode: 400 \}/, `${filePath} should return 400 for malformed JSON bodies`],
      [/new AbortController\(\)/, `${filePath} should bound Appium status probes`],
      [/fetch\(appiumStatusUrl\(appium\), \{ signal: controller\.signal \}\)/, `${filePath} should pass an abort signal to Appium status fetch`],
      [/const SCREENSHOT_CAPTURE_TIMEOUT_MS = 10_000/, `${filePath} should bound screenshot capture time`],
      [/const WINDOW_RECT_TIMEOUT_MS = 5_000/, `${filePath} should bound viewport capture time`],
      [/withTimeout\(\s*driver\.takeScreenshot\(\)/, `${filePath} should not call takeScreenshot without a timeout`],
      [/withTimeout\(\s*driver\.getWindowRect\(\)/, `${filePath} should not call getWindowRect without a timeout`],
      [/displayCommand/, `${filePath} should avoid logging the default absolute Appium binary path`],
    ]);
  }

  console.log('Legacy tool smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
