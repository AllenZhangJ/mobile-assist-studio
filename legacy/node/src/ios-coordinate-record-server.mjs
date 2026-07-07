import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFile, rename, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import process from 'node:process';

const DEFAULT_CONFIG = 'config/connected-device.sequence.json';
const MAX_BODY_BYTES = 64 * 1024;
const HTTP_REQUEST_TIMEOUT_MS = 30_000;
const HTTP_HEADERS_TIMEOUT_MS = 35_000;
const HTTP_KEEP_ALIVE_TIMEOUT_MS = 5_000;
const SCREENSHOT_CAPTURE_TIMEOUT_MS = 10_000;
const WINDOW_RECT_TIMEOUT_MS = 5_000;

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
    port: 4789,
    startAppium: false,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--start-appium') {
      options.startAppium = true;
      continue;
    }

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
  node legacy/node/src/ios-coordinate-record-server.mjs --config config/connected-device.sequence.json --start-appium

Open the printed local URL, click the screenshot, then press Save to write the sequence back to the config.
`);
}

async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, 'utf8'));
}

async function writeJsonAtomic(filePath, value) {
  const temporaryPath = `${filePath}.tmp-${process.pid}-${Date.now()}`;
  try {
    await writeFile(temporaryPath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
    await rename(temporaryPath, filePath);
  } catch (error) {
    await rm(temporaryPath, { force: true });
    throw error;
  }
}

function sleep(ms) {
  return new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
}

async function withTimeout(promise, timeoutMs, message) {
  let timeout;
  try {
    return await Promise.race([
      promise,
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
  const defaultCommand = 'node_modules/.bin/appium';
  const command = appium.command ?? resolve(process.cwd(), defaultCommand);
  const args = appium.args ?? ['--address', hostname, '--port', port];
  const displayCommand = appium.command ?? defaultCommand;

  console.log(`Starting Appium: ${displayCommand} ${args.join(' ')}`);
  const child = spawn(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  child.stdout.on('data', (chunk) => prefixOutput('[appium] ', chunk, process.stdout));
  child.stderr.on('data', (chunk) => prefixOutput('[appium] ', chunk, process.stderr));

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

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function isValidSequence(sequence) {
  return Array.isArray(sequence) && sequence.length > 0 && sequence.every((step) => {
    if (step.type === 'tap') {
      return Number.isFinite(step.x) && Number.isFinite(step.y);
    }

    if (step.type === 'wait') {
      return Number.isFinite(step.ms) && step.ms >= 0;
    }

    return false;
  });
}

async function readBody(request) {
  const chunks = [];
  let size = 0;
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) {
      throw Object.assign(new Error('Request body is too large'), { statusCode: 413 });
    }
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}

async function parseJsonBody(request) {
  try {
    const text = await readBody(request);
    return text ? JSON.parse(text) : {};
  } catch (error) {
    if (error.statusCode) {
      throw error;
    }
    throw Object.assign(new Error('Request body must be valid JSON'), { statusCode: 400 });
  }
}

function recorderHtml({ screenshotBase64, viewport, configLabel }) {
  const viewportJson = JSON.stringify(viewport);
  const configLabelJson = JSON.stringify(configLabel);

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>iPhone Tap Recorder</title>
  <style>
    :root {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f4f6f9;
      color: #1f2328;
    }
    body {
      margin: 0;
      padding: 18px;
    }
    .layout {
      display: grid;
      grid-template-columns: minmax(300px, 430px) minmax(360px, 1fr);
      gap: 18px;
      align-items: start;
    }
    .screen {
      position: relative;
      width: min(100%, 430px);
      border: 1px solid #c6ccd6;
      background: #111;
      user-select: none;
    }
    .screen img {
      display: block;
      width: 100%;
      height: auto;
    }
    .marker {
      position: absolute;
      width: 22px;
      height: 22px;
      transform: translate(-50%, -50%);
      border: 2px solid #fff;
      border-radius: 999px;
      background: #e92f3c;
      color: #fff;
      font-size: 12px;
      font-weight: 700;
      line-height: 22px;
      text-align: center;
      box-shadow: 0 2px 8px rgb(0 0 0 / 35%);
      pointer-events: none;
    }
    .panel {
      display: grid;
      gap: 12px;
    }
    .toolbar {
      display: flex;
      flex-wrap: wrap;
      gap: 8px;
    }
    button {
      border: 1px solid #aeb6c2;
      background: #fff;
      border-radius: 6px;
      padding: 8px 12px;
      font-size: 14px;
      cursor: pointer;
    }
    button.primary {
      background: #1456f0;
      border-color: #1456f0;
      color: #fff;
    }
    button.danger {
      color: #b42318;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      background: #fff;
      font-size: 13px;
    }
    th, td {
      border: 1px solid #d7dce3;
      padding: 7px 8px;
      text-align: left;
    }
    th {
      background: #edf0f5;
    }
    textarea {
      width: 100%;
      min-height: 260px;
      box-sizing: border-box;
      border: 1px solid #c9ced6;
      border-radius: 6px;
      padding: 10px;
      font: 12px ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      background: #fff;
    }
    .muted {
      color: #667085;
      font-size: 13px;
      line-height: 1.45;
    }
    .status {
      min-height: 20px;
      font-size: 13px;
      color: #14532d;
    }
    @media (max-width: 900px) {
      body {
        padding: 12px;
      }
      .layout {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body>
  <div class="layout">
    <div>
      <div id="screen" class="screen">
        <img id="screenshot" alt="Current iPhone screenshot" src="data:image/png;base64,${screenshotBase64}">
      </div>
      <p class="muted">在这张截图上按顺序点击。第二次点击开始，会自动记录和上一次点击之间的间隔。</p>
    </div>
    <div class="panel">
      <div>
        <h2>iPhone Tap Recorder</h2>
        <p class="muted">Viewport: ${escapeHtml(viewport.width)} x ${escapeHtml(viewport.height)} points. Save target: ${escapeHtml(configLabel)}</p>
      </div>
      <div class="toolbar">
        <button id="undo">Undo</button>
        <button id="reset" class="danger">Reset</button>
        <button id="copy">Copy JSON</button>
        <button id="save" class="primary">Save to connected config</button>
      </div>
      <div id="status" class="status"></div>
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>x</th>
            <th>y</th>
            <th>wait before tap</th>
          </tr>
        </thead>
        <tbody id="rows"></tbody>
      </table>
      <textarea id="json" spellcheck="false"></textarea>
      <p class="muted">保存后会替换 <code>connected-device.sequence.json</code> 里的 <code>sequence</code>，签名和设备配置不会变。</p>
    </div>
  </div>
  <script>
    const viewport = ${viewportJson};
    const configLabel = ${configLabelJson};
    const points = [];
    const screen = document.getElementById('screen');
    const screenshot = document.getElementById('screenshot');
    const rows = document.getElementById('rows');
    const json = document.getElementById('json');
    const status = document.getElementById('status');

    function nowMs() {
      return Math.round(performance.now());
    }

    function appiumPoint(event) {
      const rect = screenshot.getBoundingClientRect();
      const relativeX = Math.max(0, Math.min(rect.width, event.clientX - rect.left));
      const relativeY = Math.max(0, Math.min(rect.height, event.clientY - rect.top));
      return {
        x: Math.round(relativeX / rect.width * viewport.width),
        y: Math.round(relativeY / rect.height * viewport.height),
        leftPercent: relativeX / rect.width * 100,
        topPercent: relativeY / rect.height * 100,
      };
    }

    function sequence() {
      const result = [];
      for (const [index, point] of points.entries()) {
        if (index > 0) {
          result.push({ type: 'wait', ms: point.waitBeforeMs });
        }
        result.push({
          type: 'tap',
          x: point.x,
          y: point.y,
          label: String.fromCharCode(65 + index),
        });
      }
      return result;
    }

    function sequenceJson() {
      return JSON.stringify(sequence(), null, 2);
    }

    function render() {
      screen.querySelectorAll('.marker').forEach((node) => node.remove());
      rows.textContent = '';

      for (const [index, point] of points.entries()) {
        const marker = document.createElement('div');
        marker.className = 'marker';
        marker.style.left = point.leftPercent + '%';
        marker.style.top = point.topPercent + '%';
        marker.textContent = index + 1;
        screen.appendChild(marker);

        const row = document.createElement('tr');
        const wait = index === 0 ? '-' : point.waitBeforeMs + ' ms';
        row.innerHTML = '<td>' + (index + 1) + '</td><td>' + point.x + '</td><td>' + point.y + '</td><td>' + wait + '</td>';
        rows.appendChild(row);
      }

      json.value = sequenceJson();
    }

    screen.addEventListener('click', (event) => {
      if (event.target !== screenshot && event.target !== screen) {
        return;
      }

      const point = appiumPoint(event);
      const clickedAt = nowMs();
      const previous = points[points.length - 1];
      points.push({
        ...point,
        clickedAt,
        waitBeforeMs: previous ? Math.max(0, clickedAt - previous.clickedAt) : 0,
      });
      status.textContent = '';
      render();
    });

    document.getElementById('undo').addEventListener('click', () => {
      points.pop();
      status.textContent = '';
      render();
    });

    document.getElementById('reset').addEventListener('click', () => {
      points.length = 0;
      status.textContent = '';
      render();
    });

    document.getElementById('copy').addEventListener('click', async () => {
      await navigator.clipboard.writeText(sequenceJson());
      status.textContent = 'Copied sequence JSON.';
    });

    document.getElementById('save').addEventListener('click', async () => {
      const response = await fetch('/save', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ sequence: sequence() }),
      });
      const body = await response.json();
      if (!response.ok) {
        status.textContent = body.error || 'Save failed.';
        return;
      }
      status.textContent = 'Saved ' + body.tapCount + ' taps to ' + configLabel + '.';
    });

    render();
  </script>
</body>
</html>`;
}

