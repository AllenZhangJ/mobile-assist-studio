import http from 'node:http';
import process from 'node:process';
import { rename, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import {
  AssistSession,
  appiumStatusUrl,
  capabilityValue,
  isAppiumReady,
  listUsbmuxDevices,
  readJson,
  sleep,
  withTimeout,
} from './ios-assist-session.mjs';
import { AssistRunner } from './ios-assist-runner.mjs';
import { EvidenceStore } from './ios-assist-evidence.mjs';
import { analyzeVisualSnapshot } from './ios-assist-visual.mjs';
import { createDeviceDiscoveryStatus } from './ios-assist-device-discovery.mjs';
import {
  normalizeWorkflow,
  resolveExecutableSequence,
  summarizeWorkflowConfig,
  validateWorkflow,
  workflowFromConfig,
} from './ios-assist-workflow.mjs';
import {
  manualDeviceCommandBlockReason,
  workflowWriteBlockReason,
} from './ios-assist-console-guards.mjs';
import { publicErrorMessage, publicText } from './ios-assist-public-text.mjs';
import { publicPayload } from './ios-assist-public-payload.mjs';

const DEFAULT_CONFIG = 'config/connected-device.sequence.json';
const LOG_LIMIT = 500;
const EVENT_LIMIT = 300;
const MAX_BODY_BYTES = 64 * 1024;
const HTTP_REQUEST_TIMEOUT_MS = 30_000;
const HTTP_HEADERS_TIMEOUT_MS = 35_000;
const HTTP_KEEP_ALIVE_TIMEOUT_MS = 5_000;
const HTTP_SHUTDOWN_TIMEOUT_MS = 3_000;
const SCREENSHOT_CAPTURE_TIMEOUT_MS = 10_000;
const PAGE_SOURCE_CAPTURE_TIMEOUT_MS = 5_000;
const FAILURE_SCREENSHOT_TIMEOUT_MS = 5_000;
const DEVICE_COMMAND_HARD_LOCK_TIMEOUT_MS = 30_000;
const RUNNER_SHUTDOWN_WAIT_TIMEOUT_MS = 5_000;

const state = {
  logs: [],
  runEvents: [],
  evidence: {
    lastScreenshot: null,
    lastTap: null,
    lastError: null,
    lastVisual: null,
  },
  clients: new Set(),
  session: null,
  runner: null,
  evidenceStore: new EvidenceStore(),
  discoverDevicesForStatus: null,
  workflowWriteInProgress: false,
  deviceCommand: null,
};

function readOptionValue(argv, index, name) {
  const value = argv[index + 1];
  if (!value || value.startsWith('--')) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function parseArgs(argv) {
  const options = {
    config: DEFAULT_CONFIG,
    port: 4877,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--config') {
      options.config = readOptionValue(argv, index, '--config');
      index += 1;
      continue;
    }
    if (arg === '--port') {
      const value = Number(readOptionValue(argv, index, '--port'));
      if (!Number.isInteger(value) || value < 1 || value > 65535) {
        throw new Error('--port requires a valid TCP port');
      }
      options.port = value;
      index += 1;
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      options.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function printHelp() {
  console.log(`
Usage:
  node legacy/node/src/ios-assist-console.mjs --config config/connected-device.sequence.json
  node legacy/node/src/ios-assist-console.mjs --port 4877
`);
}

function sendJson(response, statusCode, body) {
  if (response.writableEnded) {
    return;
  }
  if (response.headersSent) {
    response.end();
    return;
  }
  response.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  response.end(JSON.stringify(body));
}

function sendErrorJson(response, statusCode, error) {
  try {
    sendJson(response, statusCode, { error: publicErrorMessage(error) });
  } catch {
    try {
      response.destroy();
    } catch {
      // Nothing useful can be done after a failed error response.
    }
  }
}

function httpError(message, statusCode) {
  return Object.assign(new Error(message), { statusCode });
}

async function readBody(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) {
      throw httpError('Request body is too large', 413);
    }
    chunks.push(chunk);
  }
  const text = Buffer.concat(chunks).toString('utf8');
  return text ? JSON.parse(text) : {};
}

async function writeJsonAtomic(filePath, value) {
  const absolutePath = resolve(process.cwd(), filePath);
  const temporaryPath = `${absolutePath}.tmp-${process.pid}-${Date.now()}`;
  try {
    await writeFile(temporaryPath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
    await rename(temporaryPath, absolutePath);
  } catch (error) {
    await rm(temporaryPath, { force: true });
    throw error;
  }
}

function sequenceRows(sequence) {
  const rows = [];
  for (let index = 0; index < sequence.length; index += 1) {
    const step = sequence[index];
    if (step.type !== 'tap') {
      continue;
    }

    const nextStep = sequence[index + 1];
    let waitAfter = null;
    if (nextStep?.type === 'wait') {
      waitAfter = `${nextStep.ms}ms`;
    } else if (nextStep?.type === 'waitRandom') {
      waitAfter = `${nextStep.minMs}-${nextStep.maxMs}ms`;
    }

    rows.push({
      label: step.label ?? `#${rows.length + 1}`,
      x: step.x,
      y: step.y,
      waitAfter,
    });
  }
  return rows;
}

function summarizeIdentifier(value) {
  const text = String(value ?? '');
  if (text.length <= 10) {
    return text;
  }
  return `${text.slice(0, 6)}...${text.slice(-4)}`;
}

function publicDevice(device) {
  if (!device) {
    return null;
  }
  return {
    udid: summarizeIdentifier(device.udid),
    connectionType: device.connectionType,
  };
}

function publicError(error) {
  if (!error) {
    return null;
  }
  return {
    code: error.code,
    message: publicErrorMessage(error),
    userAction: publicText(error.userAction),
  };
}

function publicSession(sessionSnapshot) {
  return {
    ...sessionSnapshot,
    device: publicDevice(sessionSnapshot.device),
    error: publicError(sessionSnapshot.error),
  };
}

function publicLastInit(lastInit) {
  if (!lastInit) {
    return null;
  }
  return {
    initializedAt: lastInit.initializedAt,
    selectedUdid: summarizeIdentifier(lastInit.selectedUdid),
    source: lastInit.source,
    selection: lastInit.selection,
    device: publicDevice(lastInit.device),
  };
}

function runSummary(config) {
  const run = config.run ?? {};
  return {
    loops: run.loops ?? 1,
    initialDelayMs: run.initialDelayMs ?? 0,
    betweenLoopsDelayMs: run.betweenLoopsDelayMs ?? 0,
    tapDurationMs: run.tapDurationMs ?? 80,
    stopOnError: run.stopOnError !== false,
  };
}

function workflowNodeLabel(node) {
  if (node.type === 'Tap') {
    return node.params?.label ?? node.id;
  }
  if (node.type === 'Wait') {
    if ('ms' in (node.params ?? {})) {
      return `${node.params.ms}ms`;
    }
    return `${node.params?.minMs}-${node.params?.maxMs}ms`;
  }
  return node.type;
}

function workflowNodeParams(node) {
  if (node.type === 'Tap') {
    return {
      label: node.params?.label ?? node.id,
      x: node.params?.x,
      y: node.params?.y,
    };
  }
  if (node.type === 'Wait') {
    if ('ms' in (node.params ?? {})) {
      return { ms: node.params.ms };
    }
    return {
      minMs: node.params?.minMs,
      maxMs: node.params?.maxMs,
    };
  }
  if (node.type === 'Snapshot') {
    return { reason: node.params?.reason ?? node.id };
  }
  if (node.type === 'Visual_Branch') {
    return {
      rules: (node.params?.rules ?? []).map((rule) => ({
        id: rule.id,
        minConfidence: rule.minConfidence,
        next: rule.next,
      })),
    };
  }
  if (node.type === 'If_Else') {
    return { condition: node.condition ?? null };
  }
  if (node.type === 'Sub_Workflow') {
    return { workflowId: node.params?.workflowId ?? '' };
  }
  return {};
}

function workflowNodeEdges(node) {
  const edges = [];
  const pushEdge = (target, kind) => {
    if (target) {
      edges.push({ from: node.id, to: target, kind });
    }
  };
  pushEdge(node.next, 'next');
  pushEdge(node.trueNext, 'true');
  pushEdge(node.falseNext, 'false');
  pushEdge(node.defaultNext, 'default');
  pushEdge(node.lowConfidenceNext, 'low-confidence');
  pushEdge(node.onError, 'error');
  for (const rule of node.params?.rules ?? []) {
    pushEdge(rule.next, `rule:${rule.id}`);
  }
  return edges;
}

function publicWorkflowDetails(config) {
  const workflow = workflowFromConfig(config);
  return {
    entry: workflow.entry,
    nodes: workflow.nodes.map((node) => ({
      id: node.id,
      type: node.type,
      label: workflowNodeLabel(node),
      params: workflowNodeParams(node),
      next: node.next ?? null,
      trueNext: node.trueNext ?? null,
      falseNext: node.falseNext ?? null,
      defaultNext: node.defaultNext ?? null,
      lowConfidenceNext: node.lowConfidenceNext ?? null,
      onError: node.onError ?? null,
    })),
    edges: workflow.nodes.flatMap(workflowNodeEdges),
  };
}

function workflowPayload(config) {
  let sourceWorkflow;
  try {
    sourceWorkflow = workflowFromConfig(config);
  } catch (error) {
    const message = publicErrorMessage(error);
    return {
      workflow: null,
      validation: {
        ok: false,
        errors: [message],
        warnings: [],
        summary: {
          id: 'invalid-config',
          version: null,
          entry: null,
          nodeCount: 0,
          nodeTypes: {},
        },
      },
      public: { entry: null, nodes: [], edges: [] },
    };
  }
  const validation = validateWorkflow(sourceWorkflow);
  const workflow = validation.ok ? normalizeWorkflow(sourceWorkflow) : null;
  return {
    workflow,
    validation,
    public: validation.ok ? publicWorkflowDetails({ workflow }) : { entry: null, nodes: [], edges: [] },
  };
}

function workflowConfigErrorPayload(error) {
  const message = publicErrorMessage(error);
  return {
    workflow: null,
    validation: {
      ok: false,
      errors: [`Config could not be loaded: ${message}`],
      warnings: [],
      summary: {
        id: 'missing-config',
        version: null,
        entry: null,
        nodeCount: 0,
        nodeTypes: {},
      },
    },
    public: { entry: null, nodes: [], edges: [] },
  };
}

function workflowFromBody(body) {
  const workflow = body?.workflow ?? body;
  if (!workflow || typeof workflow !== 'object' || Array.isArray(workflow)) {
    throw new Error('workflow must be an object');
  }
  return workflow;
}

function assertWorkflowWritable() {
  if (state.workflowWriteInProgress) {
    throw Object.assign(new Error('Workflow write is already in progress. Wait for it to finish before changing workflow.'), { statusCode: 409 });
  }
  assertWorkflowLifecycleWritable();
}

function assertWorkflowLifecycleWritable() {
  const reason = workflowWriteBlockReason({
    sessionSnapshot: state.session.snapshot(),
    runnerSnapshot: state.runner.snapshot(),
  });
  if (reason) {
    throw Object.assign(new Error(reason), { statusCode: 409 });
  }
}

async function withWorkflowWriteLock(action) {
  assertWorkflowWritable();
  state.workflowWriteInProgress = true;
  broadcast({ type: 'status' });
  try {
    return await action();
  } finally {
    state.workflowWriteInProgress = false;
    broadcast({ type: 'status' });
  }
}

function workflowWriteInProgressError(action = 'starting a run') {
  return state.workflowWriteInProgress
    ? `Workflow write is in progress. Wait for it to finish before ${action}.`
    : null;
}

function deviceCommandSnapshot() {
  if (!state.deviceCommand) {
    return { active: false };
  }
  return {
    active: true,
    name: state.deviceCommand.name,
    startedAt: state.deviceCommand.startedAt,
  };
}

function deviceCommandInProgressError(action = 'starting a run') {
  const snapshot = deviceCommandSnapshot();
  return snapshot.active
    ? `Device command is in progress (${snapshot.name}). Wait until it finishes before ${action}.`
    : null;
}

function assertManualDeviceCommandAllowed() {
  const reason = manualDeviceCommandBlockReason({
    sessionSnapshot: state.session.snapshot(),
    runnerSnapshot: state.runner.snapshot(),
    deviceCommandSnapshot: deviceCommandSnapshot(),
  });
  if (reason) {
    throw Object.assign(new Error(reason), { statusCode: 409 });
  }
}

async function withDeviceCommandLock(name, createCommand) {
  if (state.deviceCommand) {
    throw Object.assign(
      new Error(`Device command is already in progress (${state.deviceCommand.name}). Wait until it finishes before starting ${name}.`),
      { statusCode: 409 }
    );
  }

  const token = Symbol(name);
  state.deviceCommand = {
    token,
    name,
    startedAt: new Date().toISOString(),
  };
  broadcast({ type: 'status' });

  let command;
  try {
    command = createCommand();
  } catch (error) {
    if (state.deviceCommand?.token === token) {
      state.deviceCommand = null;
      broadcast({ type: 'status' });
    }
    throw error;
  }

  const settle = Promise.resolve(command.settle)
    .catch(() => {})
    .then(() => 'settled');
  const hardTimeout = sleep(DEVICE_COMMAND_HARD_LOCK_TIMEOUT_MS).then(() => 'timeout');
  Promise.race([settle, hardTimeout]).then((result) => {
    if (state.deviceCommand?.token !== token) {
      return;
    }
    if (result === 'timeout') {
      addLog('system', `Device command lock released after ${DEVICE_COMMAND_HARD_LOCK_TIMEOUT_MS}ms: ${name}`);
    }
    state.deviceCommand = null;
    broadcast({ type: 'status' });
  });

  return command.result;
}

async function awaitCommandResultAndSettle(name, command) {
  let result;
  let resultError;
  try {
    result = await command.result;
  } catch (error) {
    resultError = error;
  }

  const settled = await Promise.race([
    Promise.resolve(command.settle)
      .catch(() => {})
      .then(() => true),
    sleep(DEVICE_COMMAND_HARD_LOCK_TIMEOUT_MS).then(() => false),
  ]);
  if (!settled) {
    addLog('system', `WDA command did not settle within ${DEVICE_COMMAND_HARD_LOCK_TIMEOUT_MS}ms: ${name}`);
  }

  if (resultError) {
    throw resultError;
  }
  return result;
}

function isConnectingPhase(phase) {
  return ['initializing', 'connecting', 'waitingForDeveloperTrust'].includes(phase);
}

function isDisconnectingPhase(phase) {
  return phase === 'disconnecting';
}

async function statusPayload(configPath) {
  let config;
  try {
    config = await readJson(configPath);
  } catch (error) {
    const message = publicErrorMessage(error);
    return {
      session: publicSession(state.session.snapshot()),
      run: state.runner.snapshot(),
      appium: {
        statusUrl: '',
        ready: false,
      },
      config: {
        error: `Config could not be loaded: ${message}`,
        configuredUdid: '',
        configuredUdidSummary: '',
        deviceName: '',
        automationName: '',
        autoLaunch: false,
        lastInit: null,
        initMatchesConfig: false,
        configuredDeviceConnected: false,
        devices: [],
        deviceError: null,
        run: runSummary({}),
        sequence: [],
        workflow: {
          ok: false,
          executable: false,
          linear: false,
          linearError: message,
          entry: null,
          nodes: [],
          edges: [],
          nodeCount: 0,
          nodeTypes: {},
        },
      },
      evidence: state.evidence,
      evidenceStorage: state.evidenceStore.summary(),
      runEvents: state.runEvents,
      operations: {
        workflowWriteInProgress: state.workflowWriteInProgress,
        deviceCommand: deviceCommandSnapshot(),
      },
    };
  }
  const capabilities = config.appium?.capabilities ?? {};
  const configuredUdid = String(capabilityValue(capabilities, 'udid') ?? '');
  const lastInit = config.appium?.lastInit ?? null;
  let workflowResult;
  try {
    workflowResult = summarizeWorkflowConfig(config);
  } catch (error) {
    const message = publicErrorMessage(error);
    workflowResult = {
      ok: false,
      errors: [message],
      warnings: [],
      summary: {
        id: 'invalid-config',
        version: null,
        entry: null,
        nodeCount: 0,
        nodeTypes: {},
      },
    };
  }
  let workflowDetails = { entry: null, nodes: [], edges: [] };
  if (workflowResult.ok) {
    try {
      workflowDetails = publicWorkflowDetails(config);
    } catch (error) {
      workflowResult = {
        ...workflowResult,
        ok: false,
        errors: [...(workflowResult.errors ?? []), publicErrorMessage(error)],
      };
    }
  }
  let executableSequence = [];
  let linearSequenceError = null;
  let devices = [];
  let deviceError = null;

  try {
    executableSequence = resolveExecutableSequence(config);
  } catch (error) {
    linearSequenceError = publicErrorMessage(error);
  }

  const deviceDiscovery = await state.discoverDevicesForStatus();
  devices = deviceDiscovery.devices;
  deviceError = deviceDiscovery.error;
  const publicDevices = devices.map(publicDevice).filter(Boolean);

  return {
    session: publicSession(state.session.snapshot()),
    run: state.runner.snapshot(),
    operations: {
      workflowWriteInProgress: state.workflowWriteInProgress,
      deviceCommand: deviceCommandSnapshot(),
    },
    appium: {
      statusUrl: appiumStatusUrl(config.appium),
      ready: await isAppiumReady(config.appium),
    },
    config: {
      configuredUdid: summarizeIdentifier(configuredUdid),
      configuredUdidSummary: summarizeIdentifier(configuredUdid),
      deviceName: capabilityValue(capabilities, 'deviceName') ?? '',
      automationName: capabilityValue(capabilities, 'automationName') ?? '',
      autoLaunch: capabilityValue(capabilities, 'autoLaunch') === true,
      lastInit: publicLastInit(lastInit),
      initMatchesConfig: Boolean(lastInit?.selectedUdid && lastInit.selectedUdid === configuredUdid),
      configuredDeviceConnected: devices.some((device) => device.udid === configuredUdid),
      devices: publicDevices,
      deviceError,
      run: runSummary(config),
      sequence: sequenceRows(executableSequence),
      workflow: {
        ...workflowResult.summary,
        ok: workflowResult.ok,
        executable: workflowResult.ok,
        linear: !linearSequenceError,
        linearError: linearSequenceError,
        ...workflowDetails,
      },
    },
    evidence: state.evidence,
    evidenceStorage: state.evidenceStore.summary(),
    runEvents: state.runEvents,
  };
}

function broadcast(event) {
  const payload = `data: ${JSON.stringify(event)}\n\n`;
  for (const client of state.clients) {
    try {
      client.write(payload);
    } catch {
      state.clients.delete(client);
    }
  }
}

function addLog(stream, message) {
  const entry = {
    at: new Date().toISOString(),
    stream,
    message: publicText(message),
  };
  state.logs.push(entry);
  if (state.logs.length > LOG_LIMIT) {
    state.logs.splice(0, state.logs.length - LOG_LIMIT);
  }
  broadcast({ type: 'log', entry });
}

function logEvidenceStoreError(action, error) {
  addLog('system', `Evidence ${action} failed: ${error.message}`);
}

function clearLogs() {
  state.logs = [];
  broadcast({ type: 'logsCleared' });
  return { ok: true };
}

function closeEventClients() {
  for (const client of Array.from(state.clients)) {
    try {
      client.write(`data: ${JSON.stringify({ type: 'shutdown' })}\n\n`);
      client.end();
    } catch {
      // The client is already gone.
    }
    state.clients.delete(client);
  }
}

function addRunEvent(event) {
  const publicEvent = publicPayload(event);
  const entry = {
    id: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
    ...publicEvent,
  };

  if (entry.type === 'stepStart' && entry.step?.type === 'tap') {
    state.evidence.lastTap = {
      at: entry.at,
      label: entry.step.label,
      x: entry.step.x,
      y: entry.step.y,
      loopNumber: entry.loopNumber,
      stepNumber: entry.stepNumber,
    };
  }
  if (entry.type === 'runError') {
    state.evidence.lastError = {
      at: entry.at,
      message: entry.message,
      currentStep: entry.currentStep ?? null,
    };
  }
  if (entry.type === 'visualAnalysis') {
    state.evidence.lastVisual = entry.analysis ?? null;
  }

  state.runEvents.push(entry);
  if (state.runEvents.length > EVENT_LIMIT) {
    state.runEvents.splice(0, state.runEvents.length - EVENT_LIMIT);
  }
  if (entry.type === 'runStart') {
    state.evidenceStore.startRun(entry).catch((error) => logEvidenceStoreError('start', error));
  }
  state.evidenceStore.recordEvent(entry).catch((error) => logEvidenceStoreError('event write', error));
  broadcast({ type: 'runEvent', entry, evidence: state.evidence });
}

function failureHeatmapEntry(event) {
  if (!event || typeof event !== 'object' || event.status !== 'error') {
    return null;
  }
  const step = event.step;
  if (step?.type === 'tap') {
    return {
      key: `tap:${step.label ?? '-'}:${step.x}:${step.y}`,
      label: `${step.label ?? 'tap'} (${step.x}, ${step.y})`,
      detail: event.nodeId ? `node ${event.nodeId}` : (event.type ?? 'event'),
    };
  }
  if (event.nodeId) {
    return {
      key: `node:${event.nodeId}`,
      label: `node ${event.nodeId}`,
      detail: event.type ?? 'event',
    };
  }
  return null;
}

function failureHeatmapPayload(events = state.runEvents) {
  const stats = new Map();
  for (const event of Array.isArray(events) ? events : []) {
    const entry = failureHeatmapEntry(event);
    if (!entry) {
      continue;
    }
    const current = stats.get(entry.key) || { ...entry, count: 0 };
    current.count += 1;
    current.detail = entry.detail;
    stats.set(entry.key, current);
  }
  return {
    generatedAt: new Date().toISOString(),
    totalEvents: Array.isArray(events) ? events.length : 0,
    rows: Array.from(stats.values())
      .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label))
      .slice(0, 12),
  };
}

async function saveScreenshotFromPromise(reason, screenshotPromise, timeoutMs) {
  const screenshot = await withTimeout(
    screenshotPromise,
    timeoutMs,
    `Screenshot capture timed out after ${timeoutMs}ms`
  );
  const savedScreenshot = await state.evidenceStore.saveScreenshot(screenshot, {
    reason,
    lastTap: state.evidence.lastTap,
    lastError: state.evidence.lastError,
  });
  state.evidence.lastScreenshot = savedScreenshot;
  broadcast({ type: 'evidence', evidence: state.evidence });
  return savedScreenshot;
}

async function captureScreenshot(reason, { timeoutMs = SCREENSHOT_CAPTURE_TIMEOUT_MS } = {}) {
  return awaitCommandResultAndSettle(
    `runner screenshot: ${reason}`,
    createScreenshotCommand(reason, { timeoutMs })
  );
}

function createScreenshotCommand(reason, { timeoutMs = SCREENSHOT_CAPTURE_TIMEOUT_MS } = {}) {
  const screenshotPromise = state.session.captureScreenshot({ reason });
  return {
    result: saveScreenshotFromPromise(reason, screenshotPromise, timeoutMs),
    settle: screenshotPromise,
  };
}

function createVisualSnapshotCommand(reason) {
  const screenshotCommand = createScreenshotCommand(reason);
  let pageSourcePromise = null;
  const result = (async () => {
    const screenshot = await screenshotCommand.result;
    let source = '';
    try {
      pageSourcePromise = state.session.capturePageSource();
      source = await withTimeout(
        pageSourcePromise,
        PAGE_SOURCE_CAPTURE_TIMEOUT_MS,
        `Page source capture timed out after ${PAGE_SOURCE_CAPTURE_TIMEOUT_MS}ms`
      );
    } catch (error) {
      addLog('system', `Page source capture skipped: ${error.message}`);
    }
    const analysis = analyzeVisualSnapshot({
      screenshot,
      source,
      reason,
    });
    const publicAnalysis = {
      ...analysis,
      screenshot: {
        ...analysis.screenshot,
        file: screenshot.file ?? null,
      },
    };
    addRunEvent({
      type: 'visualAnalysis',
      status: analysis.decision.action === 'pause'
        ? 'paused'
        : (analysis.decision.action === 'warn' ? 'warning' : 'ok'),
      reason,
      analysis: publicAnalysis,
    });
    return {
      screenshot,
      analysis: publicAnalysis,
    };
  })();

  return {
    result,
    settle: Promise.allSettled([
      screenshotCommand.settle,
      result,
      result.catch(() => {}).then(() => pageSourcePromise),
    ]),
  };
}

async function captureVisualSnapshot(reason) {
  return awaitCommandResultAndSettle(
    `runner visual snapshot: ${reason}`,
    createVisualSnapshotCommand(reason)
  );
}

function startConnectWithEvidence(reason) {
  state.session.connect({ retryTrust: true })
    .then(() => {
      withDeviceCommandLock(`connection screenshot: ${reason}`, () => createScreenshotCommand(reason))
        .then((screenshot) => {
          addRunEvent({
            type: 'screenshot',
            status: 'ok',
            reason: screenshot.reason,
            durationMs: screenshot.durationMs,
            file: screenshot.file ?? null,
          });
        })
        .catch((error) => {
          addLog('system', `Connected, but screenshot capture failed: ${error.message}`);
        });
    })
    .catch((error) => {
      addLog('stderr', error.message);
    });
}

async function visualGuardBeforeStep(payload) {
  if (payload.step?.type !== 'tap') {
    return null;
  }
  const reason = `before-${payload.step.label ?? payload.stepNumber}`;
  const { analysis } = await captureVisualSnapshot(reason);
  if (analysis.decision.action === 'pause') {
    return {
      pause: true,
      reason: analysis.decision.reason,
      analysis,
    };
  }
  return null;
}

async function visualEvidenceAfterStep(payload) {
  if (payload.step?.type !== 'tap' || payload.status !== 'ok') {
    return null;
  }
  const reason = `after-${payload.step.label ?? payload.stepNumber}`;
  await captureVisualSnapshot(reason);
  return null;
}

async function workflowSnapshot(payload) {
  const reason = payload.reason ?? payload.node?.id ?? 'workflow-snapshot';
  const screenshot = await captureScreenshot(reason);
  addRunEvent({
    type: 'screenshot',
    status: 'ok',
    reason: screenshot.reason,
    durationMs: screenshot.durationMs,
    file: screenshot.file ?? null,
    nodeId: payload.node?.id,
    nodeType: payload.node?.type,
  });
  return {
    at: screenshot.at,
    reason: screenshot.reason,
    file: screenshot.file ?? null,
  };
}

async function workflowVisualBranch(payload) {
  const reason = payload.node?.id ?? 'workflow-visual-branch';
  const result = await captureVisualSnapshot(reason);
  return {
    analysis: result.analysis,
    screenshot: {
      at: result.screenshot.at,
      reason: result.screenshot.reason,
      file: result.screenshot.file ?? null,
    },
  };
}

function serveEvents(request, response) {
  response.writeHead(200, {
    'content-type': 'text/event-stream; charset=utf-8',
    'cache-control': 'no-store',
    connection: 'keep-alive',
  });
  response.write('\n');
  state.clients.add(response);
  response.write(`data: ${JSON.stringify({
    type: 'snapshot',
    logs: state.logs,
    runEvents: state.runEvents,
    evidence: state.evidence,
    session: publicSession(state.session.snapshot()),
    run: state.runner.snapshot(),
  })}\n\n`);

  request.on('close', () => {
    state.clients.delete(response);
  });
}

function consoleHtml() {
  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>iOS Assist Studio</title>
  <style>
    :root {
      color-scheme: dark;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #050608;
      color: #e6f7ff;
      --bg: #050608;
      --panel: rgba(9, 14, 20, 0.94);
      --panel-soft: rgba(13, 22, 30, 0.92);
      --line: #1a2a33;
      --grid: rgba(0, 245, 255, 0.08);
      --cyan: #00f5ff;
      --green: #39ff14;
      --amber: #ffaa00;
      --red: #ff0055;
      --muted: #8aa4b0;
    }
    * {
      box-sizing: border-box;
    }
    body {
      margin: 0;
      min-height: 100vh;
      background:
        linear-gradient(var(--grid) 1px, transparent 1px),
        linear-gradient(90deg, var(--grid) 1px, transparent 1px),
        radial-gradient(circle at 18% 0%, rgba(0, 245, 255, 0.14), transparent 26%),
        radial-gradient(circle at 92% 18%, rgba(57, 255, 20, 0.08), transparent 24%),
        var(--bg);
      background-size: 20px 20px, 20px 20px, auto, auto, auto;
    }
    button, input {
      font: inherit;
    }
    .topbar {
      min-height: 58px;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 16px;
      padding: 0 22px;
      border-bottom: 1px solid #d9e0ea;
      border-bottom: 1px solid var(--line);
      background: rgba(5, 8, 12, 0.9);
      box-shadow: 0 1px 0 rgba(0, 245, 255, 0.12);
    }
    .brand {
      font-size: 17px;
      font-weight: 750;
      color: #f6fdff;
    }
    .status-strip {
      display: flex;
      gap: 8px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    .shell {
      max-width: 1440px;
      margin: 0 auto;
      padding: 18px;
      display: grid;
      grid-template-columns: minmax(300px, 390px) minmax(430px, 1fr) minmax(300px, 380px);
      gap: 16px;
      align-items: start;
    }
    .panel {
      background: var(--panel);
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 0 0 1px rgba(0, 245, 255, 0.04), 0 12px 38px rgba(0, 0, 0, 0.32);
    }
    .panel h2 {
      margin: 0;
      font-size: 14px;
      line-height: 1.2;
    }
    .panel-title {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 10px;
      min-height: 46px;
      padding: 10px 14px;
      border-bottom: 1px solid var(--line);
      background: linear-gradient(90deg, rgba(0, 245, 255, 0.08), rgba(255, 255, 255, 0.02));
    }
    .panel-body {
      padding: 14px;
      display: grid;
      gap: 12px;
    }
    .hero-state {
      display: grid;
      gap: 10px;
      padding: 16px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--panel-soft);
    }
    .hero-state h1 {
      margin: 0;
      font-size: 22px;
      line-height: 1.2;
      letter-spacing: 0;
    }
    .hero-state p {
      margin: 0;
      color: var(--muted);
      line-height: 1.45;
      font-size: 13px;
    }
    .spinner {
      width: 18px;
      height: 18px;
      border: 2px solid rgba(0, 245, 255, 0.22);
      border-top-color: var(--cyan);
      border-radius: 999px;
      animation: spin 900ms linear infinite;
      display: inline-block;
      vertical-align: -4px;
      margin-right: 8px;
    }
    @keyframes spin {
      to { transform: rotate(360deg); }
    }
    .badge {
      display: inline-flex;
      align-items: center;
      min-height: 24px;
      padding: 0 9px;
      border-radius: 999px;
      background: rgba(138, 164, 176, 0.12);
      color: #d7eef5;
      font-size: 12px;
      font-weight: 700;
      white-space: nowrap;
    }
    .badge.ok {
      background: rgba(57, 255, 20, 0.12);
      color: var(--green);
    }
    .badge.warn {
      background: rgba(255, 170, 0, 0.12);
      color: var(--amber);
    }
    .badge.danger {
      background: rgba(255, 0, 85, 0.12);
      color: #ff6f9f;
    }
    .badge.info {
      background: rgba(0, 245, 255, 0.12);
      color: var(--cyan);
    }
    .controls {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
    }
    .run-box {
      display: grid;
      grid-template-columns: 92px 1fr;
      gap: 8px;
    }
    input[type="number"] {
      width: 100%;
      border: 1px solid var(--line);
      border-radius: 6px;
      padding: 8px 10px;
      min-height: 40px;
      background: rgba(0, 0, 0, 0.28);
      color: #e6f7ff;
    }
    button {
      min-height: 40px;
      border: 1px solid #26404b;
      border-radius: 6px;
      background: rgba(8, 16, 22, 0.92);
      color: #e6f7ff;
      cursor: pointer;
      white-space: nowrap;
    }
    button.primary {
      background: linear-gradient(135deg, rgba(0, 245, 255, 0.22), rgba(57, 255, 20, 0.12));
      border-color: rgba(0, 245, 255, 0.65);
      color: #f7feff;
      font-weight: 700;
    }
    button.danger {
      border-color: rgba(255, 0, 85, 0.55);
      color: #ff7aa6;
    }
    button:disabled {
      cursor: not-allowed;
      opacity: 0.5;
    }
    button.compact {
      min-height: 30px;
      padding: 0 10px;
      font-size: 12px;
    }
    .metric-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 8px;
    }
    .metric {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 10px;
      background: rgba(0, 0, 0, 0.2);
    }
    .metric .label {
      font-size: 12px;
      color: var(--muted);
    }
    .metric .value {
      margin-top: 4px;
      font-size: 15px;
      font-weight: 750;
      overflow-wrap: anywhere;
    }
    .issue {
      display: none;
      border: 1px solid rgba(255, 170, 0, 0.42);
      background: rgba(255, 170, 0, 0.08);
      border-radius: 8px;
      padding: 12px;
      color: #ffd28a;
      font-size: 13px;
      line-height: 1.45;
    }
    .issue strong {
      display: block;
      margin-bottom: 4px;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      font-size: 13px;
    }
    th, td {
      border-bottom: 1px solid var(--line);
      padding: 9px 10px;
      text-align: left;
    }
    th {
      color: var(--muted);
      font-weight: 700;
      background: rgba(0, 245, 255, 0.04);
    }
    tr.current-step {
      background: rgba(0, 245, 255, 0.1);
      outline: 1px solid rgba(0, 245, 255, 0.28);
    }
    .log-actions {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
      justify-content: flex-end;
    }
    .log {
      height: 340px;
      overflow: auto;
      background: #030507;
      color: #e5e7eb;
      padding: 12px;
      font: 12px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      line-height: 1.55;
      white-space: pre-wrap;
    }
    .log .stderr {
      color: #fecaca;
    }
    .log .system {
      color: #bfdbfe;
    }
    .log .appium {
      color: #d1d5db;
    }
    .muted {
      color: var(--muted);
      font-size: 12px;
      line-height: 1.45;
    }
    .device-stage {
      min-height: 420px;
      display: grid;
      place-items: center;
      border: 1px solid var(--line);
      border-radius: 8px;
      background:
        linear-gradient(rgba(0, 245, 255, 0.06) 1px, transparent 1px),
        linear-gradient(90deg, rgba(0, 245, 255, 0.06) 1px, transparent 1px),
        #020405;
      background-size: 20px 20px;
      position: relative;
      overflow: hidden;
    }
    .device-frame {
      width: min(240px, 72vw);
      aspect-ratio: 9 / 19.5;
      border: 8px solid #111820;
      border-radius: 34px;
      background: #000;
      box-shadow: 0 0 32px rgba(0, 245, 255, 0.12);
      overflow: hidden;
      position: relative;
    }
    .device-frame img {
      width: 100%;
      height: 100%;
      object-fit: contain;
      display: block;
      background: #000;
    }
    .device-empty {
      padding: 18px;
      color: var(--muted);
      text-align: center;
      line-height: 1.5;
    }
    .tap-dot {
      width: 14px;
      height: 14px;
      position: absolute;
      border: 2px solid var(--red);
      border-radius: 999px;
      box-shadow: 0 0 14px rgba(255, 0, 85, 0.8);
      transform: translate(-50%, -50%);
      pointer-events: none;
    }
    .timeline {
      max-height: 360px;
      overflow: auto;
      display: grid;
      gap: 8px;
    }
    .event-row {
      display: grid;
      grid-template-columns: 90px 1fr auto;
      gap: 10px;
      align-items: center;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 8px 10px;
      background: rgba(0, 0, 0, 0.18);
      font-size: 12px;
    }
    .event-row.error {
      border-color: rgba(255, 0, 85, 0.45);
    }
    .event-row.ok {
      border-color: rgba(57, 255, 20, 0.28);
    }
    .event-row.warning,
    .event-row.paused {
      border-color: rgba(255, 170, 0, 0.45);
    }
    .event-time {
      color: var(--muted);
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    }
    .event-main {
      overflow-wrap: anywhere;
    }
    .heatmap {
      display: grid;
      gap: 8px;
      max-height: 260px;
      overflow: auto;
    }
    .heatmap-row {
      display: grid;
      grid-template-columns: minmax(120px, 1fr) 48px;
      gap: 10px;
      align-items: center;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 8px 10px;
      background: rgba(0, 0, 0, 0.18);
      font-size: 12px;
    }
    .heatmap-main {
      display: grid;
      gap: 6px;
      min-width: 0;
    }
    .heatmap-label {
      overflow-wrap: anywhere;
    }
    .heatmap-bar {
      height: 5px;
      border-radius: 999px;
      background: linear-gradient(90deg, rgba(255, 0, 85, 0.86), rgba(255, 170, 0, 0.6));
      box-shadow: 0 0 12px rgba(255, 0, 85, 0.24);
    }
    .heatmap-count {
      color: #ffb4ca;
      font-weight: 800;
      text-align: right;
    }
    .workflow-board {
      display: grid;
      grid-template-columns: minmax(360px, 1fr) minmax(260px, 340px);
      gap: 12px;
      align-items: stretch;
    }
    .workflow-canvas {
      min-height: 360px;
      overflow: auto;
      border: 1px solid var(--line);
      border-radius: 8px;
      background:
        linear-gradient(rgba(0, 245, 255, 0.05) 1px, transparent 1px),
        linear-gradient(90deg, rgba(0, 245, 255, 0.05) 1px, transparent 1px),
        rgba(0, 0, 0, 0.2);
      background-size: 24px 24px;
      position: relative;
    }
    .workflow-canvas-inner {
      min-width: 100%;
      min-height: 360px;
      position: relative;
    }
    .workflow-edges {
      inset: 0;
      pointer-events: none;
      position: absolute;
      z-index: 0;
    }
    .workflow-edge {
      fill: none;
      stroke: rgba(0, 245, 255, 0.44);
      stroke-width: 1.4;
      filter: drop-shadow(0 0 5px rgba(0, 245, 255, 0.18));
    }
    .workflow-edge.error {
      stroke: rgba(255, 0, 85, 0.62);
    }
    .workflow-edge.low-confidence {
      stroke: rgba(255, 170, 0, 0.62);
    }
    .workflow-edge.true,
    .workflow-edge.false {
      stroke: rgba(57, 255, 20, 0.42);
    }
    .workflow-nodes {
      inset: 0;
      position: absolute;
      z-index: 1;
    }
    .workflow-node {
      cursor: grab;
      min-height: 92px;
      position: absolute;
      width: 144px;
      display: grid;
      gap: 6px;
      align-content: start;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 10px;
      background: rgba(0, 0, 0, 0.22);
      text-align: left;
      white-space: normal;
      touch-action: none;
    }
    .workflow-node.dragging {
      cursor: grabbing;
      opacity: 0.92;
      z-index: 4;
    }
    .workflow-node.current {
      border-color: rgba(0, 245, 255, 0.72);
      box-shadow: 0 0 18px rgba(0, 245, 255, 0.12);
    }
    .workflow-node.selected {
      outline: 1px solid rgba(57, 255, 20, 0.52);
    }
    .workflow-node .node-id {
      color: var(--muted);
      font: 11px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      overflow-wrap: anywhere;
    }
    .workflow-node .node-type {
      font-size: 12px;
      color: var(--cyan);
      font-weight: 800;
    }
    .workflow-node .node-label {
      font-size: 14px;
      font-weight: 750;
      overflow-wrap: anywhere;
    }
    .workflow-detail {
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 12px;
      background: rgba(0, 0, 0, 0.2);
      min-height: 180px;
      display: grid;
      gap: 8px;
      align-content: start;
    }
    .workflow-detail pre {
      margin: 0;
      max-height: 220px;
      overflow: auto;
      font: 11px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      color: #d7eef5;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
    }
    .workflow-editor {
      width: 100%;
      min-height: 320px;
      resize: vertical;
      border: 1px solid var(--line);
      border-radius: 8px;
      padding: 12px;
      background: #030507;
      color: #d7eef5;
      font: 12px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      line-height: 1.55;
      outline: none;
    }
    .workflow-editor:focus {
      border-color: rgba(0, 245, 255, 0.68);
      box-shadow: 0 0 0 1px rgba(0, 245, 255, 0.12);
    }
    .workflow-editor-status {
      min-height: 24px;
      color: var(--muted);
      font-size: 12px;
      overflow-wrap: anywhere;
    }
    .workflow-editor-status.ok {
      color: var(--green);
    }
    .workflow-editor-status.warn {
      color: var(--amber);
    }
    .workflow-editor-status.danger {
      color: #ff6f9f;
    }
    .edge-list {
      display: flex;
      gap: 6px;
      flex-wrap: wrap;
    }
    .edge-chip {
      border: 1px solid var(--line);
      border-radius: 999px;
      padding: 4px 8px;
      color: var(--muted);
      font-size: 11px;
      background: rgba(255, 255, 255, 0.03);
    }
    .wide {
      grid-column: 1 / -1;
    }
    @media (max-width: 900px) {
      .topbar {
        align-items: flex-start;
        flex-direction: column;
        padding: 12px;
      }
      .shell {
        grid-template-columns: 1fr;
        padding: 12px;
      }
      .metric-grid {
        grid-template-columns: 1fr;
      }
      .workflow-board {
        grid-template-columns: 1fr;
      }
      .workflow-canvas {
        min-height: 320px;
      }
    }
  </style>
</head>
<body>
  <header class="topbar">
    <div class="brand">iOS Assist Studio</div>
    <div class="status-strip">
      <span id="deviceBadge" class="badge">设备读取中</span>
      <span id="wdaBadge" class="badge">WDA 未连接</span>
      <span id="runBadge" class="badge">任务空闲</span>
    </div>
  </header>

  <main class="shell">
    <section class="panel">
      <div class="panel-title"><h2>连接控制</h2></div>
      <div class="panel-body">
        <div class="hero-state">
          <h1 id="heroTitle">准备连接</h1>
          <p id="heroText">点击初始化并连接后，看板会发现 USB iPhone、启动 Appium、预热 WDA，并保持 WebDriver 会话。</p>
        </div>
        <div id="issueBox" class="issue"></div>
        <div class="controls">
          <button id="connectButton" class="primary">初始化并连接</button>
          <button id="disconnectButton">断开连接</button>
          <button id="reconnectButton">重新连接</button>
          <button id="refreshButton">刷新状态</button>
        </div>
      </div>
    </section>

    <section class="panel">
      <div class="panel-title">
        <h2>数字孪生设备视窗</h2>
        <div class="log-actions">
          <button id="visualButton" class="compact">分析画面</button>
          <button id="screenshotButton" class="compact">刷新截图</button>
        </div>
      </div>
      <div class="panel-body">
        <div class="device-stage">
          <div class="device-frame" id="deviceFrame">
            <div id="deviceEmpty" class="device-empty">连接后可刷新当前屏幕快照</div>
            <img id="screenshotImage" alt="iPhone screen snapshot" hidden>
            <div id="tapDot" class="tap-dot" hidden></div>
          </div>
        </div>
        <div class="metric-grid">
          <div class="metric"><div class="label">最近截图</div><div id="screenshotMetric" class="value">-</div></div>
          <div class="metric"><div class="label">最近点击</div><div id="tapMetric" class="value">-</div></div>
          <div class="metric"><div class="label">最近错误</div><div id="errorMetric" class="value">-</div></div>
          <div class="metric"><div class="label">视觉守卫</div><div id="visualMetric" class="value">-</div></div>
        </div>
      </div>
    </section>

    <section class="panel">
      <div class="panel-title"><h2>执行任务</h2></div>
      <div class="panel-body">
        <div class="controls">
          <button id="testButton">测试 1 轮</button>
          <div class="run-box">
            <input id="loopsInput" type="number" min="1" step="1" value="10" aria-label="循环次数">
            <button id="runButton" class="primary">执行 N 轮</button>
          </div>
          <button id="resumeButton">继续任务</button>
          <button id="stopButton" class="danger">停止任务</button>
        </div>
        <div class="metric-grid">
          <div class="metric"><div class="label">连接状态</div><div id="sessionMetric" class="value">-</div></div>
          <div class="metric"><div class="label">执行进度</div><div id="progressMetric" class="value">-</div></div>
          <div class="metric"><div class="label">默认参数</div><div id="runMetric" class="value">-</div></div>
        </div>
      </div>
    </section>

    <section class="panel">
      <div class="panel-title"><h2>A-F 坐标与等待</h2></div>
      <table>
        <thead>
          <tr>
            <th>点</th>
            <th>x</th>
            <th>y</th>
            <th>点击后等待</th>
          </tr>
        </thead>
        <tbody id="sequenceRows"></tbody>
      </table>
    </section>

    <section class="panel wide">
      <div class="panel-title"><h2>工作流拓扑</h2></div>
      <div class="panel-body">
        <div class="workflow-board">
          <div id="workflowCanvas" class="workflow-canvas">
            <div id="workflowCanvasInner" class="workflow-canvas-inner">
              <svg id="workflowEdges" class="workflow-edges" aria-hidden="true"></svg>
              <div id="workflowNodes" class="workflow-nodes"></div>
            </div>
          </div>
          <div id="workflowDetail" class="workflow-detail"></div>
        </div>
      </div>
    </section>

    <section class="panel wide">
      <div class="panel-title">
        <h2>工作流配置</h2>
        <div class="log-actions">
          <button id="loadWorkflowButton" class="compact">加载当前</button>
          <button id="validateWorkflowButton" class="compact">校验</button>
          <button id="saveWorkflowButton" class="compact primary">保存</button>
          <button id="clearWorkflowButton" class="compact danger">清除自定义</button>
        </div>
      </div>
      <div class="panel-body">
        <textarea id="workflowEditor" class="workflow-editor" spellcheck="false" aria-label="工作流 JSON"></textarea>
        <div id="workflowEditorStatus" class="workflow-editor-status">未加载</div>
      </div>
    </section>

    <section class="panel">
      <div class="panel-title"><h2>连接摘要</h2></div>
      <div class="panel-body">
        <div class="metric-grid">
          <div class="metric"><div class="label">iPhone</div><div id="deviceMetric" class="value">-</div></div>
          <div class="metric"><div class="label">Automation</div><div id="automationMetric" class="value">-</div></div>
          <div class="metric"><div class="label">Appium</div><div id="appiumMetric" class="value">-</div></div>
          <div class="metric"><div class="label">Workflow</div><div id="workflowMetric" class="value">-</div></div>
        </div>
      </div>
    </section>

    <section class="panel wide">
      <div class="panel-title"><h2>全链路事件</h2></div>
      <div class="panel-body">
        <div id="timeline" class="timeline"></div>
      </div>
    </section>

    <section class="panel wide">
      <div class="panel-title"><h2>失败热力图</h2></div>
      <div class="panel-body">
        <div id="heatmap" class="heatmap"></div>
      </div>
    </section>

    <section class="panel wide">
      <div class="panel-title">
        <h2>诊断日志</h2>
        <div class="log-actions">
          <button id="copyLogButton" class="compact">复制所有</button>
          <button id="clearLogButton" class="compact danger">清除所有</button>
        </div>
      </div>
      <div id="log" class="log"></div>
    </section>
  </main>

  <script>
    const elements = {
      deviceBadge: document.getElementById('deviceBadge'),
      wdaBadge: document.getElementById('wdaBadge'),
      runBadge: document.getElementById('runBadge'),
      heroTitle: document.getElementById('heroTitle'),
      heroText: document.getElementById('heroText'),
      issueBox: document.getElementById('issueBox'),
      connectButton: document.getElementById('connectButton'),
      reconnectButton: document.getElementById('reconnectButton'),
      disconnectButton: document.getElementById('disconnectButton'),
      refreshButton: document.getElementById('refreshButton'),
      screenshotButton: document.getElementById('screenshotButton'),
      visualButton: document.getElementById('visualButton'),
      deviceFrame: document.getElementById('deviceFrame'),
      deviceEmpty: document.getElementById('deviceEmpty'),
      screenshotImage: document.getElementById('screenshotImage'),
      tapDot: document.getElementById('tapDot'),
      screenshotMetric: document.getElementById('screenshotMetric'),
      tapMetric: document.getElementById('tapMetric'),
      errorMetric: document.getElementById('errorMetric'),
      visualMetric: document.getElementById('visualMetric'),
      testButton: document.getElementById('testButton'),
      runButton: document.getElementById('runButton'),
      resumeButton: document.getElementById('resumeButton'),
      stopButton: document.getElementById('stopButton'),
      loopsInput: document.getElementById('loopsInput'),
      sessionMetric: document.getElementById('sessionMetric'),
      progressMetric: document.getElementById('progressMetric'),
      runMetric: document.getElementById('runMetric'),
      sequenceRows: document.getElementById('sequenceRows'),
      deviceMetric: document.getElementById('deviceMetric'),
      automationMetric: document.getElementById('automationMetric'),
      appiumMetric: document.getElementById('appiumMetric'),
      workflowMetric: document.getElementById('workflowMetric'),
      workflowCanvas: document.getElementById('workflowCanvas'),
      workflowCanvasInner: document.getElementById('workflowCanvasInner'),
      workflowEdges: document.getElementById('workflowEdges'),
      workflowNodes: document.getElementById('workflowNodes'),
      workflowDetail: document.getElementById('workflowDetail'),
      workflowEditor: document.getElementById('workflowEditor'),
      workflowEditorStatus: document.getElementById('workflowEditorStatus'),
      loadWorkflowButton: document.getElementById('loadWorkflowButton'),
      validateWorkflowButton: document.getElementById('validateWorkflowButton'),
      saveWorkflowButton: document.getElementById('saveWorkflowButton'),
      clearWorkflowButton: document.getElementById('clearWorkflowButton'),
      timeline: document.getElementById('timeline'),
      heatmap: document.getElementById('heatmap'),
      log: document.getElementById('log'),
      copyLogButton: document.getElementById('copyLogButton'),
      clearLogButton: document.getElementById('clearLogButton'),
    };

    let latestStatus = null;
    let logEntries = [];
    let runEvents = [];
    let evidence = { lastScreenshot: null, lastTap: null, lastError: null, lastVisual: null };
    let selectedWorkflowNodeId = null;
    let workflowEditorDirty = false;
    let lastEventStreamErrorAt = 0;
    let workflowLayoutKey = '';
    let workflowNodePositions = new Map();
    let workflowDrag = null;

    function escapeHtml(value) {
      return String(value ?? '')
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    }

    function setBadge(el, text, tone) {
      el.className = tone ? 'badge ' + tone : 'badge';
      el.textContent = text;
    }

    function shortTime(value) {
      return value ? String(value).replace('T', ' ').replace('Z', '').slice(11, 23) : '-';
    }

    function eventLabel(event) {
      if (!event || typeof event !== 'object') return '未知事件';
      if (event.type === 'runStart') return '任务开始：' + event.loops + ' 轮';
      if (event.type === 'runEnd') {
        if (event.status === 'error') return '任务异常结束';
        return event.stopped ? '任务安全停止' : '任务完成';
      }
      if (event.type === 'runError') return '任务失败：' + event.message;
      if (event.type === 'loopStart') return '第 ' + event.loopNumber + '/' + event.loops + ' 轮开始';
      if (event.type === 'loopEnd') return '第 ' + event.loopNumber + '/' + event.loops + ' 轮结束';
      if (event.type === 'stepStart') return '步骤 ' + event.stepNumber + ' 开始：' + stepLabel(event.step);
      if (event.type === 'stepEnd') return '步骤 ' + event.stepNumber + ' 结束：' + stepLabel(event.step);
      if (event.type === 'screenshot') return '截图：' + (event.reason || 'manual');
      if (event.type === 'visualAnalysis') return '视觉分析：' + (event.analysis?.decision?.reason || event.reason || 'screen');
      if (event.type === 'runPaused') return '任务挂起：' + (event.reason || '等待人工处理');
      if (event.type === 'runResumed') return '任务继续';
      if (event.type === 'runtimeWarning') return '运行警告：' + event.message;
      return event.type;
    }

    function stepLabel(step) {
      if (!step) return '-';
      if (step.type === 'tap') return (step.label || 'tap') + ' (' + step.x + ', ' + step.y + ')';
      if (step.type === 'wait') return 'wait ' + step.ms + 'ms';
      if (step.type === 'waitRandom') return 'wait ' + step.minMs + '-' + step.maxMs + 'ms';
      return step.type;
    }

    function renderTimeline() {
      elements.timeline.textContent = '';
      const visible = (Array.isArray(runEvents) ? runEvents : []).slice(-80).reverse();
      if (visible.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'muted';
        empty.textContent = '暂无执行事件';
        elements.timeline.appendChild(empty);
        return;
      }
      for (const entry of visible) {
        const row = document.createElement('div');
        row.className = 'event-row ' + (['error', 'ok', 'warning', 'paused'].includes(entry.status) ? entry.status : '');
        row.innerHTML = '<div class="event-time">' + escapeHtml(shortTime(entry.at)) + '</div>'
          + '<div class="event-main">' + escapeHtml(eventLabel(entry)) + '</div>'
          + '<div class="muted">' + escapeHtml(entry.durationMs != null ? entry.durationMs + 'ms' : '') + '</div>';
        elements.timeline.appendChild(row);
      }
    }

    function heatmapEntryFor(event) {
      if (!event || typeof event !== 'object' || event.status !== 'error') {
        return null;
      }
      const step = event.step;
      if (step?.type === 'tap') {
        return {
          key: 'tap:' + (step.label || '-') + ':' + step.x + ':' + step.y,
          label: (step.label || 'tap') + ' (' + step.x + ', ' + step.y + ')',
          detail: event.nodeId ? 'node ' + event.nodeId : (event.type || 'event'),
        };
      }
      if (event.nodeId) {
        return {
          key: 'node:' + event.nodeId,
          label: 'node ' + event.nodeId,
          detail: event.type || 'event',
        };
      }
      return null;
    }

    function renderHeatmap() {
      elements.heatmap.textContent = '';
      const stats = new Map();
      for (const event of Array.isArray(runEvents) ? runEvents : []) {
        const entry = heatmapEntryFor(event);
        if (!entry) continue;
        const current = stats.get(entry.key) || { ...entry, count: 0 };
        current.count += 1;
        current.detail = entry.detail;
        stats.set(entry.key, current);
      }
      const rows = Array.from(stats.values())
        .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label))
        .slice(0, 12);
      if (rows.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'muted';
        empty.textContent = '暂无失败坐标或失败节点';
        elements.heatmap.appendChild(empty);
        return;
      }
      const max = Math.max(...rows.map((row) => row.count), 1);
      for (const item of rows) {
        const row = document.createElement('div');
        row.className = 'heatmap-row';
        const width = Math.max(10, Math.round((item.count / max) * 100));
        row.innerHTML = '<div class="heatmap-main">'
          + '<div class="heatmap-label">' + escapeHtml(item.label) + '</div>'
          + '<div class="muted">' + escapeHtml(item.detail) + '</div>'
          + '<div class="heatmap-bar" style="width:' + width + '%"></div>'
          + '</div>'
          + '<div class="heatmap-count">' + escapeHtml(item.count) + '</div>';
        elements.heatmap.appendChild(row);
      }
    }

    function renderEvidence() {
      const screenshot = evidence.lastScreenshot;
      const tap = evidence.lastTap;
      const lastError = evidence.lastError;
      const lastVisual = evidence.lastVisual;

      if (screenshot?.dataUrl) {
        elements.screenshotImage.src = screenshot.dataUrl;
        elements.screenshotImage.hidden = false;
        elements.deviceEmpty.hidden = true;
        elements.screenshotMetric.textContent = shortTime(screenshot.at) + ' / ' + screenshot.reason;
        if (screenshot.file?.path) {
          elements.screenshotMetric.title = screenshot.file.path;
        }
      } else {
        elements.screenshotImage.removeAttribute('src');
        elements.screenshotImage.hidden = true;
        elements.deviceEmpty.hidden = false;
        elements.screenshotMetric.textContent = '-';
        elements.screenshotMetric.removeAttribute('title');
      }

      if (tap?.x != null && tap?.y != null) {
        elements.tapMetric.textContent = (tap.label || 'tap') + ' (' + tap.x + ', ' + tap.y + ')';
        positionTapDot();
      } else {
        elements.tapMetric.textContent = '-';
        elements.tapDot.hidden = true;
      }

      elements.errorMetric.textContent = lastError?.message || '-';
      if (lastVisual?.decision) {
        elements.visualMetric.textContent = lastVisual.decision.action + ' / ' + Math.round(lastVisual.decision.confidence * 100) + '%';
        elements.visualMetric.title = lastVisual.decision.reason || '';
      } else {
        elements.visualMetric.textContent = '-';
        elements.visualMetric.removeAttribute('title');
      }
    }

    function workflowEdgesFor(node, workflow) {
      return (workflow?.edges || []).filter((edge) => edge.from === node.id);
    }

    function resetWorkflowLayoutIfNeeded(nodes, workflow) {
      const key = (workflow?.id || 'workflow') + ':' + nodes.map((node) => node.id + ':' + node.type).join('|');
      if (key !== workflowLayoutKey) {
        workflowLayoutKey = key;
        workflowNodePositions = new Map();
      }
    }

    function computeWorkflowColumns(nodes, workflow) {
      const nodeIds = new Set(nodes.map((node) => node.id));
      const outgoing = new Map();
      for (const edge of workflow?.edges || []) {
        if (!nodeIds.has(edge.from) || !nodeIds.has(edge.to)) continue;
        if (!outgoing.has(edge.from)) outgoing.set(edge.from, []);
        outgoing.get(edge.from).push(edge.to);
      }

      const levels = new Map();
      const entry = workflow?.entry && nodeIds.has(workflow.entry) ? workflow.entry : nodes[0]?.id;
      const queue = entry ? [entry] : [];
      if (entry) levels.set(entry, 0);
      while (queue.length > 0) {
        const id = queue.shift();
        const level = levels.get(id) ?? 0;
        for (const next of outgoing.get(id) || []) {
          const nextLevel = level + 1;
          if (!levels.has(next) || nextLevel > levels.get(next)) {
            levels.set(next, nextLevel);
            queue.push(next);
          }
        }
      }

      let fallbackLevel = 0;
      for (const node of nodes) {
        if (!levels.has(node.id)) {
          levels.set(node.id, fallbackLevel);
          fallbackLevel += 1;
        }
      }
      return levels;
    }

    function ensureWorkflowNodePositions(nodes, workflow) {
      resetWorkflowLayoutIfNeeded(nodes, workflow);
      const levels = computeWorkflowColumns(nodes, workflow);
      const rowsByLevel = new Map();
      for (const node of nodes) {
        const level = levels.get(node.id) ?? 0;
        const row = rowsByLevel.get(level) ?? 0;
        rowsByLevel.set(level, row + 1);
        if (!workflowNodePositions.has(node.id)) {
          workflowNodePositions.set(node.id, {
            left: 24 + level * 184,
            top: 24 + row * 128,
          });
        }
      }

      resizeWorkflowCanvasToPositions();
    }

    function resizeWorkflowCanvasToPositions() {
      let maxLeft = 360;
      let maxTop = 300;
      for (const position of workflowNodePositions.values()) {
        maxLeft = Math.max(maxLeft, position.left + 184);
        maxTop = Math.max(maxTop, position.top + 128);
      }
      elements.workflowCanvasInner.style.width = maxLeft + 'px';
      elements.workflowCanvasInner.style.height = maxTop + 'px';
      elements.workflowEdges.setAttribute('width', String(maxLeft));
      elements.workflowEdges.setAttribute('height', String(maxTop));
      elements.workflowEdges.setAttribute('viewBox', '0 0 ' + maxLeft + ' ' + maxTop);
    }

    function renderWorkflowEdges(workflow) {
      elements.workflowEdges.textContent = '';
      const svgNs = 'http://www.w3.org/2000/svg';
      for (const edge of workflow?.edges || []) {
        const from = workflowNodePositions.get(edge.from);
        const to = workflowNodePositions.get(edge.to);
        if (!from || !to) continue;
        const x1 = from.left + 144;
        const y1 = from.top + 46;
        const x2 = to.left;
        const y2 = to.top + 46;
        const curve = Math.max(42, Math.abs(x2 - x1) / 2);
        const path = document.createElementNS(svgNs, 'path');
        path.setAttribute('class', 'workflow-edge ' + edge.kind);
        path.setAttribute('d', 'M ' + x1 + ' ' + y1 + ' C ' + (x1 + curve) + ' ' + y1 + ', ' + (x2 - curve) + ' ' + y2 + ', ' + x2 + ' ' + y2);
        const title = document.createElementNS(svgNs, 'title');
        title.textContent = edge.kind + ': ' + edge.from + ' -> ' + edge.to;
        path.appendChild(title);
        elements.workflowEdges.appendChild(path);
      }
    }

    function applyWorkflowNodePosition(button, nodeId) {
      const position = workflowNodePositions.get(nodeId);
      if (!position) return;
      button.style.left = position.left + 'px';
      button.style.top = position.top + 'px';
    }

    function stopWorkflowDrag() {
      if (!workflowDrag) return;
      const drag = workflowDrag;
      workflowDrag = null;
      drag.button.classList.remove('dragging');
      document.removeEventListener('pointermove', moveWorkflowDrag);
      document.removeEventListener('pointerup', stopWorkflowDrag);
      document.removeEventListener('pointercancel', stopWorkflowDrag);
      if (drag.moved) {
        drag.button.dataset.dragged = 'true';
        setTimeout(() => {
          drag.button.dataset.dragged = 'false';
        }, 0);
      }
    }

    function moveWorkflowDrag(event) {
      if (!workflowDrag) return;
      const dx = event.clientX - workflowDrag.startX;
      const dy = event.clientY - workflowDrag.startY;
      if (Math.abs(dx) > 3 || Math.abs(dy) > 3) {
        workflowDrag.moved = true;
      }
      const position = {
        left: Math.max(12, workflowDrag.startLeft + dx),
        top: Math.max(12, workflowDrag.startTop + dy),
      };
      workflowNodePositions.set(workflowDrag.nodeId, position);
      applyWorkflowNodePosition(workflowDrag.button, workflowDrag.nodeId);
      resizeWorkflowCanvasToPositions();
      renderWorkflowEdges(workflowDrag.workflow);
    }

    function startWorkflowDrag(event, nodeId, button, workflow) {
      if (event.button !== 0) return;
      const position = workflowNodePositions.get(nodeId);
      if (!position) return;
      event.preventDefault();
      workflowDrag = {
        nodeId,
        button,
        workflow,
        startX: event.clientX,
        startY: event.clientY,
        startLeft: position.left,
        startTop: position.top,
        moved: false,
      };
      button.dataset.dragged = 'false';
      button.classList.add('dragging');
      document.addEventListener('pointermove', moveWorkflowDrag);
      document.addEventListener('pointerup', stopWorkflowDrag);
      document.addEventListener('pointercancel', stopWorkflowDrag);
    }

    function renderWorkflowDetail(node, workflow) {
      elements.workflowDetail.textContent = '';
      if (!node) {
        const empty = document.createElement('div');
        empty.className = 'muted';
        empty.textContent = '选择一个节点查看参数';
        elements.workflowDetail.appendChild(empty);
        return;
      }

      const title = document.createElement('div');
      title.innerHTML = '<span class="badge info">' + escapeHtml(node.type) + '</span>';
      elements.workflowDetail.appendChild(title);

      const name = document.createElement('div');
      name.className = 'metric';
      name.innerHTML = '<div class="label">节点</div><div class="value">' + escapeHtml(node.id + ' / ' + node.label) + '</div>';
      elements.workflowDetail.appendChild(name);

      const edges = workflowEdgesFor(node, workflow);
      const edgeWrap = document.createElement('div');
      edgeWrap.className = 'edge-list';
      if (edges.length === 0) {
        edgeWrap.innerHTML = '<span class="edge-chip">end</span>';
      } else {
        edgeWrap.innerHTML = edges.map((edge) => '<span class="edge-chip">' + escapeHtml(edge.kind + ' -> ' + edge.to) + '</span>').join('');
      }
      elements.workflowDetail.appendChild(edgeWrap);

      const params = document.createElement('pre');
      params.textContent = JSON.stringify(node.params || {}, null, 2);
      elements.workflowDetail.appendChild(params);
    }

    function renderWorkflow(payload) {
      const workflow = payload.config?.workflow;
      const nodes = workflow?.nodes || [];
      elements.workflowNodes.textContent = '';
      if (nodes.length === 0) {
        const empty = document.createElement('div');
        empty.className = 'muted';
        empty.textContent = '暂无工作流节点';
        elements.workflowNodes.appendChild(empty);
        elements.workflowEdges.textContent = '';
        renderWorkflowDetail(null, workflow);
        return;
      }

      ensureWorkflowNodePositions(nodes, workflow);
      if (!selectedWorkflowNodeId || !nodes.some((node) => node.id === selectedWorkflowNodeId)) {
        selectedWorkflowNodeId = payload.run?.currentStep?.nodeId || workflow.entry || nodes[0].id;
      }
      const currentNodeId = payload.run?.currentStep?.nodeId;
      for (const node of nodes) {
        const button = document.createElement('button');
        button.className = 'workflow-node'
          + (node.id === currentNodeId ? ' current' : '')
          + (node.id === selectedWorkflowNodeId ? ' selected' : '');
        button.innerHTML = '<div class="node-id">' + escapeHtml(node.id) + '</div>'
          + '<div class="node-type">' + escapeHtml(node.type) + '</div>'
          + '<div class="node-label">' + escapeHtml(node.label) + '</div>';
        button.addEventListener('pointerdown', (event) => startWorkflowDrag(event, node.id, button, workflow));
        button.addEventListener('click', () => {
          if (button.dataset.dragged === 'true') return;
          selectedWorkflowNodeId = node.id;
          renderWorkflow(latestStatus);
        });
        applyWorkflowNodePosition(button, node.id);
        elements.workflowNodes.appendChild(button);
      }
      renderWorkflowEdges(workflow);
      renderWorkflowDetail(nodes.find((node) => node.id === selectedWorkflowNodeId), workflow);
    }

    function setWorkflowEditorStatus(message, tone) {
      elements.workflowEditorStatus.className = 'workflow-editor-status' + (tone ? ' ' + tone : '');
      elements.workflowEditorStatus.textContent = message;
    }

    function parseWorkflowEditor() {
      try {
        const workflow = JSON.parse(elements.workflowEditor.value);
        if (!workflow || typeof workflow !== 'object' || Array.isArray(workflow)) {
          throw new Error('workflow must be a JSON object');
        }
        return workflow;
      } catch (error) {
        setWorkflowEditorStatus(error.message, 'danger');
        appendLog({ at: new Date().toISOString(), stream: 'system', message: 'Workflow JSON invalid: ' + error.message });
        return null;
      }
    }

    async function getJson(url) {
      try {
        const response = await fetch(url, { cache: 'no-store' });
        let payload;
        try {
          payload = await response.json();
        } catch {
          payload = { error: 'request failed' };
        }
        if (!response.ok) {
          appendSystemLog(payload.error || 'request failed');
        }
        return payload;
      } catch (error) {
        const payload = { error: 'request failed: ' + error.message };
        appendSystemLog(payload.error);
        return payload;
      }
    }

    async function loadWorkflowEditor() {
      const payload = await getJson('/api/workflow');
      if (!payload.workflow) {
        const errors = payload.validation?.errors || [];
        setWorkflowEditorStatus(payload.error || errors.join(' / ') || '加载失败', 'danger');
        return;
      }
      elements.workflowEditor.value = JSON.stringify(payload.workflow, null, 2);
      workflowEditorDirty = false;
      const summary = payload.validation?.summary;
      setWorkflowEditorStatus(
        payload.validation?.ok
          ? '已加载 / ' + (summary?.nodeCount ?? 0) + ' nodes'
          : '已加载但校验失败',
        payload.validation?.ok ? 'ok' : 'danger',
      );
    }

    async function validateWorkflowEditor() {
      const workflow = parseWorkflowEditor();
      if (!workflow) return;
      const payload = await postJson('/api/workflow/validate', { workflow });
      if (payload.ok) {
        setWorkflowEditorStatus('校验通过 / ' + (payload.summary?.nodeCount ?? 0) + ' nodes', 'ok');
      } else {
        setWorkflowEditorStatus('校验失败：' + (payload.errors || []).join(' / '), 'danger');
      }
    }

    async function saveWorkflowEditor() {
      const workflow = parseWorkflowEditor();
      if (!workflow) return;
      const payload = await postJson('/api/workflow', { workflow });
      if (payload.ok) {
        workflowEditorDirty = false;
        setWorkflowEditorStatus('已保存 / ' + (payload.summary?.nodeCount ?? 0) + ' nodes', 'ok');
        await refreshStatus();
      } else if (payload.error) {
        setWorkflowEditorStatus(payload.error, 'danger');
      }
    }

    async function clearWorkflowEditor() {
      const payload = await postJson('/api/workflow/clear');
      if (payload.ok) {
        setWorkflowEditorStatus('已清除自定义 workflow，回到基础序列模板', 'warn');
        await loadWorkflowEditor();
        await refreshStatus();
      } else if (payload.error) {
        setWorkflowEditorStatus(payload.error, 'danger');
      }
    }

    function positionTapDot() {
      const tap = evidence.lastTap;
      const image = elements.screenshotImage;
      if (!tap || image.hidden || !image.naturalWidth || !image.naturalHeight) {
        elements.tapDot.hidden = true;
        return;
      }
      const left = Math.max(0, Math.min(100, (tap.x / image.naturalWidth) * 100));
      const top = Math.max(0, Math.min(100, (tap.y / image.naturalHeight) * 100));
      elements.tapDot.hidden = false;
      elements.tapDot.style.left = left + '%';
      elements.tapDot.style.top = top + '%';
    }

    function isBusy(session, run) {
      return ['initializing', 'connecting', 'waitingForDeveloperTrust', 'disconnecting'].includes(session.phase)
        || run.active;
    }

    function phaseTitle(session) {
      if (session.phase === 'connected') return '已连接，可执行';
      if (session.phase === 'initializing') return '正在初始化设备';
      if (session.phase === 'connecting') return '正在连接 WDA';
      if (session.phase === 'waitingForDeveloperTrust') return '等待信任开发者证书';
      if (session.phase === 'disconnecting') return '正在断开连接';
      if (session.phase === 'error') return '连接需要处理';
      return '准备连接';
    }

    function phaseText(session) {
      if (session.phase === 'connected') return 'Appium、WDA 和 WebDriver 会话保持常驻。后续点击会直接发送到当前连接。';
      if (session.phase === 'initializing') return '正在发现 USB iPhone，并写入当前设备初始化标记。';
      if (session.phase === 'connecting') return '正在启动或复用 Appium，并创建 WebDriverAgent 会话。';
      if (session.phase === 'waitingForDeveloperTrust') {
        const limit = session.trustRetryLimit ?? '-';
        const count = session.trustRetryCount ?? 0;
        return '请在 iPhone 上打开 设置 -> 通用 -> VPN 与设备管理，信任开发者证书。看板会在限定次数内自动重试：' + count + '/' + limit + '。';
      }
      if (session.phase === 'disconnecting') return '正在释放 WebDriver 会话，并关闭本看板启动的 Appium。';
      if (session.phase === 'error') return session.error?.message || '连接失败，请查看提示或诊断日志。';
      return '点击初始化并连接后，看板会完成设备发现、WDA 预热和常驻连接。';
    }

    function renderIssue(session) {
      if (!session.error) {
        elements.issueBox.style.display = 'none';
        elements.issueBox.textContent = '';
        return;
      }
      elements.issueBox.style.display = 'block';
      elements.issueBox.innerHTML = '<strong>' + escapeHtml(session.error.message) + '</strong>'
        + escapeHtml(session.error.userAction || '查看诊断日志获取更多信息。');
    }

    function renderStatus(payload) {
      latestStatus = payload;
      const { session, run, config, appium } = payload;
      const hasDevice = config.configuredDeviceConnected;
      const busy = isBusy(session, run);
      const connected = session.phase === 'connected';
      const paused = run.status === 'paused';
      const deviceCommandBusy = payload.operations?.deviceCommand?.active === true;

      setBadge(elements.deviceBadge, hasDevice ? 'iPhone 已连接' : 'iPhone 未连接', hasDevice ? 'ok' : 'danger');
      if (session.phase === 'waitingForDeveloperTrust') {
        setBadge(elements.wdaBadge, '等待证书信任 ' + (session.trustRetryCount ?? 0) + '/' + (session.trustRetryLimit ?? '-'), 'warn');
      } else if (connected) {
        setBadge(elements.wdaBadge, 'WDA 已连接', 'ok');
      } else if (['initializing', 'connecting'].includes(session.phase)) {
        setBadge(elements.wdaBadge, '连接中', 'info');
      } else {
        setBadge(elements.wdaBadge, 'WDA 未连接', session.phase === 'error' ? 'danger' : '');
      }
      setBadge(elements.runBadge, paused ? '任务挂起' : (run.active ? '任务运行中' : '任务空闲'), paused ? 'danger' : (run.active ? 'warn' : 'ok'));

      const loading = ['initializing', 'connecting', 'waitingForDeveloperTrust', 'disconnecting'].includes(session.phase);
      elements.heroTitle.innerHTML = (loading ? '<span class="spinner"></span>' : '') + escapeHtml(phaseTitle(session));
      elements.heroText.textContent = phaseText(session);
      renderIssue(session);

      const workflowWriteBusy = payload.operations?.workflowWriteInProgress === true;
      elements.connectButton.disabled = busy || connected || workflowWriteBusy;
      elements.reconnectButton.disabled = run.active || workflowWriteBusy || deviceCommandBusy || ['initializing', 'connecting', 'disconnecting'].includes(session.phase);
      elements.disconnectButton.disabled = session.phase === 'disconnected' || run.active || workflowWriteBusy || deviceCommandBusy;
      elements.screenshotButton.disabled = !connected || run.active || deviceCommandBusy;
      elements.visualButton.disabled = !connected || run.active || deviceCommandBusy;
      elements.testButton.disabled = !connected || run.active || workflowWriteBusy || deviceCommandBusy;
      elements.runButton.disabled = !connected || run.active || workflowWriteBusy || deviceCommandBusy;
      elements.resumeButton.disabled = !paused;
      elements.stopButton.disabled = !run.active;
      elements.saveWorkflowButton.disabled = busy || workflowWriteBusy;
      elements.clearWorkflowButton.disabled = busy || workflowWriteBusy;

      elements.sessionMetric.textContent = connected
        ? '常驻连接'
        : session.phase;
      elements.progressMetric.textContent = run.active
        ? run.completedLoops + '/' + run.loops + ' 轮' + (paused ? ' / 挂起' : '')
        : '空闲';
      elements.runMetric.textContent = 'tap ' + config.run.tapDurationMs + 'ms';
      elements.deviceMetric.textContent = config.configuredUdidSummary || '-';
      elements.automationMetric.textContent = config.automationName || '-';
      elements.appiumMetric.textContent = appium.ready ? 'ready' : (connected ? '会话中' : '未运行');
      elements.workflowMetric.textContent = config.workflow
        ? config.workflow.nodeCount + ' nodes / ' + (config.workflow.linear ? 'linear' : 'graph')
        : '-';
      evidence = payload.evidence || evidence;
      runEvents = payload.runEvents || runEvents;
      renderEvidence();
      renderTimeline();
      renderHeatmap();
      renderWorkflow(payload);

      elements.sequenceRows.textContent = '';
      for (const step of config.sequence) {
        const row = document.createElement('tr');
        if (
          run.currentStep?.type === 'tap'
          && run.currentStep.label === step.label
          && run.currentStep.x === step.x
          && run.currentStep.y === step.y
        ) {
          row.className = 'current-step';
        }
        row.innerHTML = '<td>' + escapeHtml(step.label) + '</td>'
          + '<td>' + escapeHtml(step.x) + '</td>'
          + '<td>' + escapeHtml(step.y) + '</td>'
          + '<td>' + escapeHtml(step.waitAfter ?? '-') + '</td>';
        elements.sequenceRows.appendChild(row);
      }
    }

    function formatLog(entry) {
      const at = String(entry?.at ?? new Date().toISOString()).replace('T', ' ').replace('Z', '');
      return '[' + at + '] '
        + (entry?.stream || 'system') + '  ' + (entry?.message || '');
    }

    function appendLogElement(entry) {
      const line = document.createElement('div');
      line.className = entry?.stream || 'system';
      line.textContent = formatLog(entry);
      elements.log.appendChild(line);
      elements.log.scrollTop = elements.log.scrollHeight;
    }

    function appendLog(entry) {
      logEntries.push(entry);
      appendLogElement(entry);
    }

    function appendSystemLog(message) {
      appendLog({ at: new Date().toISOString(), stream: 'system', message });
    }

    function renderLogs(entries) {
      logEntries = Array.isArray(entries) ? entries.slice() : [];
      elements.log.textContent = '';
      logEntries.forEach(appendLogElement);
    }

    async function refreshStatus() {
      try {
        const response = await fetch('/api/status', { cache: 'no-store' });
        const payload = await response.json();
        if (!response.ok || payload.error) {
          appendSystemLog(payload.error || 'Status refresh failed');
          return;
        }
        renderStatus(payload);
      } catch (error) {
        appendSystemLog('Status refresh failed: ' + error.message);
      }
    }

    async function postJson(url, body = {}) {
      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify(body),
        });
        let payload;
        try {
          payload = await response.json();
        } catch {
          payload = { error: 'request failed' };
        }
        if (!response.ok) {
          appendSystemLog(payload.error || 'request failed');
        }
        await refreshStatus();
        return payload;
      } catch (error) {
        const payload = { error: 'request failed: ' + error.message };
        appendSystemLog(payload.error);
        return payload;
      }
    }

    elements.connectButton.addEventListener('click', () => postJson('/api/connect'));
    elements.reconnectButton.addEventListener('click', () => postJson('/api/reconnect'));
    elements.disconnectButton.addEventListener('click', () => postJson('/api/disconnect'));
    elements.refreshButton.addEventListener('click', refreshStatus);
    elements.screenshotButton.addEventListener('click', () => postJson('/api/screenshot', { reason: 'manual' }));
    elements.visualButton.addEventListener('click', () => postJson('/api/visual/analyze', { reason: 'manual' }));
    elements.screenshotImage.addEventListener('load', positionTapDot);
    elements.testButton.addEventListener('click', () => postJson('/api/run', { loops: 1 }));
    elements.runButton.addEventListener('click', () => postJson('/api/run', { loops: elements.loopsInput.value }));
    elements.resumeButton.addEventListener('click', () => postJson('/api/resume'));
    elements.stopButton.addEventListener('click', () => postJson('/api/stop'));
    elements.workflowEditor.addEventListener('input', () => {
      workflowEditorDirty = true;
      setWorkflowEditorStatus('已修改，未保存', 'warn');
    });
    elements.loadWorkflowButton.addEventListener('click', loadWorkflowEditor);
    elements.validateWorkflowButton.addEventListener('click', validateWorkflowEditor);
    elements.saveWorkflowButton.addEventListener('click', saveWorkflowEditor);
    elements.clearWorkflowButton.addEventListener('click', clearWorkflowEditor);
    elements.copyLogButton.addEventListener('click', async () => {
      const text = logEntries.map(formatLog).join('\\n');
      try {
        await navigator.clipboard.writeText(text);
      } catch {
        const textarea = document.createElement('textarea');
        textarea.value = text;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        textarea.remove();
      }
      const original = elements.copyLogButton.textContent;
      elements.copyLogButton.textContent = '已复制';
      setTimeout(() => {
        elements.copyLogButton.textContent = original;
      }, 1200);
    });
    elements.clearLogButton.addEventListener('click', () => postJson('/api/logs/clear'));

    function handleRealtimePayload(payload) {
      if (!payload || typeof payload !== 'object') {
        throw new Error('Realtime event payload must be an object');
      }
      if (payload.type === 'snapshot') {
        renderLogs(payload.logs);
        runEvents = Array.isArray(payload.runEvents) ? payload.runEvents : [];
        evidence = payload.evidence || evidence;
        renderTimeline();
        renderHeatmap();
        renderEvidence();
        refreshStatus();
        return;
      }
      if (payload.type === 'log') {
        appendLog(payload.entry || { at: new Date().toISOString(), stream: 'system', message: 'Malformed log event received.' });
        return;
      }
      if (payload.type === 'logsCleared') {
        renderLogs([]);
        return;
      }
      if (payload.type === 'runEvent') {
        if (!payload.entry || typeof payload.entry !== 'object') {
          throw new Error('runEvent entry must be an object');
        }
        runEvents.push(payload.entry);
        if (runEvents.length > 300) runEvents = runEvents.slice(-300);
        evidence = payload.evidence || evidence;
        renderTimeline();
        renderHeatmap();
        renderEvidence();
        return;
      }
      if (payload.type === 'evidence') {
        evidence = payload.evidence || evidence;
        renderEvidence();
        return;
      }
      if (payload.type === 'status') {
        refreshStatus();
      }
    }

    const events = new EventSource('/api/events');
    events.onmessage = (event) => {
      let payload;
      try {
        payload = JSON.parse(event.data);
      } catch (error) {
        appendSystemLog('Realtime event parse failed: ' + error.message);
        return;
      }
      try {
        handleRealtimePayload(payload);
      } catch (error) {
        appendSystemLog('Realtime event handling failed: ' + error.message);
      }
    };
    events.onerror = () => {
      const now = Date.now();
      if (now - lastEventStreamErrorAt > 5000) {
        lastEventStreamErrorAt = now;
        appendSystemLog('Realtime event stream disconnected. The browser will retry automatically.');
      }
    };

    refreshStatus();
    loadWorkflowEditor();
    setInterval(() => {
      if (!latestStatus || !isBusy(latestStatus.session, latestStatus.run)) {
        refreshStatus();
      }
    }, 5000);
  </script>
