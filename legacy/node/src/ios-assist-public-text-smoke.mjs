#!/usr/bin/env node
import { publicErrorMessage, publicText } from './ios-assist-public-text.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function main() {
  const localPath = `/${['Users', 'example', 'project', 'config.json'].join('/')}`;
  const privatePath = `/${['private', 'tmp', 'example.log'].join('/')}`;
  const bareTmpPath = '/tmp';
  const deviceId = ['ABCDEF12', '34567890ABCDEF12'].join('-');
  const legacyDeviceId = [
    '01234567',
    '89abcdef',
    '01234567',
    '89ABCDEF',
    '01234567',
  ].join('');
  const text = publicText(`path=${localPath} tmp=${privatePath} bare=${bareTmpPath} udid=${deviceId} legacy=${legacyDeviceId}`);
  assert(!text.includes(localPath), 'Public text should redact user paths');
  assert(!text.includes('/private/tmp'), 'Public text should redact private paths');
  assert(!text.includes('/tmp'), 'Public text should redact bare temp paths');
  assert(!text.includes(deviceId), 'Public text should redact iOS device identifiers');
  assert(!text.includes(legacyDeviceId), 'Public text should redact legacy unhyphenated iOS device identifiers');
  assert(text.includes('[path]'), 'Public text should include path placeholder');
  assert(text.includes('[device-id]'), 'Public text should include device placeholder');

  const error = publicErrorMessage(new Error(`failed at ${localPath}`));
  assert(!error.includes(localPath), 'Public error message should redact paths');

  console.log('Public text smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
