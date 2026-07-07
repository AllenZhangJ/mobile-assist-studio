import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, relative, resolve } from 'node:path';
import process from 'node:process';

const DEFAULT_CONFIG = 'config/connected-device.sequence.json';
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
    output: 'recordings/latest-recorder.html',
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

    if (arg === '--output') {
      options.output = readOptionValue(argv, index, '--output');
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
  node legacy/node/src/ios-coordinate-record.mjs --config config/connected-device.sequence.json --start-appium

The recorder captures the current iPhone screenshot and creates an HTML page.
Click the screenshot in order; the page records Appium coordinates and intervals.
`);
}

async function loadConfig(configPath) {
  const absolutePath = resolve(process.cwd(), configPath);
  const contents = await readFile(absolutePath, 'utf8');
  const config = JSON.parse(contents);

  if (!config.appium?.capabilities) {
    throw new Error('Config must include appium.capabilities');
  }

  return config;
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

function publicPath(filePath) {
  const relativePath = relative(process.cwd(), filePath).replaceAll('\\', '/');
  if (relativePath && !relativePath.startsWith('../') && relativePath !== '..') {
    return relativePath;
  }
  return 'external-recorder-output';
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

function createRecorderHtml({ screenshotBase64, viewport, configName }) {
  const viewportJson = JSON.stringify(viewport);
  const configNameJson = JSON.stringify(configName);

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>iOS Coordinate Recorder</title>
  <style>
    :root {
      color-scheme: light;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      background: #f5f6f8;
      color: #1f2328;
    }
    body {
      margin: 0;
      padding: 24px;
    }
    .layout {
      display: grid;
      grid-template-columns: minmax(280px, 430px) minmax(340px, 1fr);
      gap: 20px;
      align-items: start;
    }
    .screen {
      position: relative;
      width: min(100%, 430px);
      border: 1px solid #c9ced6;
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
      background: #ff3b30;
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
      gap: 14px;
    }
    .toolbar {
      display: flex;
      gap: 10px;
      flex-wrap: wrap;
      align-items: center;
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
    table {
      border-collapse: collapse;
      width: 100%;
      background: #fff;
      font-size: 13px;
    }
    th, td {
      border: 1px solid #d7dce3;
      padding: 8px;
      text-align: left;
    }
    th {
      background: #edf0f5;
    }
    textarea {
      width: 100%;
      min-height: 280px;
      box-sizing: border-box;
      border: 1px solid #c9ced6;
      border-radius: 6px;
      padding: 12px;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      font-size: 12px;
      resize: vertical;
      background: #fff;
    }
    .muted {
      color: #667085;
      font-size: 13px;
      line-height: 1.5;
    }
    @media (max-width: 900px) {
      body {
        padding: 14px;
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
      <p class="muted">Click this screenshot in the same order you want the iPhone to tap. The recorder converts image clicks to Appium viewport coordinates.</p>
    </div>
    <div class="panel">
      <div>
        <h2>Coordinate Recorder</h2>
        <p class="muted">Viewport: ${escapeHtml(viewport.width)} x ${escapeHtml(viewport.height)} points. Source config: ${escapeHtml(configName)}.</p>
      </div>
      <div class="toolbar">
        <button id="reset">Reset</button>
        <button id="undo">Undo</button>
        <button id="copy" class="primary">Copy sequence JSON</button>
      </div>
      <table>
        <thead>
          <tr>
            <th>#</th>
            <th>x</th>
            <th>y</th>
            <th>wait after previous</th>
          </tr>
        </thead>
        <tbody id="rows"></tbody>
      </table>
      <textarea id="json" spellcheck="false"></textarea>
      <p class="muted">For the first tap, no wait is added before it. Starting from the second tap, the page inserts a wait equal to the time between clicks.</p>
    </div>
  </div>

  <script>
    const viewport = ${viewportJson};
    const configName = ${configNameJson};
    const points = [];
    const screen = document.getElementById('screen');
    const screenshot = document.getElementById('screenshot');
    const rows = document.getElementById('rows');
    const json = document.getElementById('json');

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

    function sequenceJson() {
      const sequence = [];
      for (const [index, point] of points.entries()) {
        if (index > 0) {
          sequence.push({ type: 'wait', ms: point.waitAfterPreviousMs });
        }
        sequence.push({
          type: 'tap',
          x: point.x,
          y: point.y,
          label: String.fromCharCode(65 + index),
        });
      }
      return JSON.stringify(sequence, null, 2);
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
        row.innerHTML = '<td>' + (index + 1) + '</td><td>' + point.x + '</td><td>' + point.y + '</td><td>' + (index === 0 ? '-' : point.waitAfterPreviousMs + ' ms') + '</td>';
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
        waitAfterPreviousMs: previous ? Math.max(0, clickedAt - previous.clickedAt) : 0,
      });
      render();
    });

    document.getElementById('reset').addEventListener('click', () => {
      points.length = 0;
      render();
    });

    document.getElementById('undo').addEventListener('click', () => {
      points.pop();
      render();
    });

    document.getElementById('copy').addEventListener('click', async () => {
      await navigator.clipboard.writeText(sequenceJson());
    });

    render();
  </script>
</body>
</html>`;
}

async function main() {
  const options = parseArgs(process.argv);

  if (options.help) {
    printHelp();
    return;
  }

  const config = await loadConfig(options.config);
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
    appiumProcess = await ensureAppium(appium, options.startAppium || appium.autoStart === true);
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
    const viewport = {
      width: Math.round(rect.width),
      height: Math.round(rect.height),
    };

    const outputPath = resolve(process.cwd(), options.output);
    await mkdir(dirname(outputPath), { recursive: true });
    await writeFile(outputPath, createRecorderHtml({
      screenshotBase64,
      viewport,
      configName: options.config,
    }));

    console.log(`Recorder written to: ${publicPath(outputPath)}`);
    console.log('Open that HTML file in a browser, click the screenshot, then copy the generated sequence JSON.');
  } finally {
    if (driver) {
      await driver.deleteSession();
    }
    await stopAppiumServer(appiumProcess);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
