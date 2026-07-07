import { createRequire } from 'node:module';
import { readFile, rename, rm, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import process from 'node:process';

const require = createRequire(import.meta.url);
const DEFAULT_CONFIG = 'config/connected-device.sequence.json';
const IOS_DEVICE_USBMUX = 'appium-xcuitest-driver/node_modules/appium-ios-device/build/lib/usbmux';

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
    allowNonUsb: false,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === '--config') {
      options.config = readOptionValue(argv, index, '--config');
      index += 1;
      continue;
    }

    if (arg === '--allow-any-usbmux-device') {
      options.allowNonUsb = true;
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
  node legacy/node/src/ios-coordinate-init.mjs
  node legacy/node/src/ios-coordinate-init.mjs --config config/connected-device.sequence.json
  node legacy/node/src/ios-coordinate-init.mjs --allow-any-usbmux-device
`);
}

async function loadConfig(configPath) {
  const absolutePath = resolve(process.cwd(), configPath);
  const contents = await readFile(absolutePath, 'utf8');
  const config = JSON.parse(contents);

  if (!config.appium?.capabilities) {
    throw new Error('Config must include appium.capabilities');
  }

  return { absolutePath, config };
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

async function listUsbmuxDevices() {
  const { Usbmux, getDefaultSocket } = require(IOS_DEVICE_USBMUX);
  let usbmux;

  try {
    usbmux = new Usbmux(await getDefaultSocket());
  } catch (error) {
    throw new Error(`Unable to connect to usbmuxd: ${error.message}`);
  }

  try {
    return await usbmux.listDevices();
  } finally {
    usbmux.close();
  }
}

function deviceUdid(device) {
  return device?.Properties?.SerialNumber;
}

function deviceConnectionType(device) {
  return device?.Properties?.ConnectionType ?? 'unknown';
}

function deviceSummary(device) {
  return {
    udid: deviceUdid(device),
    connectionType: deviceConnectionType(device),
    deviceId: device?.Properties?.DeviceID,
    locationId: device?.Properties?.LocationID,
    productId: device?.Properties?.ProductID,
  };
}

function summarizeIdentifier(value) {
  const text = String(value ?? '');
  if (text.length <= 10) {
    return text;
  }
  return `${text.slice(0, 6)}...${text.slice(-4)}`;
}

function selectDevice(devices, options) {
  const usableDevices = devices.filter((device) => deviceUdid(device));
  const usbDevices = usableDevices.filter((device) => deviceConnectionType(device) === 'USB');

  if (usbDevices.length > 0) {
    return usbDevices[0];
  }

  if (options.allowNonUsb && usableDevices.length > 0) {
    return usableDevices[0];
  }

  return null;
}

function printDevices(devices) {
  if (devices.length === 0) {
    console.log('Detected Appium/usbmux devices: none');
    return;
  }

  console.log('Detected Appium/usbmux devices:');
  devices.forEach((device, index) => {
    const summary = deviceSummary(device);
    console.log(
      `${index + 1}. ${summarizeIdentifier(summary.udid ?? 'unknown')} (${summary.connectionType})`
    );
  });
}

function updateConfig(config, selectedDevice) {
  const selected = deviceSummary(selectedDevice);
  config.appium ??= {};
  config.appium.capabilities ??= {};
  config.appium.capabilities['appium:udid'] = selected.udid;
  config.appium.lastInit = {
    initializedAt: new Date().toISOString(),
    selectedUdid: selected.udid,
    source: 'appium-ios-device/usbmux',
    selection: selected.connectionType === 'USB' ? 'first-usb-device' : 'first-usbmux-device',
    device: selected,
  };
}

function initFailureMessage() {
  return `
No wired iOS device was found through Appium/usbmux.

Fix:
  1. Connect the iPhone with a USB data cable.
  2. Unlock the iPhone and keep it unlocked.
  3. Tap "Trust This Computer" if iOS asks.
  4. Run: idevice_id -l
  5. Re-run: npm run legacy:init:connected
`;
}

async function main() {
  const options = parseArgs(process.argv);
  if (options.help) {
    printHelp();
    return;
  }

  const { absolutePath, config } = await loadConfig(options.config);
  const devices = await listUsbmuxDevices();
  printDevices(devices);

  const selectedDevice = selectDevice(devices, options);
  if (!selectedDevice) {
    throw new Error(initFailureMessage());
  }

  updateConfig(config, selectedDevice);
  await writeJsonAtomic(absolutePath, config);

  const selected = deviceSummary(selectedDevice);
  console.log(`Initialized connected config: ${options.config}`);
  console.log(`Selected device: ${summarizeIdentifier(selected.udid)} (${selected.connectionType})`);
  console.log('Next: npm run legacy:click:connected 1 -- --log-level progress');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
