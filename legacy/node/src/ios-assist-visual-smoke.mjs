#!/usr/bin/env node
import { analyzeVisualSnapshot } from './ios-assist-visual.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function pngDataUrl(width, height) {
  const bytes = Buffer.alloc(24);
  Buffer.from('89504e470d0a1a0a', 'hex').copy(bytes, 0);
  bytes.writeUInt32BE(13, 8);
  bytes.write('IHDR', 12, 'ascii');
  bytes.writeUInt32BE(width, 16);
  bytes.writeUInt32BE(height, 20);
  return `data:image/png;base64,${bytes.toString('base64')}`;
}

async function main() {
  const clear = analyzeVisualSnapshot({
    reason: 'clear-screen',
    screenshot: {
      dataUrl: pngDataUrl(390, 844),
    },
    source: '<App><Window /></App>',
  });
  assert(clear.screenshot.width === 390, 'Visual analyzer should read PNG width');
  assert(clear.screenshot.height === 844, 'Visual analyzer should read PNG height');
  assert(clear.decision.action === 'continue', 'Clear screen should continue');

  const alert = analyzeVisualSnapshot({
    reason: 'alert-screen',
    screenshot: {
      dataUrl: pngDataUrl(390, 844),
    },
    source: '<XCUIElementTypeAlert><XCUIElementTypeButton name="OK" /></XCUIElementTypeAlert>',
  });
  assert(alert.decision.action === 'pause', 'Known iOS alert should pause');
  assert(alert.decision.confidence >= 0.9, 'Known iOS alert should be high confidence');
  assert(alert.checks.some((check) => check.id === 'ios.system-alert'), 'Known alert check should be present');

  console.log('Visual smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