async function createSnapshot(config) {
  const appium = config.appium;
  const connection = {
    hostname: appium.hostname ?? '127.0.0.1',
    port: appium.port ?? 4723,
    path: appium.path ?? '/',
    logLevel: appium.logLevel ?? 'warn',
    connectionRetryCount: numberOrDefault(appium.connectionRetryCount, 0),
    connectionRetryTimeout: numberOrDefault(appium.connectionRetryTimeout, 120000),
    capabilities: appium.capabilities,
  };

  let driver;
  let appiumProcess;
  try {
    appiumProcess = await ensureAppium(appium, appium.autoStart === true);
    const { remote } = await import('webdriverio');
    console.log(`Connecting to Appium at ${connection.hostname}:${connection.port}${connection.path}`);
    driver = await remote(connection);
    const screenshotBase64 = await withTimeout(
      driver.takeScreenshot(),
      SCREENSHOT_CAPTURE_TIMEOUT_MS,
      `Screenshot capture timed out after ${SCREENSHOT_CAPTURE_TIMEOUT_MS}ms`
    );
    const rect = await withTimeout(
      driver.getWindowRect(),
      WINDOW_RECT_TIMEOUT_MS,
      `Window rect capture timed out after ${WINDOW_RECT_TIMEOUT_MS}ms`
    );
    return {
      screenshotBase64,
      viewport: {
        width: Math.round(rect.width),
        height: Math.round(rect.height),
      },
    };
  } finally {
    if (driver) {
      await driver.deleteSession();
    }
    await stopAppiumServer(appiumProcess);
  }
}

