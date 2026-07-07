#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { readdir } from 'node:fs/promises';
import { join } from 'node:path';

const LEGACY_SOURCE_DIR = join('legacy', 'node', 'src');

// 列出归档 Node 源文件，供 legacy:check 逐个做语法校验。
async function listLegacySourceFiles() {
  const entries = await readdir(LEGACY_SOURCE_DIR, { withFileTypes: true });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith('.mjs'))
    .map((entry) => join(LEGACY_SOURCE_DIR, entry.name).replaceAll('\\', '/'))
    .sort();
}

// 运行单个 node --check，并保留原始错误输出便于排查。
function checkFile(filePath) {
  return new Promise((resolve, reject) => {
    const child = spawn('node', ['--check', filePath], { stdio: 'inherit' });
    child.on('error', reject);
    child.on('exit', (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`node --check ${filePath} exited with code ${code}`));
    });
  });
}

// 程序入口：校验归档区所有 Node 文件的语法。
async function main() {
  const files = await listLegacySourceFiles();
  if (files.length === 0) {
    throw new Error('No legacy Node source files found');
  }

  for (const filePath of files) {
    await checkFile(filePath);
  }
  console.log(`Legacy Node check passed (${files.length} files checked)`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
