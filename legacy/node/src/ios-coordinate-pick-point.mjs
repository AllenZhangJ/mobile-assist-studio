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
    label: 'D',
    port: 4790,
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

    if (arg === '--label') {
      options.label = readOptionValue(argv, index, '--label');
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
  node legacy/node/src/ios-coordinate-pick-point.mjs --config config/connected-device.sequence.json --label D --start-appium

Click once on the screenshot. The matching tap label is updated immediately.
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

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function pickHtml({ screenshotBase64, viewport, label }) {
  const viewportJson = JSON.stringify(viewport);
  const labelJson = JSON.stringify(label);

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Pick ${escapeHtml(label)} Point</title>
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
    .wrap {
      display: grid;
      grid-template-columns: minmax(300px, 430px) minmax(260px, 1fr);
      gap: 18px;
      align-items: start;
    }
    .screen {
      position: relative;
      width: min(100%, 430px);
      border: 1px solid #c6ccd6;
      background: #111;
      cursor: crosshair;
      user-select: none;
    }
    img {
      display: block;
      width: 100%;
      height: auto;
    }
    .marker {
      position: absolute;
      width: 24px;
      height: 24px;
      transform: translate(-50%, -50%);
      border: 2px solid #fff;
      border-radius: 999px;
      background: #1456f0;
      color: #fff;
      font-size: 13px;
      font-weight: 700;
      line-height: 24px;
      text-align: center;
      box-shadow: 0 2px 8px rgb(0 0 0 / 35%);
      pointer-events: none;
    }
    .panel {
      background: #fff;
      border: 1px solid #d7dce3;
      border-radius: 6px;
      padding: 14px;
    }
    .status {
      color: #14532d;
      font-size: 14px;
      line-height: 1.5;
      white-space: pre-wrap;
    }
    .muted {
      color: #667085;
      font-size: 13px;
      line-height: 1.45;
    }
  </style>
</head>
<body>
  <div class="wrap">
    <div>
      <div id="screen" class="screen">
        <img id="screenshot" alt="Current iPhone screenshot" src="data:image/png;base64,${screenshotBase64}">
      </div>
      <p class="muted">只点一次截图，坐标会立刻写入配置里的 ${escapeHtml(label)} 点。</p>
    </div>
    <div class="panel">
      <h2>Pick ${escapeHtml(label)} Point</h2>
      <p class="muted">Viewport: ${escapeHtml(viewport.width)} x ${escapeHtml(viewport.height)} points</p>
      <div id="status" class="status">等待你点击截图...</div>
    </div>
  </div>
  <script>
    const viewport = ${viewportJson};
    const label = ${labelJson};
    const screen = document.getElementById('screen');
    const screenshot = document.getElementById('screenshot');
    const status = document.getElementById('status');

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

    function renderMarker(point) {
      screen.querySelectorAll('.marker').forEach((node) => node.remove());
      const marker = document.createElement('div');
      marker.className = 'marker';
      marker.style.left = point.leftPercent + '%';
      marker.style.top = point.topPercent + '%';
      marker.textContent = label;
      screen.appendChild(marker);
    }

    screen.addEventListener('click', async (event) => {
      if (event.target !== screenshot && event.target !== screen) {
        return;
      }

      const point = appiumPoint(event);
      renderMarker(point);
      status.textContent = '保存中... x=' + point.x + ', y=' + point.y;

      const response = await fetch('/pick', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ x: point.x, y: point.y }),
      });
      const body = await response.json();
      if (!response.ok) {
        status.textContent = body.error || '保存失败';
        return;
      }
      status.textContent = '已保存 ' + label + ': x=' + body.x + ', y=' + body.y + '\\n可以关闭这个页面。';
    });
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

  console.log(`Capturing current iPhone screen for ${options.label}...`);
  const snapshot = await createSnapshot(config);

  let saved = false;
  const server = http.createServer(async (request, response) => {
    try {
      if (request.method === 'GET' && request.url === '/') {
        response.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
        response.end(pickHtml({
          screenshotBase64: snapshot.screenshotBase64,
          viewport: snapshot.viewport,
          label: options.label,
        }));
        return;
      }

      if (request.method === 'POST' && request.url === '/pick') {
        const body = await parseJsonBody(request);
        if (!Number.isFinite(body.x) || !Number.isFinite(body.y)) {
          response.writeHead(400, { 'content-type': 'application/json' });
          response.end(JSON.stringify({ error: 'x and y must be numbers' }));
          return;
        }

        const latestConfig = await readJson(configPath);
        const target = latestConfig.sequence?.find(
          (step) => step.type === 'tap' && step.label === options.label
        );
        if (!target) {
          response.writeHead(404, { 'content-type': 'application/json' });
          response.end(JSON.stringify({ error: `No tap step with label ${options.label}` }));
          return;
        }

        target.x = body.x;
        target.y = body.y;
        await writeJsonAtomic(configPath, latestConfig);
        saved = true;
        console.log(`Saved ${options.label}: x=${body.x}, y=${body.y}`);
        response.writeHead(200, { 'content-type': 'application/json' });
        response.end(JSON.stringify({ ok: true, label: options.label, x: body.x, y: body.y }));
        setTimeout(() => {
          server.close(() => process.exit(0));
          server.closeIdleConnections?.();
          setTimeout(() => server.closeAllConnections?.(), 1000).unref();
        }, 500);
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
  console.log(`Pick ${options.label} here: http://127.0.0.1:${options.port}/`);
  console.log('Click once on the screenshot. The coordinate will be saved immediately.');

  process.once('SIGINT', () => {
    if (!saved) {
      console.log('Stopped before saving a point.');
    }
    server.close(() => process.exit(0));
    server.closeIdleConnections?.();
    setTimeout(() => server.closeAllConnections?.(), 1000).unref();
  });
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