</body>
</html>`;
}

async function handleRequest(options, request, response) {
  try {
    const url = new URL(request.url, `http://${request.headers.host ?? '127.0.0.1'}`);

    if (request.method === 'GET' && url.pathname === '/') {
      response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      response.end(consoleHtml());
      return;
    }
    if (request.method === 'GET' && url.pathname === '/api/status') {
      sendJson(response, 200, await statusPayload(options.config));
      return;
    }
    if (request.method === 'GET' && url.pathname === '/api/workflow') {
      let config;
      try {
        config = await readJson(options.config);
      } catch (error) {
        sendJson(response, 200, workflowConfigErrorPayload(error));
        return;
      }
      sendJson(response, 200, workflowPayload(config));
      return;
    }
    if (request.method === 'GET' && url.pathname === '/api/analytics/heatmap') {
      sendJson(response, 200, failureHeatmapPayload());
      return;
    }
    if (request.method === 'GET' && (url.pathname === '/api/events' || url.pathname === '/api/logs')) {
      serveEvents(request, response);
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/workflow/validate') {
      const workflow = workflowFromBody(await readBody(request));
      const result = validateWorkflow(workflow);
      sendJson(response, 200, result);
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/workflow') {
      await withWorkflowWriteLock(async () => {
        const workflow = workflowFromBody(await readBody(request));
        const result = validateWorkflow(workflow);
        if (!result.ok) {
          sendJson(response, 400, result);
          return;
        }
        assertWorkflowLifecycleWritable();
        const config = await readJson(options.config);
        config.workflow = normalizeWorkflow(workflow);
        await writeJsonAtomic(options.config, config);
        addLog('system', `Workflow saved: ${result.summary.nodeCount} nodes`);
        sendJson(response, 200, { ok: true, summary: result.summary });
      });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/workflow/clear') {
      await withWorkflowWriteLock(async () => {
        assertWorkflowLifecycleWritable();
        const config = await readJson(options.config);
        delete config.workflow;
        await writeJsonAtomic(options.config, config);
        const payload = workflowPayload(config);
        addLog('system', 'Workflow override cleared; legacy sequence is active');
        sendJson(response, 200, { ok: true, validation: payload.validation, public: payload.public });
      });
      return;
    }
    if (request.method === 'POST' && (url.pathname === '/api/connect' || url.pathname === '/api/init')) {
      const writeError = workflowWriteInProgressError('connecting');
      if (writeError) {
        sendJson(response, 409, { error: writeError });
        return;
      }
      const snapshot = state.session.snapshot();
      if (snapshot.phase === 'connected') {
        sendJson(response, 200, { session: publicSession(snapshot) });
        return;
      }
      if (isConnectingPhase(snapshot.phase)) {
        sendJson(response, 202, { session: publicSession(snapshot) });
        return;
      }
      if (isDisconnectingPhase(snapshot.phase)) {
        sendJson(response, 409, { error: 'Disconnect is in progress. Wait until it finishes before connecting again.' });
        return;
      }
      startConnectWithEvidence('connected');
      sendJson(response, 202, { session: publicSession(state.session.snapshot()) });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/reconnect') {
      const writeError = workflowWriteInProgressError('reconnecting');
      if (writeError) {
        sendJson(response, 409, { error: writeError });
        return;
      }
      const deviceCommandError = deviceCommandInProgressError('reconnecting');
      if (deviceCommandError) {
        sendJson(response, 409, { error: deviceCommandError });
        return;
      }
      if (state.runner.snapshot().active) {
        sendJson(response, 409, { error: 'A run is active. Stop it before reconnecting.' });
        return;
      }
      await state.session.disconnect();
      startConnectWithEvidence('reconnected');
      sendJson(response, 202, { session: publicSession(state.session.snapshot()) });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/disconnect') {
      const writeError = workflowWriteInProgressError('disconnecting');
      if (writeError) {
        sendJson(response, 409, { error: writeError });
        return;
      }
      const deviceCommandError = deviceCommandInProgressError('disconnecting');
      if (deviceCommandError) {
        sendJson(response, 409, { error: deviceCommandError });
        return;
      }
      if (state.runner.snapshot().active) {
        sendJson(response, 409, { error: 'A run is active. Stop it before disconnecting.' });
        return;
      }
      sendJson(response, 200, { session: publicSession(await state.session.disconnect()) });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/screenshot') {
      assertManualDeviceCommandAllowed();
      const body = await readBody(request);
      const screenshot = await withDeviceCommandLock(
        `manual screenshot: ${body.reason ?? 'manual'}`,
        () => createScreenshotCommand(body.reason ?? 'manual')
      );
      addRunEvent({
        type: 'screenshot',
        status: 'ok',
        reason: screenshot.reason,
        durationMs: screenshot.durationMs,
        file: screenshot.file ?? null,
      });
      sendJson(response, 200, { screenshot });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/visual/analyze') {
      assertManualDeviceCommandAllowed();
      const body = await readBody(request);
      const result = await withDeviceCommandLock(
        `manual visual analysis: ${body.reason ?? 'manual'}`,
        () => createVisualSnapshotCommand(body.reason ?? 'manual')
      );
      sendJson(response, 200, result);
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/run') {
      const body = await readBody(request);
      const parsedLoops = Number(body.loops);
      if (!Number.isInteger(parsedLoops) || parsedLoops < 1) {
        sendJson(response, 400, { error: 'loops must be a positive integer' });
        return;
      }
      if (state.runner.snapshot().active) {
        sendJson(response, 409, { error: 'A run is already active.' });
        return;
      }
      const deviceCommandError = deviceCommandInProgressError();
      if (deviceCommandError) {
        sendJson(response, 409, { error: deviceCommandError });
        return;
      }
      const writeError = workflowWriteInProgressError();
      if (writeError) {
        sendJson(response, 409, { error: writeError });
        return;
      }
      if (state.session.snapshot().phase !== 'connected') {
        sendJson(response, 409, { error: 'WDA/WebDriver is not connected. Connect first.' });
        return;
      }
      state.runner.run({ loops: parsedLoops }).catch(async (error) => {
        addLog('stderr', error.message);
        try {
          const screenshot = await withDeviceCommandLock(
            'run failure screenshot',
            () => createScreenshotCommand('run-error', { timeoutMs: FAILURE_SCREENSHOT_TIMEOUT_MS })
          );
          addRunEvent({
            type: 'screenshot',
            status: 'error',
            reason: screenshot.reason,
            durationMs: screenshot.durationMs,
            file: screenshot.file ?? null,
          });
        } catch (screenshotError) {
          addLog('system', `Failed to capture failure screenshot: ${screenshotError.message}`);
        }
      }).finally(() => {
        state.evidenceStore.finishRun({ reason: 'runner-settled' })
          .catch((error) => logEvidenceStoreError('finish', error));
      });
      sendJson(response, 202, { run: state.runner.snapshot() });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/stop') {
      sendJson(response, 200, { run: state.runner.requestStop() });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/resume') {
      sendJson(response, 200, { run: state.runner.resume() });
      return;
    }
    if (request.method === 'POST' && url.pathname === '/api/logs/clear') {
      sendJson(response, 200, clearLogs());
      return;
    }

    response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
    response.end('Not found');
  } catch (error) {
    sendErrorJson(response, error.statusCode ?? 400, error);
  }
}

