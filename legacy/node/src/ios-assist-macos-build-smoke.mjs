#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { access } from 'node:fs/promises';
import { join } from 'node:path';

const APP_DIR = join('apps', 'studio_mac');
const BUILT_APP = join(APP_DIR, 'build', 'macos', 'Build', 'Products', 'Debug', 'studio_mac.app');

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function run(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      stdio: 'inherit',
      env: {
        ...process.env,
        DART_SUPPRESS_ANALYTICS: 'true',
        FLUTTER_SUPPRESS_ANALYTICS: 'true',
      },
      ...options,
    });

    child.on('error', (error) => reject(error));
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`${command} ${args.join(' ')} exited with code ${code}`));
    });
  });
}

async function assertBuiltAppExists() {
  await access(BUILT_APP);
}

async function main() {
  assert(process.platform === 'darwin', 'macOS build smoke must run on macOS.');
  console.log('Building Flutter macOS debug app...');
  await run('fvm', ['flutter', 'build', 'macos', '--debug'], { cwd: APP_DIR });
  await assertBuiltAppExists();
  console.log('macOS build smoke passed');
}

main().catch((error) => {
  if (error.code === 'ENOENT') {
    console.error('fvm command was not found. Install or activate FVM before running the macOS build smoke.');
  } else {
    console.error(error.message);
  }
  process.exitCode = 1;
});
