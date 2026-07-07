import { EventEmitter } from 'node:events';
import { spawn } from 'node:child_process';
import { createRequire } from 'node:module';
import { readFile, rename, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import process from 'node:process';

const require = createRequire(import.meta.url);

const IOS_DEVICE_USBMUX = 'appium-xcuitest-driver/node_modules/appium-ios-device/build/lib/usbmux';
const DEFAULT_DERIVED_DATA_PATH = '/private/tmp/ios-assist-studio-wda-derived';
const DEFAULT_TRUST_RETRY_LIMIT = 12;
const DEFAULT_TRUST_RETRY_DELAY_MS = 5000;
const DEFAULT_DISCONNECT_CONNECT_WAIT_TIMEOUT_MS = 5000;
const DEFAULT_DELETE_SESSION_TIMEOUT_MS = 5000;

export function sleep(ms) {
  return new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
}

export async function withTimeout(promise, timeoutMs, message) {
  let timer;
  try {
    return await Promise.race([
      Promise.resolve(promise),
      new Promise((_, rejectTimeout) => {
        timer = setTimeout(() => rejectTimeout(new Error(message)), timeoutMs);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

export async function readJson(filePath) {
  return JSON.parse(await readFile(filePath, 'utf8'));
}

export async function writeJsonAtomic(filePath, value) {
  const temporaryPath = `${filePath}.tmp-${process.pid}-${Date.now()}`;
  try {
    await writeFile(temporaryPath, `${JSON.stringify(value, null, 2)}\n`, 'utf8');
    await rename(temporaryPath, filePath);
  } catch (error) {
    await rm(temporaryPath, { force: true });
    throw error;
  }
}

async function writeJson(filePath, value) {
  await writeJsonAtomic(filePath, value);
}

function numberOrDefault(value, fallback) {
  return Number.isFinite(value) ? value : fallback;
}

function integerOrDefault(value, fallback) {
  return Number.isInteger(value) ? value : fallback;
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

export function capabilityValue(capabilities, name) {
  return capabilities?.[`appium:${name}`] ?? capabilities?.[name];
}

function normalizeBasePath(path) {
  if (!path || path === '/') {
    return '';
  }

  return path.startsWith('/') ? path : `/${path}`;
}

export function appiumStatusUrl(appium) {
  const hostname = appium?.hostname ?? '127.0.0.1';
  const port = appium?.port ?? 4723;
  const basePath = normalizeBasePath(appium?.path);
  return `http://${hostname}:${port}${basePath}/status`;
}

export async function isAppiumReady(appium, { timeoutMs = 1500 } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
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
    clearTimeout(timer);
  }
}

export async function listUsbmuxDevices() {
  const { Usbmux, getDefaultSocket } = require(IOS_DEVICE_USBMUX);
  let usbmux;

  try {
    usbmux = new Usbmux(await getDefaultSocket());
  } catch (error) {
    throw new Error(`Unable to connect to usbmuxd: ${error.message}`);
  }

  try {
    const devices = await usbmux.listDevices();
    return devices.map((device) => ({
      udid: device?.Properties?.SerialNumber,
      connectionType: device?.Properties?.ConnectionType ?? 'unknown',
      deviceId: device?.Properties?.DeviceID,
      locationId: device?.Properties?.LocationID,
      productId: device?.Properties?.ProductID,
    })).filter((device) => device.udid);
  } finally {
    usbmux.close();
  }
}

function selectDevice(devices) {
  return devices.find((device) => device.connectionType === 'USB') ?? null;
}

function developerTrustErrorText() {
  return '手机还没有信任开发者证书。';
}

function redactDiagnosticText(text) {
  const oneLine = String(text)
    .replace(/\s+/g, ' ')
    .replace(/\/Users\/[^ ]+/g, '[path]')
    .replace(/\/private\/[^ ]+/g, '[path]')
    .replace(/http:\/\/127\.0\.0\.1:\d+[^\s]*/g, '[local-url]')
    .replace(/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{16}/g, '[device]')
    .replace(/[A-Fa-f0-9]{40}/g, '[device]')
    .replace(/[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}/g, '[id]')
    .trim();
  return oneLine.length > 320 ? `${oneLine.slice(0, 320)}...` : oneLine;
}

export function classifyConnectionError(error, diagnosticText = '') {
  const text = `${error?.message ?? error ?? ''}\n${diagnosticText}`;
  const detail = redactDiagnosticText(text);
  if (/Developer App Certificate is not trusted|Developer App is not trusted|explicitly trusted|profile has not been explicitly trusted|invalid code signature.*trusted|not trusted/i.test(text)) {
    return {
      code: 'DEVELOPER_CERT_NOT_TRUSTED',
      message: developerTrustErrorText(),
      detail,
      userAction: '打开手机设置，进入通用 / VPN 与设备管理，信任当前开发者证书后再点重连。',
    };
  }

  if (/Unlock .* to Continue|device is locked|passcode|destination is not ready/i.test(text)) {
    return {
      code: 'DEVICE_LOCKED',
      message: '手机需要先解锁。',
      detail,
      userAction: '解锁 iPhone 并保持亮屏，然后回到看板点重连。',
    };
  }

  if (/Unable to reach Appium|ECONNREFUSED|connect ECONNREFUSED|Timed out while requesting|Appium response was not an object/i.test(text)) {
    return {
      code: 'APPIUM_UNAVAILABLE',
      message: '驱动服务未就绪。',
      detail,
      userAction: '先启动或重启驱动服务，然后重新连接设备。',
    };
  }

  if (/Could not proxy command|socket hang up|port 8100|RemoteXPC|tunnel/i.test(text)) {
    return {
      code: 'WDA_SESSION_NOT_READY',
      message: '手机会话还没有启动成功。',
      detail,
      userAction: '确认手机已解锁并已信任证书，再重新连接；若仍失败，查看本机检查和 Xcode 诊断。',
    };
  }

  if (/xcodebuild failed with code 65|WebDriverAgent/i.test(text)) {
    return {
      code: 'WDA_START_FAILED',
      message: '手机会话启动失败。',
      detail,
      userAction: '查看本机检查和 Xcode 诊断，优先确认证书、签名、Developer Mode 与手机解锁状态。',
    };
  }

  if (/usbmux|device/i.test(text)) {
    return {
      code: 'DEVICE_UNAVAILABLE',
      message: '没有找到可用的 USB iPhone。',
      detail,
      userAction: '保持 USB 连接，解锁手机，并确认这台 Mac 已被信任。',
    };
  }

  return {
    code: 'UNKNOWN',
    message: error?.message ?? String(error),
    detail,
    userAction: '',
  };
}

const classifyError = classifyConnectionError;

function prefixOutput(prefix, chunk, emitLog) {
  const lines = chunk.toString().split(/\r?\n/);
  for (const line of lines) {
    if (line.length > 0) {
      emitLog(prefix, redactDiagnosticText(line));
    }
  }
}

function startAppiumServer(appium, emitLog) {
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

  emitLog('system', `Starting Appium: ${summarizeCommand(command)} ${args.join(' ')}`);
  const child = spawn(command, args, {
    cwd: process.cwd(),
    env: process.env,
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  child.stdout.on('data', (chunk) => prefixOutput('appium', chunk, emitLog));
  child.stderr.on('data', (chunk) => prefixOutput('appium', chunk, emitLog));

  return child;
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

function waitForChildExitOrReady(appium, child, timeoutMs, emitLog, shouldCancel = () => false) {
  return new Promise((resolveReady, rejectReady) => {
    let done = false;
    let timer;

    const finish = (error) => {
      if (done) {
        return;
      }
      done = true;
      clearTimeout(timer);
      child.off('error', onError);
      child.off('exit', onExit);
      if (error) {
        rejectReady(error);
      } else {
        resolveReady();
      }
    };

    const onError = (error) => finish(error);
    const onExit = (code, signal) => finish(new Error(
      signal
        ? `Appium exited before becoming ready with signal ${signal}`
        : `Appium exited before becoming ready with code ${code}`
    ));

    child.once('error', onError);
    child.once('exit', onExit);

    const startedAt = Date.now();
    const check = async () => {
      if (done) {
        return;
      }
      if (shouldCancel()) {
        emitLog('system', 'Appium startup cancelled before readiness.');
        stopAppiumServer(child)
          .then(() => finish())
          .catch((error) => finish(error));
        return;
      }
      if (await isAppiumReady(appium)) {
        emitLog('system', `Appium is ready: ${appiumStatusUrl(appium)}`);
        finish();
        return;
      }
      if (Date.now() - startedAt >= timeoutMs) {
        finish(new Error(`Appium did not become ready within ${timeoutMs}ms`));
        return;
      }
      timer = setTimeout(check, 500);
    };

    check();
  });
}

function buildConnection(config) {
  const appium = config.appium;
  return {
    hostname: appium.hostname ?? '127.0.0.1',
    port: appium.port ?? 4723,
    path: appium.path ?? '/',
    logLevel: appium.logLevel ?? 'silent',
    connectionRetryCount: numberOrDefault(appium.connectionRetryCount, 0),
    connectionRetryTimeout: numberOrDefault(appium.connectionRetryTimeout, 120000),
    capabilities: appium.capabilities,
  };
}

function wdaBundleId(config) {
  return capabilityValue(config.appium?.capabilities, 'updatedWDABundleId') ?? 'com.facebook.WebDriverAgentRunner';
}

function trustRetryLimit(config) {
  return Math.max(0, integerOrDefault(config.appium?.trustRetryLimit, DEFAULT_TRUST_RETRY_LIMIT));
}

function trustRetryDelayMs(config) {
  return Math.max(0, numberOrDefault(config.appium?.trustRetryDelayMs, DEFAULT_TRUST_RETRY_DELAY_MS));
}

async function waitForTrustRetry(delayMs, shouldCancel) {
  const startedAt = Date.now();
  while (!shouldCancel() && Date.now() - startedAt < delayMs) {
    await sleep(Math.min(100, delayMs - (Date.now() - startedAt)));
  }
}

async function runWdaTrustDiagnostic(config, udid, emitLog) {
  const projectPath = 'node_modules/appium-xcuitest-driver/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj';
  const args = [
    '-quiet',
    '-project',
    projectPath,
    '-scheme',
    'WebDriverAgentRunner',
    '-destination',
    `id=${udid}`,
  ];

  const xcodeConfigFile = capabilityValue(config.appium?.capabilities, 'xcodeConfigFile');
  if (xcodeConfigFile) {
    args.push('-xcconfig', xcodeConfigFile);
  }
  args.push(
    '-derivedDataPath',
    DEFAULT_DERIVED_DATA_PATH,
    '-allowProvisioningUpdates',
    '-allowProvisioningDeviceRegistration',
    `PRODUCT_BUNDLE_IDENTIFIER=${wdaBundleId(config)}`,
    'test'
  );

  emitLog('system', 'Running WDA trust diagnostic...');
  return new Promise((resolveDiagnostic) => {
    const child = spawn('xcodebuild', args, {
      cwd: process.cwd(),
      env: process.env,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let output = '';
    const collect = (chunk) => {
      output += chunk.toString();
      if (output.length > 80000) {
        output = output.slice(-80000);
      }
    };

    const timer = setTimeout(() => {
      child.kill('SIGTERM');
      output += '\nWDA diagnostic timed out.';
    }, 25000);

    child.stdout.on('data', collect);
    child.stderr.on('data', collect);
    child.once('exit', () => {
      clearTimeout(timer);
      resolveDiagnostic(output);
    });
    child.once('error', (error) => {
      clearTimeout(timer);
      resolveDiagnostic(error.message);
    });
  });
}

export class AssistSession extends EventEmitter {
  constructor({
    configPath,
    disconnectConnectWaitTimeoutMs = DEFAULT_DISCONNECT_CONNECT_WAIT_TIMEOUT_MS,
    deleteSessionTimeoutMs = DEFAULT_DELETE_SESSION_TIMEOUT_MS,
  }) {
    super();
    this.configPath = configPath;
    this.absoluteConfigPath = resolve(process.cwd(), configPath);
    this.disconnectConnectWaitTimeoutMs = disconnectConnectWaitTimeoutMs;
    this.deleteSessionTimeoutMs = deleteSessionTimeoutMs;
    this.phase = 'disconnected';
    this.device = null;
    this.error = null;
    this.driver = null;
    this.appiumProcess = null;
    this.startedAppium = false;
    this.connectPromise = null;
    this.disconnectPromise = null;
    this.waitingForTrust = false;
    this.disconnectRequested = false;
    this.trustRetryCount = 0;
    this.trustRetryLimit = DEFAULT_TRUST_RETRY_LIMIT;
  }

  emitLog(stream, message) {
    this.emit('log', { stream, message });
  }

  setPhase(phase, extra = {}) {
    this.phase = phase;
    if ('error' in extra) {
      this.error = extra.error;
    }
    if ('device' in extra) {
      this.device = extra.device;
    }
    if ('waitingForTrust' in extra) {
      this.waitingForTrust = extra.waitingForTrust;
    }
    this.emit('status', this.snapshot());
  }

  snapshot() {
    return {
      phase: this.phase,
      connected: Boolean(this.driver),
      device: this.device,
      error: this.error,
      appiumStartedByConsole: this.startedAppium,
      waitingForTrust: this.waitingForTrust,
      trustRetryCount: this.trustRetryCount,
      trustRetryLimit: this.trustRetryLimit,
    };
  }

  async loadConfig() {
    return readJson(this.absoluteConfigPath);
  }

  async initializeDevice() {
    const config = await this.loadConfig();
    const devices = await listUsbmuxDevices();
    const selected = selectDevice(devices);
    if (!selected) {
      throw new Error('No wired iOS device was found through Appium/usbmux.');
    }

    config.appium ??= {};
    config.appium.capabilities ??= {};
    config.appium.capabilities['appium:udid'] = selected.udid;
    config.appium.lastInit = {
      initializedAt: new Date().toISOString(),
      selectedUdid: selected.udid,
      source: 'appium-ios-device/usbmux',
      selection: 'first-usb-device',
      device: selected,
    };
    await writeJson(this.absoluteConfigPath, config);
    this.device = selected;
    this.emitLog('system', `Initialized connected device: ${summarizeIdentifier(selected.udid)} (${selected.connectionType})`);
    return { config, selected };
  }

  async ensureAppium(config) {
    const appium = config.appium;
    if (await isAppiumReady(appium)) {
      this.emitLog('system', `Using existing Appium server: ${appiumStatusUrl(appium)}`);
      this.startedAppium = false;
      return;
    }

    this.appiumProcess = startAppiumServer(appium, (stream, message) => this.emitLog(stream, message));
    this.startedAppium = true;
    await waitForChildExitOrReady(
      appium,
      this.appiumProcess,
      numberOrDefault(appium.startupTimeoutMs, 60000),
      (stream, message) => this.emitLog(stream, message),
      () => this.disconnectRequested
    );
  }

  async createDriver(config, selected) {
    const { remote } = await import('webdriverio');
    const connection = buildConnection(config);
    this.emitLog('system', `Connecting WebDriver session to ${connection.hostname}:${connection.port}${connection.path}`);
    try {
      return await remote(connection);
    } catch (error) {
      if (/xcodebuild failed with code 65|WebDriverAgent/i.test(error.message)) {
        const diagnosticText = await runWdaTrustDiagnostic(
          config,
          selected.udid,
          (stream, message) => this.emitLog(stream, message)
        );
        const classified = classifyError(error, diagnosticText);
        if (classified.code === 'DEVELOPER_CERT_NOT_TRUSTED') {
          throw Object.assign(new Error(classified.message), { classified });
        }
        throw Object.assign(error, { classified });
      }
      throw Object.assign(error, { classified: classifyError(error) });
    }
  }

  async connect({ retryTrust = true } = {}) {
    if (this.disconnectPromise || this.phase === 'disconnecting') {
      throw new Error('Disconnect is in progress. Wait until it finishes before connecting again.');
    }
    if (this.connectPromise) {
      if (this.disconnectRequested) {
        throw new Error('Disconnect is in progress. Wait until it finishes before connecting again.');
      }
      return this.connectPromise;
    }
    if (this.driver) {
      return this.snapshot();
    }

    this.disconnectRequested = false;
    this.connectPromise = this.connectInternal({ retryTrust })
      .finally(() => {
        this.connectPromise = null;
      });
    return this.connectPromise;
  }

  async connectInternal({ retryTrust }) {
    this.error = null;
    this.trustRetryCount = 0;
    this.trustRetryLimit = DEFAULT_TRUST_RETRY_LIMIT;
    this.setPhase('initializing', { waitingForTrust: false });

    try {
      const { config, selected } = await this.initializeDevice();
      this.trustRetryLimit = trustRetryLimit(config);
      this.setPhase('connecting', { device: selected, waitingForTrust: false });
      await this.ensureAppium(config);
      const maxTrustRetries = this.trustRetryLimit;
      const trustDelayMs = trustRetryDelayMs(config);

      while (!this.disconnectRequested) {
        try {
          const driver = await this.createDriver(config, selected);
          if (this.disconnectRequested) {
            try {
              await withTimeout(
                driver.deleteSession(),
                this.deleteSessionTimeoutMs,
                `WebDriver session delete timed out after ${this.deleteSessionTimeoutMs}ms`
              );
            } catch (deleteError) {
              this.emitLog('system', `Failed to delete WebDriver session after cancelled connect: ${deleteError.message}`);
            }
            break;
          }
          this.driver = driver;
          this.error = null;
          this.setPhase('connected', { device: selected, waitingForTrust: false });
          this.emitLog('system', 'WDA/WebDriver session is connected and ready.');
          return this.snapshot();
        } catch (error) {
          if (this.disconnectRequested) {
            this.emitLog('system', 'WebDriver connection attempt was cancelled by disconnect.');
            break;
          }
          const classified = error.classified ?? classifyError(error);
          if (retryTrust && classified.code === 'DEVELOPER_CERT_NOT_TRUSTED') {
            if (this.trustRetryCount >= maxTrustRetries) {
              const retryLimitError = {
                ...classified,
                userAction: `${classified.userAction} Then return to the Web console and click reconnect.`,
              };
              this.setPhase('error', {
                error: retryLimitError,
                waitingForTrust: false,
                device: selected,
              });
              this.emitLog(
                'system',
                `Developer certificate trust was not confirmed after ${this.trustRetryCount}/${maxTrustRetries} automatic retry attempt(s). Automatic retries are paused.`
              );
              throw Object.assign(new Error(retryLimitError.message), { classified: retryLimitError });
            }
            this.trustRetryCount += 1;
            this.setPhase('waitingForDeveloperTrust', {
              error: classified,
              waitingForTrust: true,
              device: selected,
            });
            this.emitLog(
              'system',
              `Waiting for iPhone developer certificate trust. Retry ${this.trustRetryCount}/${maxTrustRetries} will run automatically.`
            );
            await waitForTrustRetry(trustDelayMs, () => this.disconnectRequested);
            continue;
          }

          this.setPhase('error', { error: classified, waitingForTrust: false, device: selected });
          throw error;
        }
      }

      this.setPhase('disconnected', { waitingForTrust: false });
      return this.snapshot();
    } catch (error) {
      const classified = error.classified ?? classifyError(error);
      if (!['error', 'waitingForDeveloperTrust'].includes(this.phase)) {
        this.setPhase('error', { error: classified, waitingForTrust: false });
      }
      throw error;
    }
  }

  async disconnect() {
    if (this.disconnectPromise) {
      return this.disconnectPromise;
    }

    this.disconnectPromise = this.disconnectInternal()
      .finally(() => {
        this.disconnectPromise = null;
      });
    return this.disconnectPromise;
  }

  async disconnectInternal() {
    if (
      !this.connectPromise
      && !this.driver
      && !this.startedAppium
      && !this.appiumProcess
      && this.phase === 'disconnected'
    ) {
      return this.snapshot();
    }

    this.disconnectRequested = true;
    this.setPhase('disconnecting', { waitingForTrust: false });

    if (this.connectPromise && !this.driver) {
      try {
        const result = await Promise.race([
          this.connectPromise.then(() => 'settled', () => 'settled'),
          sleep(this.disconnectConnectWaitTimeoutMs).then(() => 'timeout'),
        ]);
        if (result === 'timeout') {
          this.emitLog('system', 'Disconnect is continuing while the pending WebDriver connection attempt winds down.');
        }
      } catch {
        // The active connect attempt is being cancelled; its original error is not actionable here.
      }
    }

    if (this.driver) {
      try {
        await withTimeout(
          this.driver.deleteSession(),
          this.deleteSessionTimeoutMs,
          `WebDriver session delete timed out after ${this.deleteSessionTimeoutMs}ms`
        );
      } catch (error) {
        this.emitLog('system', `Failed to delete WebDriver session: ${error.message}`);
      }
      this.driver = null;
    }

    if (this.startedAppium && this.appiumProcess) {
      await stopAppiumServer(this.appiumProcess);
    }
    this.appiumProcess = null;
    this.startedAppium = false;
    this.setPhase('disconnected', { waitingForTrust: false });
    this.emitLog('system', 'Disconnected WDA/WebDriver session.');
    return this.snapshot();
  }

  async captureScreenshot({ reason = 'manual' } = {}) {
    if (!this.driver) {
      throw new Error('WDA/WebDriver is not connected. Connect first.');
    }

    const startedAt = Date.now();
    const base64 = await this.driver.takeScreenshot();
    return {
      at: new Date().toISOString(),
      reason,
      mimeType: 'image/png',
      dataUrl: `data:image/png;base64,${base64}`,
      durationMs: Date.now() - startedAt,
    };
  }

  async capturePageSource() {
    if (!this.driver) {
      throw new Error('WDA/WebDriver is not connected. Connect first.');
    }
    if (typeof this.driver.getPageSource !== 'function') {
      return '';
    }
    return this.driver.getPageSource();
  }
}
