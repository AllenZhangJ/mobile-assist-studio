#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { mkdtemp, readFile, writeFile } from 'node:fs/promises';
import http from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import process from 'node:process';

const EXAMPLE_CONFIG = 'config/example.sequence.json';

function getFreePort() {
  return new Promise((resolvePort, rejectPort) => {
    const server = http.createServer();
    server.once('error', rejectPort);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      server.close(() => resolvePort(address.port));
    });
  });
}

function waitForConsole(child, timeoutMs) {
  return new Promise((resolveReady, rejectReady) => {
    let output = '';
    const timeout = setTimeout(() => {
      rejectReady(new Error(`Console did not become ready within ${timeoutMs}ms.\n${output}`));
    }, timeoutMs);

    const finish = (error) => {
      clearTimeout(timeout);
      child.stdout.off('data', onStdout);
      child.stderr.off('data', onStderr);
      child.off('exit', onExit);
      if (error) {
        rejectReady(error);
      } else {
        resolveReady(output);
      }
    };

    const onStdout = (chunk) => {
      output += chunk.toString();
      if (/iOS Assist Studio dashboard:/.test(output)) {
        finish();
      }
    };
    const onStderr = (chunk) => {
      output += chunk.toString();
    };
    const onExit = (code, signal) => {
      finish(new Error(`Console exited before ready: code=${code} signal=${signal}\n${output}`));
    };

    child.stdout.on('data', onStdout);
    child.stderr.on('data', onStderr);
    child.once('exit', onExit);
  });
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const body = await response.json();
  return { response, body };
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function stopChild(child) {
  if (!child || child.exitCode !== null || child.signalCode !== null) {
    return { forced: false };
  }

  child.kill('SIGTERM');
  await Promise.race([
    new Promise((resolveExit) => child.once('exit', resolveExit)),
    new Promise((resolveTimeout) => setTimeout(resolveTimeout, 3000)),
  ]);

  if (child.exitCode === null && child.signalCode === null) {
    child.kill('SIGKILL');
    return { forced: true };
  }
  return { forced: false };
}

function openEventStream(url) {
  return new Promise((resolveOpen, rejectOpen) => {
    const request = http.get(url, (response) => {
      response.once('data', () => {
        resolveOpen({ request, response });
      });
      response.once('error', rejectOpen);
    });
    request.once('error', rejectOpen);
    request.setTimeout(3000, () => {
      request.destroy(new Error('Event stream did not open within 3000ms'));
    });
  });
}

function openSlowWorkflowPost(baseUrl, body) {
  const text = JSON.stringify(body);
  const splitAt = Math.max(1, Math.floor(text.length / 2));
  const target = new URL('/api/workflow', baseUrl);
  let finishRequest;
  const responsePromise = new Promise((resolveResponse, rejectResponse) => {
    const request = http.request({
      hostname: target.hostname,
      port: target.port,
      path: target.pathname,
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'content-length': Buffer.byteLength(text),
      },
    }, (response) => {
      let raw = '';
      response.on('data', (chunk) => {
        raw += chunk.toString();
      });
      response.once('end', () => {
        try {
          resolveResponse({ response, body: raw ? JSON.parse(raw) : {} });
        } catch (error) {
          rejectResponse(error);
        }
      });
    });
    request.once('error', rejectResponse);
    request.write(text.slice(0, splitAt));
    finishRequest = () => {
      request.end(text.slice(splitAt));
    };
  });
  return { finish: finishRequest, responsePromise };
}

