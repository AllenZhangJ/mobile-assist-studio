#!/usr/bin/env node
import { createDeviceDiscoveryStatus } from './ios-assist-device-discovery.mjs';
import { sleep } from './ios-assist-session.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function main() {
  let calls = 0;
  let resolveProbe;
  const discoverDevices = () => {
    calls += 1;
    return new Promise((resolve) => {
      resolveProbe = resolve;
    });
  };
  const discoverForStatus = createDeviceDiscoveryStatus({
    discoverDevices,
    timeoutMs: 20,
    retryCooldownMs: 30,
    sanitizeError: (error) => error.message,
  });

  const first = await discoverForStatus();
  assert(first.error === 'USB device discovery timed out', 'First hanging probe should time out');
  const second = await discoverForStatus();
  assert(second.error === 'USB device discovery timed out', 'Second status request should use cached timeout during cooldown');
  assert(calls === 1, 'Cooldown should prevent immediate probe fan-out');

  resolveProbe([{ udid: 'device-1', connectionType: 'USB' }]);
  await sleep(40);
  const third = await discoverForStatus();
  assert(calls === 2, 'After cooldown, a new status probe may start');
  assert(third.error === 'USB device discovery timed out', 'New hanging probe should still time out');

  console.log('Device discovery smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
