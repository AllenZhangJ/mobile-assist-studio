import { spawn } from 'node:child_process';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import process from 'node:process';
import { classifyConnectionError } from './ios-assist-session.mjs';
import { resolveExecutableSequence } from './ios-assist-workflow.mjs';

const DEFAULT_CONFIG = 'config/example.sequence.json';
const DEFAULT_BATCH_TARGET_LOOPS = 10;
const DEFAULT_BATCH_MAX_REQUESTS = 20;
const DELETE_SESSION_TIMEOUT_MS = 5000;
const ACTION_RELEASE_TIMEOUT_MS = 3000;
const LOG_LEVEL_RANK = {
  summary: 0,
  progress: 1,
  verbose: 2,
};

function readOptionValue(argv, index, name) {
  const value = argv[index + 1];
  if (!value || value.startsWith('--')) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function parseLoopCount(value, name) {
  const text = String(value);
  const normalized = text.startsWith('-') ? text.slice(1) : text;
  const loops = Number(normalized);
  if (!Number.isInteger(loops) || loops < 1) {
    throw new Error(`${name} requires a positive integer`);
  }
  return loops;
}

function parsePositiveInteger(value, name) {
  const number = Number(value);
  if (!Number.isInteger(number) || number < 1) {
    throw new Error(`${name} requires a positive integer`);
  }
  return number;
}

function parseBoundedPositiveInteger(value, name, max) {
  const number = parsePositiveInteger(value, name);
  if (number > max) {
    throw new Error(`${name} must be <= ${max}`);
  }
  return number;
}

function parseChoice(value, name, choices) {
  if (!choices.includes(value)) {
    throw new Error(`${name} must be one of: ${choices.join(', ')}`);
  }
  return value;
}

function parseArgs(argv) {
  const options = {
    config: DEFAULT_CONFIG,
    dryRun: false,
    startAppium: false,
    loopOverride: false,
    mode: 'step',
    tapMethod: 'pointer',
    quiet: false,
    logLevel: 'progress',
    skipDeviceCheck: false,
    batchTargetLoops: DEFAULT_BATCH_TARGET_LOOPS,
    batchMaxRequests: DEFAULT_BATCH_MAX_REQUESTS,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--dry-run') {
      options.dryRun = true;
      continue;
    }

    if (arg === '--start-appium') {
      options.startAppium = true;
      continue;
    }

    if (arg === '--quiet') {
      options.quiet = true;
      options.logLevel = 'summary';
      continue;
    }

    if (arg === '--skip-device-check') {
      options.skipDeviceCheck = true;
      continue;
    }

    if (arg === '--loops') {
      options.loops = parseLoopCount(readOptionValue(argv, index, '--loops'), '--loops');
      options.loopOverride = true;
      index += 1;
      continue;
    }

    if (arg === '--mode') {
      options.mode = parseChoice(readOptionValue(argv, index, '--mode'), '--mode', ['step', 'batch']);
      index += 1;
      continue;
    }

    if (arg === '--tap-method') {
      options.tapMethod = parseChoice(
        readOptionValue(argv, index, '--tap-method'),
        '--tap-method',
        ['pointer', 'mobile']
      );
      index += 1;
      continue;
    }

    if (arg === '--log-level') {
      options.logLevel = parseChoice(
        readOptionValue(argv, index, '--log-level'),
        '--log-level',
        ['summary', 'progress', 'verbose']
      );
      options.quiet = options.logLevel === 'summary';
      index += 1;
      continue;
    }

    if (arg === '--batch-target-loops') {
      options.batchTargetLoops = parsePositiveInteger(
        readOptionValue(argv, index, '--batch-target-loops'),
        '--batch-target-loops'
      );
      index += 1;
      continue;
    }

    if (arg === '--batch-max-requests') {
      options.batchMaxRequests = parseBoundedPositiveInteger(
        readOptionValue(argv, index, '--batch-max-requests'),
        '--batch-max-requests',
        DEFAULT_BATCH_MAX_REQUESTS
      );
      index += 1;
      continue;
    }

    if (arg === '--config') {
      options.config = readOptionValue(argv, index, '--config');
      index += 1;
      continue;
    }

    if (arg === '--help' || arg === '-h') {
      options.help = true;
      continue;
    }

    if (/^-?\d+$/.test(arg)) {
      options.loops = parseLoopCount(arg, 'loop shorthand');
      options.loopOverride = true;
      continue;
    }

    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function printHelp() {
  console.log(`
Usage:
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json --start-appium
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json --dry-run
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json --loops 1
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json 10
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json -10
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json 100 --mode batch --log-level summary
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json 10 --tap-method mobile
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json 10 --log-level verbose
  node legacy/node/src/ios-coordinate-click.mjs --config config/example.sequence.json 10 --skip-device-check

Sequence step types:
  { "type": "tap", "x": 320, "y": 680, "label": "optional" }
  { "type": "wait", "ms": 1200 }
  { "type": "waitRandom", "minMs": 50, "maxMs": 120 }
`);
}

async function loadConfig(configPath) {
  const absolutePath = resolve(process.cwd(), configPath);
  const contents = await readFile(absolutePath, 'utf8');
  const config = JSON.parse(contents);

  if (!config.appium?.capabilities) {
    throw new Error('Config must include appium.capabilities');
  }

  try {
    config.sequence = resolveExecutableSequence(config);
  } catch (error) {
    if (config.workflow) {
      throw new Error(`CLI click runner can only execute linear Tap/Wait workflows. Use the Web console runner for graph workflows. ${error.message}`);
    }
    throw error;
  }
  validateSequence(config.sequence);

  return config;
}

function sleep(ms) {
  return new Promise((resolveSleep) => {
    setTimeout(resolveSleep, ms);
  });
}

async function withTimeout(promise, timeoutMs, message) {
  let timeout;
  try {
    return await Promise.race([
      Promise.resolve(promise),
      new Promise((_, reject) => {
        timeout = setTimeout(() => reject(new Error(message)), timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timeout);
  }
}

function numberOrDefault(value, fallback) {
  return Number.isFinite(value) ? value : fallback;
}

function capabilityValue(capabilities, name) {
  return capabilities?.[`appium:${name}`] ?? capabilities?.[name];
}

function summarizeIdentifier(value) {
  const text = String(value ?? '');
  if (text.length <= 10) {
    return text;
  }
  return `${text.slice(0, 6)}...${text.slice(-4)}`;
}

function summarizeCommand(command) {
  const text = String(command ?? '');
  const workspacePrefix = `${process.cwd()}/`;
  if (text.startsWith(workspacePrefix)) {
    return text.slice(workspacePrefix.length);
  }
  return text.replace(/\/Users\/[^ ]+/g, '[path]').replace(/\/private\/[^ ]+/g, '[path]');
}

function shouldLog(options, level) {
  return LOG_LEVEL_RANK[options.logLevel] >= LOG_LEVEL_RANK[level];
}

function logAt(options, level, message) {
  if (shouldLog(options, level)) {
    console.log(message);
  }
}

function shouldPreflightRealDevice(config, options) {
  if (options.skipDeviceCheck || options.dryRun) {
    return false;
  }

  const capabilities = config.appium?.capabilities;
  const platformName = String(capabilities?.platformName ?? '').toLowerCase();
  const automationName = String(capabilityValue(capabilities, 'automationName') ?? '').toLowerCase();
  const udid = capabilityValue(capabilities, 'udid');
  const wdaUrl = capabilityValue(capabilities, 'webDriverAgentUrl');

  return platformName === 'ios'
    && automationName === 'xcuitest'
    && Boolean(udid)
    && String(udid).toLowerCase() !== 'auto'
    && !wdaUrl;
}

function assertInitializedForClick(config, options) {
  if (options.dryRun || config.appium?.requireInitBeforeClick !== true) {
    return;
  }

  const expectedUdid = String(capabilityValue(config.appium.capabilities, 'udid') ?? '');
  const lastInit = config.appium.lastInit;

  if (!lastInit?.selectedUdid || !lastInit?.initializedAt) {
    throw new Error(`
This connected config has not been initialized.

Run first:
  npm run legacy:init:connected

Then run:
  npm run legacy:click:connected 1 -- --log-level progress
`);
  }

  if (lastInit.selectedUdid !== expectedUdid) {
    throw new Error(`
Connected config initialization does not match the configured UDID.

Configured UDID:
  ${summarizeIdentifier(expectedUdid)}

Last initialized UDID:
  ${summarizeIdentifier(lastInit.selectedUdid)}

Run first:
  npm run legacy:init:connected
`);
  }
}

async function preflightRealDevice(config, options) {
  if (!shouldPreflightRealDevice(config, options)) {
    return;
  }

  const expectedUdid = String(capabilityValue(config.appium.capabilities, 'udid'));
  let connectedDevices = [];

  try {
    const { getConnectedDevices } = await import(
      'appium-xcuitest-driver/node_modules/appium-ios-device/build/lib/utilities.js'
    );
    connectedDevices = await getConnectedDevices();
  } catch (error) {
    throw new Error(`Unable to check connected iOS devices through Appium usbmux: ${error.message}`);
  }

  if (connectedDevices.includes(expectedUdid)) {
    logAt(options, 'progress', `Device ready: ${summarizeIdentifier(expectedUdid)}`);
    return;
  }

  const foundText = connectedDevices.length > 0
    ? connectedDevices.map((device) => summarizeIdentifier(device)).join(', ')
    : 'none';
  throw new Error(`
Appium cannot see the configured iPhone through usbmux.

Configured UDID:
  ${summarizeIdentifier(expectedUdid)}

Appium/usbmux connected devices:
  ${foundText}

Fix:
  1. Connect the iPhone with a USB cable, not only Wi-Fi/CoreDevice.
  2. Unlock the iPhone and keep it unlocked.
  3. If "Trust This Computer" appears, tap Trust.
  4. Run: idevice_id -l
  5. It should print ${expectedUdid}. Then run the click command again.

Note:
  xcrun devicectl may show a CoreDevice identifier even when Appium/usbmux cannot use the phone.
`);
}

function formatDuration(ms) {
  if (ms < 1000) {
    return `${ms}ms`;
  }

  const seconds = ms / 1000;
  if (seconds < 60) {
    return `${seconds.toFixed(1)}s`;
  }

  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = Math.round(seconds % 60);
  return `${minutes}m ${remainingSeconds}s`;
}

function sequenceSummary(config) {
  const run = config.run ?? {};
  const tapCount = config.sequence.filter((step) => step.type === 'tap').length;
  const fixedWaitCounts = new Map();
  const randomWaitCounts = new Map();
  for (const step of config.sequence) {
    if (step.type === 'wait') {
      const key = `${step.ms}ms`;
      fixedWaitCounts.set(key, (fixedWaitCounts.get(key) ?? 0) + 1);
    }
    if (step.type === 'waitRandom') {
      const key = `${step.minMs}-${step.maxMs}ms`;
      randomWaitCounts.set(key, (randomWaitCounts.get(key) ?? 0) + 1);
    }
  }
  const fixedWaits = [...fixedWaitCounts.entries()].map(([value, count]) => `${value} x${count}`);
  const randomWaits = [...randomWaitCounts.entries()].map(([value, count]) => `${value} x${count}`);
  const fixedText = fixedWaits.length > 0 ? `fixedWaits=${fixedWaits.join(', ')}` : 'fixedWaits=none';
  const randomText = randomWaits.length > 0 ? `randomWaits=${randomWaits.join(', ')}` : 'randomWaits=none';
  return `taps=${tapCount}, tapDuration=${numberOrDefault(run.tapDurationMs, 80)}ms, ${fixedText}, ${randomText}`;
}

function progressInterval(total) {
  if (total <= 20) {
    return 1;
  }

  return Math.max(1, Math.ceil(total / 10));
}

function shouldLogProgress(index, total) {
  return index === 0 || index === total - 1 || (index + 1) % progressInterval(total) === 0;
}

function normalizeBasePath(path) {
  if (!path || path === '/') {
    return '';
  }

  return path.startsWith('/') ? path : `/${path}`;
}

function appiumStatusUrl(appium) {
  const hostname = appium.hostname ?? '127.0.0.1';
  const port = appium.port ?? 4723;
  const basePath = normalizeBasePath(appium.path);
  return `http://${hostname}:${port}${basePath}/status`;
}

async function isAppiumReady(appium, { timeoutMs = 1500 } = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(appiumStatusUrl(appium), { signal: controller.signal });
    if (!response.ok) {
      return false;
    }

    const body = await response.json();
    return body?.value?.ready === true;
  } catch {
    return false;
  } finally {
    clearTimeout(timeout);
  }
}

function prefixOutput(prefix, chunk, stream) {
  const lines = chunk.toString().split(/\r?\n/);
  for (const line of lines) {
    if (line.length > 0) {
      stream.write(`${prefix}${line}\n`);
    }
  }
}

function startAppiumServer(appium) {
  const hostname = appium.hostname ?? '127.0.0.1';
  const port = String(appium.port ?? 4723);
  const command = appium.command ?? resolve(process.cwd(), 'node_modules/.bin/appium');
  const args = appium.args ?? [
    '--address',
    hostname,
    '--port',
    port,
    '--log-level',
    appium.serverLogLevel ?? 'error',
  ];

  console.log(`Starting Appium: ${summarizeCommand(command)} ${args.join(' ')}`);
  const child = spawn(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  if (appium.forwardLogs === true) {
    child.stdout.on('data', (chunk) => prefixOutput('[appium] ', chunk, process.stdout));
    child.stderr.on('data', (chunk) => prefixOutput('[appium] ', chunk, process.stderr));
  }

  return child;
}

async function waitForStartedAppiumReady(appium, child, timeoutMs) {
  let childFailure;
  const onError = (error) => {
    childFailure = error;
  };
  const onExit = (code, signal) => {
    childFailure = new Error(
      signal
        ? `Appium exited before becoming ready with signal ${signal}`
        : `Appium exited before becoming ready with code ${code}`
    );
  };

  child.once('error', onError);
  child.once('exit', onExit);

  try {
    const startedAt = Date.now();
    while (Date.now() - startedAt < timeoutMs) {
      if (childFailure) {
        throw childFailure;
      }

      if (await isAppiumReady(appium)) {
        console.log(`Appium is ready: ${appiumStatusUrl(appium)}`);
        return;
      }

      await sleep(500);
    }
  } finally {
    child.off('error', onError);
    child.off('exit', onExit);
  }

  throw new Error(`Appium did not become ready within ${timeoutMs}ms`);
}

async function ensureAppium(appium, startAppium) {
  if (await isAppiumReady(appium)) {
    console.log(`Using existing Appium server: ${appiumStatusUrl(appium)}`);
    return null;
  }

  if (!startAppium) {
    throw new Error(
      `Appium is not running at ${appiumStatusUrl(appium)}. Start it with npm run appium, or use --start-appium.`
    );
  }

  const child = startAppiumServer(appium);
  try {
    await waitForStartedAppiumReady(appium, child, numberOrDefault(appium.startupTimeoutMs, 60000));
    return child;
  } catch (error) {
    await stopAppiumServer(child);
    throw error;
  }
}

async function stopAppiumServer(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) {
    return;
  }

  child.kill('SIGTERM');
  const exited = await Promise.race([
    new Promise((resolveStop) => child.once('exit', () => resolveStop(true))),
    sleep(3000).then(() => false),
  ]);

  if (!exited && child.exitCode === null && child.signalCode === null) {
    child.kill('SIGKILL');
    await Promise.race([
      new Promise((resolveStop) => child.once('exit', resolveStop)),
      sleep(1000),
    ]);
  }
}

function assertTapStep(step, index) {
  if (!Number.isFinite(step.x) || !Number.isFinite(step.y) || step.x < 0 || step.y < 0) {
    throw new Error(`Tap step ${index + 1} requires non-negative numeric x and y`);
  }
}

function assertWaitStep(step, index) {
  if (!Number.isFinite(step.ms) || step.ms < 0) {
    throw new Error(`Wait step ${index + 1} requires a non-negative ms value`);
  }
}

function assertWaitRandomStep(step, index) {
  if (
    !Number.isInteger(step.minMs)
    || !Number.isInteger(step.maxMs)
    || step.minMs < 0
    || step.maxMs < step.minMs
  ) {
    throw new Error(`Random wait step ${index + 1} requires integer minMs/maxMs with 0 <= minMs <= maxMs`);
  }
}

function validateSequence(sequence) {
  for (let stepIndex = 0; stepIndex < sequence.length; stepIndex += 1) {
    const step = sequence[stepIndex];
    if (step.type === 'tap') {
      assertTapStep(step, stepIndex);
      continue;
    }

    if (step.type === 'wait') {
      assertWaitStep(step, stepIndex);
      continue;
    }

    if (step.type === 'waitRandom') {
      assertWaitRandomStep(step, stepIndex);
      continue;
    }

    throw new Error(`Unsupported step type at sequence[${stepIndex}]: ${step.type}`);
  }
}

async function cleanupResources({ driver, appiumProcess }) {
  if (driver) {
    try {
      await withTimeout(
        driver.deleteSession(),
        DELETE_SESSION_TIMEOUT_MS,
        `Appium session delete timed out after ${DELETE_SESSION_TIMEOUT_MS}ms`
      );
    } catch (error) {
      console.error(`Failed to delete Appium session: ${error.message}`);
    }
  }

  try {
    await stopAppiumServer(appiumProcess);
  } catch (error) {
    console.error(`Failed to stop Appium: ${error.message}`);
  }
}

function randomIntegerInclusive(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function resolveWaitMs(step) {
  if (step.type === 'wait') {
    return step.ms;
  }

  return randomIntegerInclusive(step.minMs, step.maxMs);
}

function tapActions(step, tapDurationMs) {
  return [
    { type: 'pointerMove', duration: 0, x: step.x, y: step.y },
    { type: 'pointerDown', button: 0 },
    { type: 'pause', duration: tapDurationMs },
    { type: 'pointerUp', button: 0 },
  ];
}

async function performPointerTap(driver, step, tapDurationMs) {
  let actionError = null;
  try {
    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: tapActions(step, tapDurationMs),
      },
    ]);
  } catch (error) {
    actionError = error;
  }

  try {
    await withTimeout(
      driver.releaseActions(),
      ACTION_RELEASE_TIMEOUT_MS,
      `Pointer action release timed out after ${ACTION_RELEASE_TIMEOUT_MS}ms`
    );
  } catch (releaseError) {
    if (!actionError) {
      throw releaseError;
    }
  }

  if (actionError) {
    throw actionError;
  }
}

async function performMobileTap(driver, step) {
  if (typeof driver.execute === 'function') {
    await driver.execute('mobile: tap', { x: step.x, y: step.y });
    return;
  }

  await driver.executeScript('mobile: tap', [{ x: step.x, y: step.y }]);
}

async function performTap(driver, step, tapDurationMs, tapMethod) {
  if (tapMethod === 'mobile') {
    await performMobileTap(driver, step);
    return;
  }

  await performPointerTap(driver, step, tapDurationMs);
}

function batchSizes(totalLoops, targetLoops, maxRequests) {
  const batchCount = Math.min(maxRequests, Math.ceil(totalLoops / targetLoops));
  const baseSize = Math.floor(totalLoops / batchCount);
  const extra = totalLoops % batchCount;
  return Array.from({ length: batchCount }, (_, index) => baseSize + (index < extra ? 1 : 0));
}

function resolvedLoopCount(config) {
  const run = config.run ?? {};
  return Math.max(1, numberOrDefault(run.loops, 1));
}

function estimatedStepDurationMs(step, tapDurationMs) {
  if (step.type === 'tap') {
    return tapDurationMs;
  }

  if (step.type === 'wait') {
    return step.ms;
  }

  if (step.type === 'waitRandom') {
    return step.maxMs;
  }

  return 0;
}

function estimatedBatchDurationMs(config, loopsInBatch, tapDurationMs, betweenLoopsDelayMs, includesRunFinalLoop) {
  const sequenceDurationMs = config.sequence.reduce(
    (total, step) => total + estimatedStepDurationMs(step, tapDurationMs),
    0
  );
  const betweenLoopCount = includesRunFinalLoop ? Math.max(0, loopsInBatch - 1) : loopsInBatch;
  return sequenceDurationMs * loopsInBatch + betweenLoopsDelayMs * betweenLoopCount;
}

function maxEstimatedBatchDurationMs(config, options) {
  const run = config.run ?? {};
  const loops = resolvedLoopCount(config);
  const tapDurationMs = Math.max(1, numberOrDefault(run.tapDurationMs, 80));
  const betweenLoopsDelayMs = Math.max(0, numberOrDefault(run.betweenLoopsDelayMs, 0));
  const sizes = batchSizes(loops, options.batchTargetLoops, options.batchMaxRequests);
  return sizes.reduce((maxDurationMs, loopsInBatch, index) => {
    const includesRunFinalLoop = index === sizes.length - 1;
    return Math.max(
      maxDurationMs,
      estimatedBatchDurationMs(config, loopsInBatch, tapDurationMs, betweenLoopsDelayMs, includesRunFinalLoop)
    );
  }, 0);
}

function validateBatchOptions(config, options) {
  const loops = resolvedLoopCount(config);
  const defaultBatchCapacity = options.batchTargetLoops * options.batchMaxRequests;
  if (!options.loopOverride && loops > defaultBatchCapacity) {
    throw new Error(
      `Batch mode requires an explicit loop count when config run.loops (${loops}) is greater than ${defaultBatchCapacity}. Use: npm run legacy:click:connected 100 -- --mode batch`
    );
  }
}

function buildBatchActions(sequence, loops, tapDurationMs, betweenLoopsDelayMs, isFinalLoopInRun) {
  const actions = [];
  const details = [];

  for (let loopIndex = 0; loopIndex < loops; loopIndex += 1) {
    for (let stepIndex = 0; stepIndex < sequence.length; stepIndex += 1) {
      const step = sequence[stepIndex];

      if (step.type === 'tap') {
        actions.push(...tapActions(step, tapDurationMs));
        details.push({ type: 'tap', x: step.x, y: step.y, label: step.label });
        continue;
      }

      if (step.type === 'wait' || step.type === 'waitRandom') {
        const ms = resolveWaitMs(step);
        if (ms > 0) {
          actions.push({ type: 'pause', duration: ms });
        }
        details.push({ type: step.type, ms });
        continue;
      }

      throw new Error(`Unsupported step type at sequence[${stepIndex}]: ${step.type}`);
    }

    if ((loopIndex < loops - 1 || !isFinalLoopInRun) && betweenLoopsDelayMs > 0) {
      actions.push({ type: 'pause', duration: betweenLoopsDelayMs });
      details.push({ type: 'betweenLoops', ms: betweenLoopsDelayMs });
    }
  }

  return { actions, details };
}

async function performBatch(driver, actions, dryRun) {
  if (dryRun) {
    return;
  }

  await driver.performActions([
    {
      type: 'pointer',
      id: 'finger1',
      parameters: { pointerType: 'touch' },
      actions,
    },
  ]);
  await withTimeout(
    driver.releaseActions(),
    ACTION_RELEASE_TIMEOUT_MS,
    `Pointer action release timed out after ${ACTION_RELEASE_TIMEOUT_MS}ms`
  );
}

async function runStepSequence(driver, config, options) {
  const run = config.run ?? {};
  const loops = resolvedLoopCount(config);
  const initialDelayMs = Math.max(0, numberOrDefault(run.initialDelayMs, 0));
  const betweenLoopsDelayMs = Math.max(0, numberOrDefault(run.betweenLoopsDelayMs, 0));
  const tapDurationMs = Math.max(1, numberOrDefault(run.tapDurationMs, 80));

  if (initialDelayMs > 0) {
    logAt(options, 'progress', `Initial delay: ${initialDelayMs}ms`);
    await sleep(initialDelayMs);
  }

  for (let loopIndex = 0; loopIndex < loops; loopIndex += 1) {
    if (shouldLog(options, 'progress') && shouldLogProgress(loopIndex, loops)) {
      console.log(`Progress: loop ${loopIndex + 1}/${loops}`);
    }

    for (let stepIndex = 0; stepIndex < config.sequence.length; stepIndex += 1) {
      const step = config.sequence[stepIndex];

      if (step.type === 'tap') {
        assertTapStep(step, stepIndex);
        const label = step.label ? ` (${step.label})` : '';
        logAt(options, 'verbose', `  tap ${step.x},${step.y}${label}`);

        if (!options.dryRun) {
          await performTap(driver, step, tapDurationMs, options.tapMethod);
        }
        continue;
      }

      if (step.type === 'wait' || step.type === 'waitRandom') {
        if (step.type === 'wait') {
          assertWaitStep(step, stepIndex);
        } else {
          assertWaitRandomStep(step, stepIndex);
        }
        const ms = resolveWaitMs(step);
        const prefix = step.type === 'waitRandom' ? 'random wait' : 'wait';
        logAt(options, 'verbose', `  ${prefix} ${ms}ms`);
        await sleep(ms);
        continue;
      }

      throw new Error(`Unsupported step type at sequence[${stepIndex}]: ${step.type}`);
    }

    if (loopIndex < loops - 1 && betweenLoopsDelayMs > 0) {
      logAt(options, 'verbose', `Between-loop delay: ${betweenLoopsDelayMs}ms`);
      await sleep(betweenLoopsDelayMs);
    }
  }
}

async function runBatchSequence(driver, config, options) {
  const run = config.run ?? {};
  const loops = resolvedLoopCount(config);
  const initialDelayMs = Math.max(0, numberOrDefault(run.initialDelayMs, 0));
  const betweenLoopsDelayMs = Math.max(0, numberOrDefault(run.betweenLoopsDelayMs, 0));
  const tapDurationMs = Math.max(1, numberOrDefault(run.tapDurationMs, 80));
  const sizes = batchSizes(loops, options.batchTargetLoops, options.batchMaxRequests);

  if (initialDelayMs > 0) {
    logAt(options, 'progress', `Initial delay: ${initialDelayMs}ms`);
    await sleep(initialDelayMs);
  }

  logAt(
    options,
    'progress',
    `Batch mode: ${loops} loops in ${sizes.length} request(s): ${sizes.join(', ')} loop(s) per request`
  );

  let completedLoops = 0;
  for (let batchIndex = 0; batchIndex < sizes.length; batchIndex += 1) {
    const loopsInBatch = sizes[batchIndex];
    const isFinalBatch = batchIndex === sizes.length - 1;
    const { actions, details } = buildBatchActions(
      config.sequence,
      loopsInBatch,
      tapDurationMs,
      betweenLoopsDelayMs,
      isFinalBatch
    );

    logAt(
      options,
      'progress',
      `Progress: batch ${batchIndex + 1}/${sizes.length}, loops ${completedLoops + 1}-${completedLoops + loopsInBatch}`
    );

    if (shouldLog(options, 'verbose')) {
      const randomWaits = details
        .filter((detail) => detail.type === 'waitRandom')
        .map((detail) => `${detail.ms}ms`);
      if (randomWaits.length > 0) {
        console.log(`  random waits: ${randomWaits.join(', ')}`);
      }
    }

    await performBatch(driver, actions, options.dryRun);
    completedLoops += loopsInBatch;
  }
}

async function runSequence(driver, config, options) {
  if (options.mode === 'batch') {
    if (options.tapMethod !== 'pointer') {
      throw new Error('Batch mode only supports --tap-method pointer');
    }
    await runBatchSequence(driver, config, options);
    return;
  }

  await runStepSequence(driver, config, options);
}

async function main() {
  const options = parseArgs(process.argv);

  if (options.help) {
    printHelp();
    return;
  }

  const config = await loadConfig(options.config);
  if (options.loops) {
    config.run = config.run ?? {};
    config.run.loops = options.loops;
  }
  config.appium.forwardLogs = options.logLevel === 'verbose';
  if (options.mode === 'batch') {
    validateBatchOptions(config, options);
  }

  const appium = config.appium;
  const baseConnectionRetryTimeout = numberOrDefault(appium.connectionRetryTimeout, 120000);
  const connectionRetryTimeout = options.mode === 'batch'
    ? Math.max(baseConnectionRetryTimeout, maxEstimatedBatchDurationMs(config, options) + 60000)
    : baseConnectionRetryTimeout;
  const connection = {
    hostname: appium.hostname ?? '127.0.0.1',
    port: appium.port ?? 4723,
    path: appium.path ?? '/',
    logLevel: options.logLevel === 'verbose' ? (appium.logLevel ?? 'warn') : 'silent',
    connectionRetryCount: numberOrDefault(appium.connectionRetryCount, 0),
    connectionRetryTimeout,
    capabilities: appium.capabilities,
  };
  const loops = resolvedLoopCount(config);
  const runStartedAt = Date.now();
  console.log(
    `Run starting: mode=${options.mode}, loops=${loops}, tapMethod=${options.tapMethod}, logLevel=${options.logLevel}`
  );
  console.log(`Sequence: ${sequenceSummary(config)}`);

  if (options.dryRun) {
    console.log('Dry run: Appium session will not be opened.');
    await runSequence(null, config, options);
    console.log(`Run finished: loops=${loops}, elapsed=${formatDuration(Date.now() - runStartedAt)}`);
    return;
  }

  let driver;
  let appiumProcess;
  let cleanupPromise;
  const cleanup = () => {
    cleanupPromise ??= cleanupResources({ driver, appiumProcess });
    return cleanupPromise;
  };
  const handleSignal = (signal) => {
    console.log(`Received ${signal}; stopping the Appium session cleanly...`);
    cleanup().finally(() => {
      process.exit(signal === 'SIGINT' ? 130 : 143);
    });
  };
  const handleSigint = () => handleSignal('SIGINT');
  const handleSigterm = () => handleSignal('SIGTERM');

  process.once('SIGINT', handleSigint);
  process.once('SIGTERM', handleSigterm);

  try {
    assertInitializedForClick(config, options);
    await preflightRealDevice(config, options);
    appiumProcess = await ensureAppium(appium, options.startAppium || appium.autoStart === true);
    const { remote } = await import('webdriverio');
    console.log(`Connecting to Appium at ${connection.hostname}:${connection.port}${connection.path}`);
    driver = await remote(connection);
    await runSequence(driver, config, options);
    console.log(`Run finished: loops=${loops}, elapsed=${formatDuration(Date.now() - runStartedAt)}`);
  } finally {
    process.off('SIGINT', handleSigint);
    process.off('SIGTERM', handleSigterm);
    await cleanup();
  }
}

main().catch((error) => {
  const classified = classifyConnectionError(error);
  console.error(classified.message);
  if (classified.detail && classified.detail !== classified.message) {
    console.error(`诊断：${classified.detail}`);
  }
  if (classified.userAction) {
    console.error(`下一步：${classified.userAction}`);
  }
  if (classified.code !== 'UNKNOWN') {
    console.error('重试：npm run legacy:click:connected -- --loops 1');
  }
  process.exitCode = 1;
});
