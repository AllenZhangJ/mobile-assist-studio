#!/usr/bin/env node
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';

const SCAN_ROOTS = [
  'apps/studio_mac/lib',
  'packages/appium_client/lib',
  'packages/studio_design_system/lib',
  'packages/studio_runtime/lib',
  'packages/workflow_dsl/lib',
];

const FORBIDDEN_PATTERNS = [
  {
    pattern: /\bios-assist-console\b/,
    reason: 'Flutter V2.0 主路径不得引用 Legacy Web Console',
  },
  {
    pattern: /\bios-coordinate-[\w-]+/,
    reason: 'Flutter V2.0 主路径不得调用 Legacy 坐标 CLI',
  },
  {
    pattern: /\bnode\s+src\//,
    reason: 'Flutter V2.0 主路径不得通过 Node 脚本作为中间层',
  },
  {
    pattern: /\bnpm\s+run\s+(?:console|click|record|init|pick|start|dry-run|validate)(?::connected)?\b/,
    reason: 'Flutter V2.0 主路径不得调用 Legacy npm 入口',
  },
  {
    pattern: /\b(?:127\.0\.0\.1|localhost):4877\b/,
    reason: 'Flutter V2.0 主路径不得调用 Legacy Web Console 端口',
  },
  {
    pattern: /\/api\/(?:status|workflow|run|runs|events|logs|device|connect|disconnect|init|execute|record|screenshot)\b/,
    reason: 'Flutter V2.0 主路径不得调用 Legacy Web API',
  },
  {
    pattern: /Process\.(?:run|start)\s*\(\s*['"]node['"]/,
    reason: 'Dart Runtime 不得启动 Node 作为产品中间层',
  },
];

// 断言条件成立，失败时用稳定文本结束 smoke。
function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

// 递归列出 Dart 源文件，只扫描 V2.0 产品主路径。
async function listDartFiles(root) {
  const entries = await readdir(root, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const filePath = join(root, entry.name).replaceAll('\\', '/');
    if (entry.isDirectory()) {
      files.push(...await listDartFiles(filePath));
      continue;
    }
    if (entry.isFile() && entry.name.endsWith('.dart')) {
      files.push(filePath);
    }
  }
  return files.sort();
}

// 生成命中上下文，输出文件和行号即可，不回显整段源码。
function violationMessage({ filePath, lineIndex, reason }) {
  return `${filePath}:${lineIndex + 1} violates V2.0 boundary: ${reason}`;
}

// 扫描单个文件，发现 Legacy Node 调用边界立即返回问题列表。
async function scanFile(filePath) {
  const text = await readFile(filePath, 'utf8');
  const lines = text.split(/\r?\n/);
  const violations = [];
  for (let lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    const line = lines[lineIndex];
    for (const rule of FORBIDDEN_PATTERNS) {
      if (rule.pattern.test(line)) {
        violations.push(violationMessage({
          filePath,
          lineIndex,
          reason: rule.reason,
        }));
      }
    }
  }
  return violations;
}

// 扫描所有 V2.0 Dart 源码，确保 Flutter/Dart 主路径不回调 Legacy Node。
async function main() {
  const files = (await Promise.all(SCAN_ROOTS.map(listDartFiles))).flat();
  assert(files.length > 0, 'V2.0 boundary smoke should scan Dart source files');

  const violations = (await Promise.all(files.map(scanFile))).flat();
  assert(
    violations.length === 0,
    `V2.0 boundary smoke failed:\n${violations.join('\n')}`,
  );

  console.log(`V2.0 boundary smoke passed (${files.length} Dart files scanned)`);
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
