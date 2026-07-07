#!/usr/bin/env node
import { publicPayload } from './ios-assist-public-payload.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function main() {
  const home = process.env.HOME || '/tmp/example-home';
  const localPath = `${home}/Documents/project/file.txt`;
  const deviceId = [
    '00000000',
    '00000000',
    '0000000000000000',
  ].join('-');
  const payload = publicPayload({
    message: `failed at ${localPath} on ${deviceId}`,
    nested: {
      dataUrl: 'data:image/png;base64,secret',
      items: [`path=${localPath}`],
    },
  });
  const text = JSON.stringify(payload);
  assert(!text.includes(home), 'Public payload should redact local home paths');
  assert(!text.includes(deviceId), 'Public payload should redact device identifiers');
  assert(!text.includes('data:image/png'), 'Public payload should strip screenshot data URLs');
  assert(text.includes('[path]'), 'Public payload should preserve redacted path marker');
  assert(text.includes('[device-id]'), 'Public payload should preserve redacted device marker');
  console.log('Public payload smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
