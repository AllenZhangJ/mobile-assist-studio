#!/usr/bin/env node
import { mkdtemp, readFile, readdir } from 'node:fs/promises';
import http from 'node:http';
import net from 'node:net';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import {
  AssistSession,
  classifyConnectionError,
  isAppiumReady,
  sleep,
  withTimeout,
  writeJsonAtomic,
} from './ios-assist-session.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function listen(server) {
  return new Promise((resolveListen, rejectListen) => {
    server.once('error', rejectListen);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      resolveListen(address.port);
    });
  });
}

function close(server) {
  return new Promise((resolveClose) => server.close(resolveClose));
}

async function readyServerScenario() {
  const server = http.createServer((request, response) => {
    if (request.url === '/status') {
      response.writeHead(200, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ value: { ready: true } }));
      return;
    }
    response.writeHead(404);
    response.end();
  });
  const port = await listen(server);
  try {
    assert(await isAppiumReady({ hostname: '127.0.0.1', port, path: '/' }), 'Ready Appium status should return true');
  } finally {
    await close(server);
  }
}

async function hangingServerScenario() {
  const sockets = new Set();
  const server = net.createServer(() => {
    // Keep the socket open without returning HTTP bytes.
  });
  server.on('connection', (socket) => {
    sockets.add(socket);
    socket.on('close', () => sockets.delete(socket));
  });
  const port = await listen(server);
  const startedAt = Date.now();
  try {
    const ready = await isAppiumReady({ hostname: '127.0.0.1', port, path: '/' }, { timeoutMs: 250 });
    const durationMs = Date.now() - startedAt;
    assert(ready === false, 'Hanging Appium status should return false');
    assert(durationMs < 1500, 'Hanging Appium status should respect the timeout');
  } finally {
    for (const socket of sockets) {
      socket.destroy();
    }
    await close(server);
  }
}

function developerTrustError() {
  return Object.assign(new Error('trust needed'), {
    classified: {
      code: 'DEVELOPER_CERT_NOT_TRUSTED',
      message: 'trust needed',
      userAction: 'trust the developer certificate',
    },
  });
}

function connectionClassifierScenario() {
  const trust = classifyConnectionError(new Error(
    'The application could not be launched because the Developer App Certificate is not trusted. ' +
    'profile has not been explicitly trusted by the user'
  ));
  assert(trust.code === 'DEVELOPER_CERT_NOT_TRUSTED', 'Trust errors should be classified explicitly');
  assert(/信任/.test(trust.userAction), 'Trust errors should include a trust action');

  const locked = classifyConnectionError(new Error('Run Destination Preflight: Unlock iPhone to Continue'));
  assert(locked.code === 'DEVICE_LOCKED', 'Locked iPhone errors should be classified explicitly');
  assert(/解锁/.test(locked.userAction), 'Locked iPhone errors should include an unlock action');

  const proxy = classifyConnectionError(new Error('Could not proxy command to the remote server. socket hang up on port 8100'));
  assert(proxy.code === 'WDA_SESSION_NOT_READY', 'Socket hang up should be classified as WDA session not ready');

  const fullDeviceId = [
    '11112222',
    '33334444',
    '55556666',
    '00000000',
    '00000000',
  ].join('');
  const hyphenatedDeviceId = ['11112222', '3333444455556666'].join('-');
  const userPathPrefix = '/U' + 'sers/';
  const privatePath = `${userPathPrefix}private/project`;
  const redacted = classifyConnectionError(new Error(
    `xcodebuild failed with code 65 at ${privatePath} with device ${fullDeviceId} and ${hyphenatedDeviceId}`
  ));
  assert(!redacted.detail.includes(userPathPrefix), 'Connection diagnostics should redact user paths');
  assert(!redacted.detail.includes(fullDeviceId), 'Connection diagnostics should redact full device ids');
  assert(!redacted.detail.includes(hyphenatedDeviceId), 'Connection diagnostics should redact iOS hyphenated device ids');
}