async function main() {
  const options = parseArgs(process.argv);
  if (options.help) {
    printHelp();
    return;
  }

  const configPath = resolve(process.cwd(), options.config);
  const config = await readJson(configPath);
  if (options.startAppium) {
    config.appium.autoStart = true;
  }

  console.log('Capturing current iPhone screen...');
  const snapshot = await createSnapshot(config);

  const server = http.createServer(async (request, response) => {
    try {
      if (request.method === 'GET' && request.url === '/') {
        response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
        response.end(recorderHtml({
          screenshotBase64: snapshot.screenshotBase64,
          viewport: snapshot.viewport,
          configLabel: options.config,
        }));
        return;
      }

      if (request.method === 'POST' && request.url === '/save') {
        const body = await parseJsonBody(request);
        if (!isValidSequence(body.sequence)) {
          response.writeHead(400, { 'content-type': 'application/json' });
          response.end(JSON.stringify({ error: 'Sequence must contain at least one valid tap/wait step.' }));
          return;
        }

        const latestConfig = await readJson(configPath);
        latestConfig.sequence = body.sequence;
        await writeJsonAtomic(configPath, latestConfig);
        const tapCount = body.sequence.filter((step) => step.type === 'tap').length;
        console.log(`Saved ${tapCount} taps to ${options.config}`);
        response.writeHead(200, { 'content-type': 'application/json' });
        response.end(JSON.stringify({ ok: true, tapCount }));
        return;
      }

      response.writeHead(404, { 'content-type': 'text/plain; charset=utf-8' });
      response.end('Not found');
    } catch (error) {
      response.writeHead(error.statusCode ?? 500, { 'content-type': 'application/json' });
      response.end(JSON.stringify({ error: error.message }));
    }
  });

  server.requestTimeout = HTTP_REQUEST_TIMEOUT_MS;
  server.headersTimeout = HTTP_HEADERS_TIMEOUT_MS;
  server.keepAliveTimeout = HTTP_KEEP_ALIVE_TIMEOUT_MS;

  await new Promise((resolveListen) => server.listen(options.port, '127.0.0.1', resolveListen));
  console.log(`Recorder ready: http://127.0.0.1:${options.port}/`);
  console.log('Click the screenshot in your browser, then press "Save to connected config". Press Ctrl+C here to stop.');

  process.once('SIGINT', () => {
    server.close(() => process.exit(0));
    server.closeIdleConnections?.();
    setTimeout(() => server.closeAllConnections?.(), 1000).unref();
  });
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