async function main() {
  const options = parseArgs(process.argv);
  if (options.help) {
    printHelp();
    return;
  }

  state.session = new AssistSession({ configPath: options.config });
  state.discoverDevicesForStatus = createDeviceDiscoveryStatus({
    discoverDevices: listUsbmuxDevices,
    sanitizeError: publicErrorMessage,
    timeoutMs: 1500,
  });
  state.runner = new AssistRunner({
    session: state.session,
    loadConfig: () => readJson(options.config),
    hooks: {
      beforeStep: visualGuardBeforeStep,
      afterStep: visualEvidenceAfterStep,
      snapshot: workflowSnapshot,
      visualBranch: workflowVisualBranch,
    },
  });

  state.session.on('log', ({ stream, message }) => addLog(stream, message));
  state.runner.on('log', ({ stream, message }) => addLog(stream, message));
  state.session.on('status', () => broadcast({ type: 'status' }));
  state.runner.on('status', () => broadcast({ type: 'status' }));
  state.runner.on('runEvent', addRunEvent);

  const server = http.createServer((request, response) => {
    handleRequest(options, request, response)
      .catch((error) => sendErrorJson(response, error.statusCode ?? 500, error));
  });
  server.requestTimeout = HTTP_REQUEST_TIMEOUT_MS;
  server.headersTimeout = HTTP_HEADERS_TIMEOUT_MS;
  server.keepAliveTimeout = HTTP_KEEP_ALIVE_TIMEOUT_MS;

  await new Promise((resolveListen, rejectListen) => {
    const onError = (error) => {
      server.off('listening', onListening);
      rejectListen(error);
    };
    const onListening = () => {
      server.off('error', onError);
      resolveListen();
    };
    server.once('error', onError);
    server.once('listening', onListening);
    server.listen(options.port, '127.0.0.1');
  });
  console.log(`iOS Assist Studio dashboard: http://127.0.0.1:${options.port}/`);
  console.log(`Config: ${options.config}`);
  console.log('Press Ctrl+C to stop the dashboard.');

  let shutdownStarted = false;
  const shutdown = async () => {
    if (shutdownStarted) {
      return;
    }
    shutdownStarted = true;
    closeEventClients();
    state.runner.requestStop();
    try {
      await state.runner.waitForIdle(RUNNER_SHUTDOWN_WAIT_TIMEOUT_MS);
    } catch (error) {
      addLog('system', `Shutdown runner wait timed out: ${error.message}`);
    }
    try {
      await Promise.race([
        state.session.disconnect(),
        sleep(5000).then(() => {
          addLog('system', 'Shutdown disconnect timed out; closing HTTP server.');
        }),
      ]);
    } catch (error) {
      addLog('system', `Shutdown disconnect failed: ${error.message}`);
    }
    closeEventClients();
    const closed = new Promise((resolveClose) => server.close(resolveClose));
    server.closeIdleConnections?.();
    await Promise.race([closed, sleep(250)]);
    server.closeAllConnections?.();
    await Promise.race([closed, sleep(HTTP_SHUTDOWN_TIMEOUT_MS)]);
    process.exit(0);
  };

  const handleSignal = () => {
    shutdown().catch((error) => {
      console.error(error.message);
      process.exit(1);
    });
  };

  process.once('SIGINT', handleSignal);
  process.once('SIGTERM', handleSignal);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