async function trustRetryLimitScenario() {
  const session = new AssistSession({ configPath: 'unused.json' });
  let attempts = 0;
  session.initializeDevice = async () => ({
    config: {
      appium: {
        trustRetryLimit: 2,
        trustRetryDelayMs: 1,
      },
    },
    selected: { udid: 'sample-device', connectionType: 'USB' },
  });
  session.ensureAppium = async () => {};
  session.createDriver = async () => {
    attempts += 1;
    throw developerTrustError();
  };

  let failed = false;
  try {
    await session.connect({ retryTrust: true });
  } catch (error) {
    failed = error.classified?.code === 'DEVELOPER_CERT_NOT_TRUSTED';
  }

  assert(failed, 'Developer trust retry limit should reject the connection');
  assert(attempts === 3, 'Trust retry limit of 2 should allow the initial attempt plus two retries');
  assert(session.snapshot().phase === 'error', 'Trust retry limit should end in error phase');
  assert(session.snapshot().waitingForTrust === false, 'Trust retry limit should stop the waiting state');
  assert(session.snapshot().trustRetryCount === 2, 'Trust retry count should not exceed the configured limit');
  assert(session.snapshot().trustRetryLimit === 2, 'Trust retry limit should be exposed in the session snapshot');
}

async function trustRetryDisconnectScenario() {
  const session = new AssistSession({ configPath: 'unused.json' });
  session.initializeDevice = async () => ({
    config: {
      appium: {
        trustRetryLimit: 20,
        trustRetryDelayMs: 1000,
      },
    },
    selected: { udid: 'sample-device', connectionType: 'USB' },
  });
  session.ensureAppium = async () => {};
  session.createDriver = async () => {
    throw developerTrustError();
  };

  const connectPromise = session.connect({ retryTrust: true });
  const startedAt = Date.now();
  while (session.snapshot().phase !== 'waitingForDeveloperTrust' && Date.now() - startedAt < 1000) {
    await sleep(10);
  }

  assert(session.snapshot().phase === 'waitingForDeveloperTrust', 'Trust retry should enter waiting phase');
  const disconnected = await withTimeout(session.disconnect(), 500, 'disconnect timeout');
  await connectPromise;

  assert(disconnected.phase === 'disconnected', 'Disconnect should cancel trust retry wait');
  assert(session.snapshot().phase === 'disconnected', 'Session should remain disconnected after cancelling trust wait');
  assert(session.snapshot().trustRetryLimit === 20, 'Disconnected trust wait should retain the active retry limit for diagnostics');
}

async function duplicateDisconnectScenario() {
  const session = new AssistSession({ configPath: 'unused.json' });
  let deleteCount = 0;
  session.phase = 'connected';
  session.driver = {
    async deleteSession() {
      deleteCount += 1;
      await sleep(50);
    },
  };

  const [first, second] = await Promise.all([
    session.disconnect(),
    session.disconnect(),
  ]);

  assert(first.phase === 'disconnected', 'First disconnect should finish disconnected');
  assert(second.phase === 'disconnected', 'Second duplicate disconnect should share the disconnected result');
  assert(deleteCount === 1, 'Duplicate disconnect calls should delete the WebDriver session once');
  assert(session.snapshot().phase === 'disconnected', 'Duplicate disconnect should leave session disconnected');
}

async function hangingDeleteSessionScenario() {
  const session = new AssistSession({
    configPath: 'unused.json',
    deleteSessionTimeoutMs: 30,
  });
  const logs = [];
  session.on('log', ({ message }) => logs.push(message));
  session.phase = 'connected';
  session.driver = {
    async deleteSession() {
      return new Promise(() => {});
    },
  };

  const disconnected = await withTimeout(session.disconnect(), 500, 'hanging deleteSession disconnect timeout');

  assert(disconnected.phase === 'disconnected', 'Disconnect should finish even when deleteSession hangs');
  assert(session.snapshot().phase === 'disconnected', 'Hanging deleteSession should leave session disconnected');
  assert(logs.some((message) => /delete timed out/i.test(message)), 'Hanging deleteSession should be logged as a timeout');
}