async function main() {
  const consoleSource = await readFile('legacy/node/src/ios-assist-console.mjs', 'utf8');
  assert(consoleSource.includes('isDisconnectingPhase(snapshot.phase)'), 'Connect API should explicitly guard disconnecting sessions');
  assert(consoleSource.includes('Disconnect is in progress. Wait until it finishes before connecting again.'), 'Disconnecting connect guard should return an actionable message');
  assert(consoleSource.includes('message: publicErrorMessage(error)'), 'Session errors should expose sanitized public messages');
  assert(consoleSource.includes('userAction: publicText(error.userAction)'), 'Session error user actions should be sanitized');
  assert(consoleSource.includes('sendErrorJson(response, error.statusCode ?? 500, error)'), 'HTTP server should catch async handler rejections');
  assert(consoleSource.includes('const url = new URL(request.url'), 'URL parsing should happen inside the request handler try/catch');
  assert(consoleSource.includes('function appendSystemLog(message)'), 'Dashboard should have a reusable visible system-log helper');
  assert(consoleSource.includes("request failed: ' + error.message"), 'Dashboard fetch helpers should surface network failures');
  assert(consoleSource.includes('events.onerror = () =>'), 'Dashboard should surface realtime event stream failures');
  assert(consoleSource.includes('Realtime event parse failed'), 'Dashboard should surface malformed realtime event payloads');
  assert(consoleSource.includes('function handleRealtimePayload(payload)'), 'Dashboard should route realtime payloads through a guarded handler');
  assert(consoleSource.includes('Realtime event handling failed'), 'Dashboard should surface realtime event handler failures');
  assert(consoleSource.includes("if (event.status === 'error') return '任务异常结束';"), 'Dashboard timeline should not label error runEnd as a successful completion');
  assert(consoleSource.includes('const SCREENSHOT_CAPTURE_TIMEOUT_MS = 10_000'), 'Screenshot capture should have a bounded default timeout');
  assert(consoleSource.includes('const PAGE_SOURCE_CAPTURE_TIMEOUT_MS = 5_000'), 'Page source capture should have a bounded timeout');
  assert(consoleSource.includes('const FAILURE_SCREENSHOT_TIMEOUT_MS = 5_000'), 'Run failure screenshot capture should have a bounded timeout');
  assert(consoleSource.includes('const DEVICE_COMMAND_HARD_LOCK_TIMEOUT_MS = 30_000'), 'Device command lock should have a hard release timeout');
  assert(consoleSource.includes('const RUNNER_SHUTDOWN_WAIT_TIMEOUT_MS = 5_000'), 'Console shutdown should have a bounded runner wait timeout');
  assert(consoleSource.includes('await state.runner.waitForIdle(RUNNER_SHUTDOWN_WAIT_TIMEOUT_MS)'), 'Console shutdown should wait for the runner to become idle before disconnecting WDA');
  assert(consoleSource.includes('function withDeviceCommandLock(name, createCommand)'), 'Dashboard should serialize manual device commands');
  assert(consoleSource.includes('async function awaitCommandResultAndSettle(name, command)'), 'Runner WDA commands should wait for settle or a hard timeout');
  assert(consoleSource.includes('runner screenshot:'), 'Runner screenshot commands should use the settle guard');
  assert(consoleSource.includes('runner visual snapshot:'), 'Runner visual commands should use the settle guard');
  assert(consoleSource.includes('deviceCommandInProgressError()'), 'Run API should reject while a manual device command is active');
  assert(consoleSource.includes("deviceCommandInProgressError('reconnecting')"), 'Reconnect API should reject while a manual device command is active');
  assert(consoleSource.includes("deviceCommandInProgressError('disconnecting')"), 'Disconnect API should reject while a manual device command is active');
  assert(consoleSource.includes('payload.operations?.deviceCommand?.active === true'), 'Dashboard buttons should reflect active manual device commands');
  assert(consoleSource.includes("'run failure screenshot'"), 'Run failure screenshot should use the shared device-command lock');
  assert(consoleSource.includes("createScreenshotCommand('run-error', { timeoutMs: FAILURE_SCREENSHOT_TIMEOUT_MS })"), 'Run failure path should use the short bounded screenshot capture');
  assert(consoleSource.includes('Array.isArray(entries) ? entries.slice() : []'), 'Dashboard log renderer should tolerate malformed snapshot logs');
  assert(consoleSource.includes('payload.validation?.errors'), 'Workflow editor should surface structured validation errors');
  assert(consoleSource.includes('elements.reconnectButton.disabled = run.active || workflowWriteBusy || deviceCommandBusy'), 'Reconnect button should reflect workflow and device-command locks');
  assert(consoleSource.includes("elements.disconnectButton.disabled = session.phase === 'disconnected' || run.active || workflowWriteBusy || deviceCommandBusy"), 'Disconnect button should reflect workflow and device-command locks');

  const port = await getFreePort();
  const tempDir = await mkdtemp(join(tmpdir(), 'ios-assist-console-'));
  const configPath = join(tempDir, 'example.sequence.json');
  await writeFile(configPath, await readFile(EXAMPLE_CONFIG, 'utf8'), 'utf8');

  const child = spawn(process.execPath, [
    'legacy/node/src/ios-assist-console.mjs',
    '--config',
    configPath,
    '--port',
    String(port),
  ], {
    cwd: process.cwd(),
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  try {
    await waitForConsole(child, 5000);
    const baseUrl = `http://127.0.0.1:${port}`;

    const page = await fetch(`${baseUrl}/`);
    assert(page.ok, 'Dashboard HTML should load');
    const html = await page.text();
    assert(html.includes('iOS Assist Studio'), 'Dashboard HTML should include the app name');
    assert(html.includes('初始化并连接'), 'Dashboard HTML should include the primary connect action');
    assert(html.includes('测试 1 轮'), 'Dashboard HTML should include the one-loop test action');
    assert(html.includes('执行 N 轮'), 'Dashboard HTML should include the multi-loop run action');
    assert(html.includes('停止任务'), 'Dashboard HTML should include the stop action');
    assert(html.includes('复制所有'), 'Dashboard HTML should include copy-all logs action');
    assert(html.includes('清除所有'), 'Dashboard HTML should include clear-all logs action');
    assert(html.includes('工作流拓扑'), 'Dashboard HTML should include the workflow topology panel');
    assert(html.includes('工作流配置'), 'Dashboard HTML should include the workflow editor panel');
    assert(html.includes('失败热力图'), 'Dashboard HTML should include the failure heatmap panel');
    assert(html.includes('heatmap'), 'Dashboard HTML should include the heatmap container');
    assert(html.includes('workflowCanvas'), 'Dashboard HTML should include workflow canvas container');
    assert(html.includes('workflowCanvasInner'), 'Dashboard HTML should include workflow canvas coordinate layer');
    assert(html.includes('workflowEdges'), 'Dashboard HTML should include workflow edge SVG layer');
    assert(html.includes('workflowNodes'), 'Dashboard HTML should include workflow nodes container');
    assert(html.includes('workflowEditor'), 'Dashboard HTML should include workflow editor');
    assert(html.includes('sequenceRows'), 'Dashboard HTML should include the sequence table body');
    assert(html.includes('copyLogButton'), 'Dashboard HTML should include the log copy button id');
    assert(html.includes('clearLogButton'), 'Dashboard HTML should include the log clear button id');
    assert(html.includes('function renderWorkflowEdges(workflow)'), 'Dashboard should render workflow edges as a canvas layer');
    assert(consoleSource.includes("url.pathname === '/api/analytics/heatmap'"), 'Dashboard should expose a read-only heatmap analytics API');
    assert(consoleSource.includes('function failureHeatmapPayload(events = state.runEvents)'), 'Dashboard should build heatmap analytics from run events');
    assert(html.includes('function renderHeatmap()'), 'Dashboard should aggregate failure heatmap data');
    assert(html.includes("event.status !== 'error'"), 'Dashboard heatmap should only aggregate error events');
    assert(html.includes("key: 'tap:'"), 'Dashboard heatmap should aggregate failed tap coordinates');
    assert(html.includes("key: 'node:'"), 'Dashboard heatmap should aggregate failed workflow nodes');
    assert(html.includes('.sort((a, b) => b.count - a.count'), 'Dashboard heatmap should rank failures by count');
    assert(html.includes('renderHeatmap();'), 'Dashboard should render the heatmap from status and realtime events');
    assert(html.includes('暂无失败坐标或失败节点'), 'Dashboard heatmap should have an explicit empty state');
    assert(html.includes('function startWorkflowDrag(event, nodeId, button, workflow)'), 'Dashboard should support front-end-only workflow node dragging');
    assert(html.includes('function resizeWorkflowCanvasToPositions()'), 'Workflow canvas should resize around dragged nodes');
    assert(html.includes("document.removeEventListener('pointercancel', stopWorkflowDrag)"), 'Workflow drag cancel should release document listeners');
    assert(html.includes("button.addEventListener('pointerdown'"), 'Workflow nodes should be draggable through pointer events');

    const status = await requestJson(`${baseUrl}/api/status`);
    assert(status.response.ok, 'Status API should return 200');
    assert(status.body.session?.phase === 'disconnected', 'Initial session phase should be disconnected');
    assert(Number.isInteger(status.body.session?.trustRetryLimit), 'Status payload should include developer trust retry limit');
    assert(Array.isArray(status.body.runEvents), 'Status payload should include runEvents');
    assert(status.body.evidence, 'Status payload should include evidence');
    assert('lastVisual' in status.body.evidence, 'Status evidence should include lastVisual');
    assert(status.body.operations?.deviceCommand?.active === false, 'Status should expose idle device command state');
    assert(status.body.config?.workflow?.nodeCount === 5, 'Status payload should expose legacy sequence as workflow nodes');
    assert(status.body.config?.workflow?.executable === true, 'Legacy workflow summary should be executable');
    assert(status.body.config?.workflow?.linear === true, 'Legacy workflow summary should be linear');
    assert(status.body.config?.workflow?.nodes?.length === 5, 'Status payload should include public workflow nodes');
    assert(status.body.config?.workflow?.edges?.length === 4, 'Status payload should include public workflow edges');

    const workflow = await requestJson(`${baseUrl}/api/workflow`);
    assert(workflow.response.ok, 'Workflow API should return 200');
    assert(workflow.body.validation?.ok === true, 'Workflow API should validate legacy workflow');
    assert(workflow.body.workflow?.id === 'legacy-sequence', 'Workflow API should expose workflow-only payload');
    assert(!('appium' in workflow.body), 'Workflow API must not expose private appium config');

    const heatmap = await requestJson(`${baseUrl}/api/analytics/heatmap`);
    assert(heatmap.response.ok, 'Heatmap analytics API should return 200');
    assert(Array.isArray(heatmap.body.rows), 'Heatmap analytics API should expose rows');
    assert(heatmap.body.rows.length === 0, 'Heatmap analytics API should start empty without failed run events');
    assert(Number.isInteger(heatmap.body.totalEvents), 'Heatmap analytics API should expose total event count');
    assert(!('appium' in heatmap.body), 'Heatmap analytics API must not expose private appium config');

    const invalidWorkflow = await requestJson(`${baseUrl}/api/workflow/validate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        workflow: {
          version: 1,
          id: 'unsafe',
          entry: 'start',
          nodes: [
            {
              id: 'start',
              type: 'If_Else',
              condition: { op: 'equals', left: 'process.env.HOME', right: 'x' },
              trueNext: 'done',
              falseNext: 'done',
            },
            { id: 'done', type: 'Wait', params: { ms: 1 } },
          ],
        },
      }),
    });
    assert(invalidWorkflow.response.ok, 'Workflow validate should return 200 for invalid graphs');
    assert(invalidWorkflow.body.ok === false, 'Workflow validate should reject unsafe expressions');

    const customWorkflow = {
      version: 1,
      id: 'smoke-workflow',
      entry: 'tapA',
      extraSecret: 'strip-me',
      nodes: [
        { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2, extraSecret: 'strip-me' }, next: 'waitA' },
        { id: 'waitA', type: 'Wait', params: { ms: 10 }, extraSecret: 'strip-me' },
      ],
    };
    const saveWorkflow = await requestJson(`${baseUrl}/api/workflow`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ workflow: customWorkflow }),
    });
    assert(saveWorkflow.response.ok && saveWorkflow.body.ok === true, 'Workflow save should return ok');

    const customStatus = await requestJson(`${baseUrl}/api/status`);
    assert(customStatus.body.config?.workflow?.nodeCount === 2, 'Saved workflow should become status source');
    assert(customStatus.body.config?.sequence?.length === 1, 'Saved workflow should become sequence source when linear');
    const savedWorkflow = await requestJson(`${baseUrl}/api/workflow`);
    assert(!('extraSecret' in savedWorkflow.body.workflow), 'Workflow save should strip root extras');
    assert(!('extraSecret' in savedWorkflow.body.workflow.nodes[0].params), 'Workflow save should strip params extras');
    assert(!('extraSecret' in savedWorkflow.body.workflow.nodes[1]), 'Workflow save should strip node extras');

    const clearWorkflow = await requestJson(`${baseUrl}/api/workflow/clear`, { method: 'POST' });
    assert(clearWorkflow.response.ok && clearWorkflow.body.ok === true, 'Workflow clear should return ok');
    const clearedStatus = await requestJson(`${baseUrl}/api/status`);
    assert(clearedStatus.body.config?.workflow?.nodeCount === 5, 'Cleared workflow should fall back to legacy sequence');
    assert(clearedStatus.body.operations?.workflowWriteInProgress === false, 'Status should expose idle workflow write state');

    const slowWorkflow = {
      version: 1,
      id: 'slow-save-workflow',
      entry: 'tapA',
      nodes: [
        { id: 'tapA', type: 'Tap', params: { label: 'A', x: 10, y: 20 } },
      ],
    };
    const slowSave = openSlowWorkflowPost(baseUrl, { workflow: slowWorkflow });
    await new Promise((resolve) => setTimeout(resolve, 50));
    const lockedStatus = await requestJson(`${baseUrl}/api/status`);
    assert(lockedStatus.body.operations?.workflowWriteInProgress === true, 'Status should expose active workflow write state');
    const overlappingSave = await requestJson(`${baseUrl}/api/workflow`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ workflow: customWorkflow }),
    });
    assert(overlappingSave.response.status === 409, 'Overlapping workflow save should be rejected');
    const overlappingClear = await requestJson(`${baseUrl}/api/workflow/clear`, { method: 'POST' });
    assert(overlappingClear.response.status === 409, 'Workflow clear during workflow save should be rejected');
    const connectDuringSave = await requestJson(`${baseUrl}/api/connect`, { method: 'POST' });
    assert(connectDuringSave.response.status === 409, 'Connect during workflow save should be rejected');
    assert(/Workflow write is in progress/i.test(connectDuringSave.body.error), 'Connect during workflow save should return a write-lock error');
    const reconnectDuringSave = await requestJson(`${baseUrl}/api/reconnect`, { method: 'POST' });
    assert(reconnectDuringSave.response.status === 409, 'Reconnect during workflow save should be rejected');
    const disconnectDuringSave = await requestJson(`${baseUrl}/api/disconnect`, { method: 'POST' });
    assert(disconnectDuringSave.response.status === 409, 'Disconnect during workflow save should be rejected');
    const runDuringSave = await requestJson(`${baseUrl}/api/run`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ loops: 1 }),
    });
    assert(runDuringSave.response.status === 409, 'Run during workflow save should be rejected before connection checks');
    assert(/Workflow write is in progress/i.test(runDuringSave.body.error), 'Run during workflow save should return a write-lock error');
    slowSave.finish();
    const slowSaveResult = await slowSave.responsePromise;
    assert(slowSaveResult.response.statusCode === 200 && slowSaveResult.body.ok === true, 'Slow workflow save should eventually finish');

    const malformedWorkflow = await requestJson(`${baseUrl}/api/workflow/validate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{"workflow":',
    });
    assert(malformedWorkflow.response.status === 400, 'Malformed JSON body should return 400');
    assert(typeof malformedWorkflow.body.error === 'string', 'Malformed JSON body should return a JSON error payload');

    const oversizedWorkflow = await requestJson(`${baseUrl}/api/workflow/validate`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ workflow: { blob: 'x'.repeat(70 * 1024) } }),
    });
    assert(oversizedWorkflow.response.status === 413, 'Oversized JSON body should return 413');
    assert(/too large/i.test(oversizedWorkflow.body.error), 'Oversized JSON body should return an actionable error');
    const statusAfterBadBodies = await requestJson(`${baseUrl}/api/status`);
    assert(statusAfterBadBodies.response.ok, 'Console should keep serving status after bad request bodies');

    const badRun = await requestJson(`${baseUrl}/api/run`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ loops: 'bad' }),
    });
    assert(badRun.response.status === 400, 'Invalid loops should return 400');

    const disconnectedRun = await requestJson(`${baseUrl}/api/run`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ loops: 1 }),
    });
    assert(disconnectedRun.response.status === 409, 'Run while disconnected should return 409');

    const screenshot = await requestJson(`${baseUrl}/api/screenshot`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ reason: 'smoke' }),
    });
    assert(screenshot.response.status === 409, 'Screenshot while disconnected should return 409');

    const visual = await requestJson(`${baseUrl}/api/visual/analyze`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ reason: 'smoke' }),
    });
    assert(visual.response.status === 409, 'Visual analysis while disconnected should return 409');

    const resume = await requestJson(`${baseUrl}/api/resume`, { method: 'POST' });
    assert(resume.response.ok && resume.body.run?.status === 'idle', 'Resume while idle should be harmless');

    const clearLogs = await requestJson(`${baseUrl}/api/logs/clear`, { method: 'POST' });
    assert(clearLogs.response.ok && clearLogs.body.ok === true, 'Logs clear API should return ok');

    const hangingSave = openSlowWorkflowPost(baseUrl, { workflow: slowWorkflow });
    hangingSave.responsePromise.catch(() => {});
    await new Promise((resolve) => setTimeout(resolve, 50));
    const hangingStatus = await requestJson(`${baseUrl}/api/status`);
    assert(hangingStatus.body.operations?.workflowWriteInProgress === true, 'Slow request should hold workflow write lock before shutdown');
    await openEventStream(`${baseUrl}/api/events`);
    const stopResult = await stopChild(child);
    assert(stopResult.forced === false, 'Console should shut down gracefully with active SSE and slow request clients');

    const badConfigPath = join(tempDir, 'bad.sequence.json');
    await writeFile(badConfigPath, JSON.stringify({
      appium: { hostname: '127.0.0.1', port: 9 },
      workflow: {
        version: 1,
        id: 'bad-workflow',
        entry: 'missing',
        extraSecret: 'do-not-return',
        nodes: [
          { id: 'start', type: 'Wait', params: { ms: -1, extraSecret: 'do-not-return' } },
        ],
      },
    }, null, 2), 'utf8');
    const badPort = await getFreePort();
    const badChild = spawn(process.execPath, [
      'legacy/node/src/ios-assist-console.mjs',
      '--config',
      badConfigPath,
      '--port',
      String(badPort),
    ], {
      cwd: process.cwd(),
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    try {
      await waitForConsole(badChild, 5000);
      const badBaseUrl = `http://127.0.0.1:${badPort}`;
      const badPage = await fetch(`${badBaseUrl}/`);
      assert(badPage.ok, 'Dashboard HTML should load even with invalid workflow config');
      const badStatus = await requestJson(`${badBaseUrl}/api/status`);
      assert(badStatus.response.ok, 'Status API should return 200 for invalid workflow config');
      assert(badStatus.body.config?.workflow?.ok === false, 'Invalid workflow config should be surfaced as workflow.ok=false');
      assert(Array.isArray(badStatus.body.config?.sequence), 'Invalid workflow status should still include sequence array');
      const badWorkflow = await requestJson(`${badBaseUrl}/api/workflow`);
      assert(badWorkflow.response.ok, 'Workflow API should return 200 for invalid workflow config');
      assert(badWorkflow.body.validation?.ok === false, 'Workflow API should surface invalid workflow validation');
      assert(badWorkflow.body.workflow === null, 'Workflow API should not return raw invalid workflow config');
      assert(!JSON.stringify(badWorkflow.body).includes('do-not-return'), 'Workflow API should not leak invalid workflow extras');
    } finally {
      await stopChild(badChild);
    }

    const missingPort = await getFreePort();
    const missingConfigPath = join(tempDir, 'missing.sequence.json');
    const missingChild = spawn(process.execPath, [
      'legacy/node/src/ios-assist-console.mjs',
      '--config',
      missingConfigPath,
      '--port',
      String(missingPort),
    ], {
      cwd: process.cwd(),
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    try {
      await waitForConsole(missingChild, 5000);
      const missingStatus = await requestJson(`http://127.0.0.1:${missingPort}/api/status`);
      assert(missingStatus.response.ok, 'Status API should return 200 for missing config');
      assert(missingStatus.body.config?.workflow?.ok === false, 'Missing config should be surfaced as workflow.ok=false');
      assert(!String(missingStatus.body.config?.error).includes(tempDir), 'Missing config error should not expose local paths');
      const missingWorkflow = await requestJson(`http://127.0.0.1:${missingPort}/api/workflow`);
      assert(missingWorkflow.response.ok, 'Workflow API should return 200 for missing config');
      assert(missingWorkflow.body.validation?.ok === false, 'Workflow API should surface missing config as validation failure');
      assert(missingWorkflow.body.workflow === null, 'Workflow API should not fabricate workflow for missing config');
      assert(!JSON.stringify(missingWorkflow.body).includes(tempDir), 'Missing workflow response should not expose local paths');
    } finally {
      await stopChild(missingChild);
    }

    console.log(`Console smoke passed on port ${port}`);
  } finally {
    await stopChild(child);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