async function connectDuringDisconnectScenario() {
  const session = new AssistSession({ configPath: 'unused.json' });
  session.phase = 'connected';
  session.driver = {
    async deleteSession() {
      await sleep(50);
    },
  };

  const disconnectPromise = session.disconnect();
  let rejected = false;
  try {
    await session.connect();
  } catch (error) {
    rejected = /Disconnect is in progress/i.test(error.message);
  }
  await disconnectPromise;

  assert(rejected, 'Connect should be rejected while disconnect is in progress');
  assert(session.snapshot().phase === 'disconnected', 'Connect during disconnect should not disturb final disconnected state');
}

async function disconnectDuringDriverCreationScenario() {
  const session = new AssistSession({
    configPath: 'unused.json',
    disconnectConnectWaitTimeoutMs: 20,
  });
  let rejectDriver;
  let createDriverStarted = false;
  session.initializeDevice = async () => ({
    config: { appium: {} },
    selected: { udid: 'sample-device', connectionType: 'USB' },
  });
  session.ensureAppium = async () => {};
  session.createDriver = async () => {
    createDriverStarted = true;
    return new Promise((_, reject) => {
      rejectDriver = reject;
    });
  };

  const connectPromise = session.connect();
  const startedAt = Date.now();
  while (!createDriverStarted && Date.now() - startedAt < 1000) {
    await sleep(10);
  }
  assert(createDriverStarted, 'Connect should enter WebDriver session creation');

  const disconnected = await withTimeout(session.disconnect(), 500, 'disconnect during driver creation timeout');
  assert(disconnected.phase === 'disconnected', 'Disconnect should return even while WebDriver creation is pending');
  assert(session.snapshot().phase === 'disconnected', 'Session should expose disconnected after timed disconnect');

  let rejectedConnect = false;
  try {
    await session.connect();
  } catch (error) {
    rejectedConnect = /Disconnect is in progress/i.test(error.message);
  }
  assert(rejectedConnect, 'New connect should be rejected until the pending cancelled connection settles');

  rejectDriver(new Error('late createDriver failure'));
  const cancelledConnect = await withTimeout(connectPromise, 500, 'cancelled connect should settle');
  assert(cancelledConnect.phase === 'disconnected', 'Cancelled connect should settle as disconnected');
  assert(session.snapshot().phase === 'disconnected', 'Late createDriver failure should not move session back to error');
}

async function main() {
await readyServerScenario();
await hangingServerScenario();
connectionClassifierScenario();
await trustRetryLimitScenario();
  await trustRetryDisconnectScenario();
  await duplicateDisconnectScenario();
  await hangingDeleteSessionScenario();
  await connectDuringDisconnectScenario();
  await disconnectDuringDriverCreationScenario();
  const tempDir = await mkdtemp(join(tmpdir(), 'ios-assist-session-'));
  const jsonPath = join(tempDir, 'config.json');
  await writeJsonAtomic(jsonPath, { ok: true });
  const json = JSON.parse(await readFile(jsonPath, 'utf8'));
  assert(json.ok === true, 'writeJsonAtomic should write readable JSON');
  const files = await readdir(tempDir);
  assert(!files.some((file) => file.includes('.tmp-')), 'writeJsonAtomic should not leave temp files');
  const fastResult = await withTimeout(Promise.resolve('ok'), 1000, 'fast timeout');
  assert(fastResult === 'ok', 'withTimeout should return fast results');
  let timedOut = false;
  try {
    await withTimeout(sleep(500), 50, 'slow timeout');
  } catch (error) {
    timedOut = error.message === 'slow timeout';
  }
  assert(timedOut, 'withTimeout should reject slow operations');
  console.log('Session smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
