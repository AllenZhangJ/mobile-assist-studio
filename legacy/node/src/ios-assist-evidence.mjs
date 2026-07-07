import { appendFile, mkdir, readdir, rm, stat, writeFile } from 'node:fs/promises';
import { join, relative, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { publicPayload } from './ios-assist-public-payload.mjs';

const DEFAULT_ROOT = 'recordings';
const DEFAULT_MAX_RECORDS = 50;
const DEFAULT_MAX_AGE_MS = 24 * 60 * 60 * 1000;

function compactTimestamp(value = new Date()) {
  return value.toISOString().replaceAll(':', '').replaceAll('.', '-');
}

function sanitizePart(value, fallback = 'item') {
  const text = String(value ?? fallback)
    .trim()
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return text || fallback;
}

function removeScreenshotPayload(value) {
  if (typeof value === 'string') {
    return publicPayload(value);
  }
  if (!value || typeof value !== 'object') {
    return value;
  }

  if (Array.isArray(value)) {
    return value.map(removeScreenshotPayload);
  }

  const copy = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === 'dataUrl') {
      continue;
    }
    copy[key] = removeScreenshotPayload(child);
  }
  return copy;
}

function decodePngDataUrl(dataUrl) {
  const match = /^data:image\/png;base64,([a-zA-Z0-9+/=]+)$/.exec(dataUrl ?? '');
  if (!match) {
    throw new Error('Screenshot payload is not a PNG data URL');
  }
  return Buffer.from(match[1], 'base64');
}

export class EvidenceStore {
  constructor({
    root = DEFAULT_ROOT,
    maxRecords = DEFAULT_MAX_RECORDS,
    maxAgeMs = DEFAULT_MAX_AGE_MS,
  } = {}) {
    this.root = root;
    this.maxRecords = maxRecords;
    this.maxAgeMs = maxAgeMs;
    this.activeRecordId = null;
    this.sessionRecordId = `session-${compactTimestamp()}-${randomUUID().slice(0, 8)}`;
    this.queue = Promise.resolve();
  }

  summary() {
    return {
      root: this.publicRootPath(),
      activeRecordId: this.activeRecordId,
      sessionRecordId: this.sessionRecordId,
      maxRecords: this.maxRecords,
      maxAgeHours: Math.round(this.maxAgeMs / (60 * 60 * 1000)),
    };
  }

  enqueue(work) {
    const next = this.queue.then(work, work);
    this.queue = next.catch(() => {});
    return next;
  }

  recordPath(recordId) {
    return join(this.root, sanitizePart(recordId, 'record'));
  }

  publicRootPath() {
    const absoluteRoot = resolve(process.cwd(), this.root);
    const relativePath = relative(process.cwd(), absoluteRoot).replaceAll('\\', '/');
    if (relativePath && !relativePath.startsWith('../') && relativePath !== '..') {
      return relativePath;
    }
    return 'external-evidence';
  }

  publicPath(filePath) {
    const relativePath = relative(process.cwd(), filePath).replaceAll('\\', '/');
    if (relativePath && !relativePath.startsWith('../') && relativePath !== '..') {
      return relativePath;
    }
    return join('external-evidence', sanitizePart(filePath.split(/[\\/]/).at(-1), 'file'))
      .replaceAll('\\', '/');
  }

  async ensureRecord(recordId, metadata = {}) {
    const dir = this.recordPath(recordId);
    await mkdir(dir, { recursive: true });
    if (Object.keys(metadata).length > 0) {
      await writeFile(join(dir, 'metadata.json'), `${JSON.stringify(removeScreenshotPayload(metadata), null, 2)}\n`, 'utf8');
    }
    return dir;
  }

  async cleanupRecords() {
    await mkdir(this.root, { recursive: true });
    const entries = await readdir(this.root, { withFileTypes: true });
    const dirs = [];
    for (const entry of entries) {
      if (!entry.isDirectory()) {
        continue;
      }
      const dirPath = join(this.root, entry.name);
      const info = await stat(dirPath);
      dirs.push({ name: entry.name, path: dirPath, mtimeMs: info.mtimeMs });
    }

    const now = Date.now();
    const oldRecords = dirs.filter((dir) => now - dir.mtimeMs > this.maxAgeMs);
    const extraRecords = dirs
      .filter((dir) => !oldRecords.some((old) => old.path === dir.path))
      .sort((a, b) => b.mtimeMs - a.mtimeMs)
      .slice(this.maxRecords);

    const targets = new Map();
    for (const dir of [...oldRecords, ...extraRecords]) {
      if (dir.name === this.activeRecordId || dir.name === this.sessionRecordId) {
        continue;
      }
      targets.set(dir.path, dir);
    }

    for (const dir of targets.values()) {
      await rm(dir.path, { recursive: true, force: true });
    }
  }

  startRun(metadata = {}) {
    return this.enqueue(async () => {
      const recordId = `run-${compactTimestamp()}-${randomUUID().slice(0, 8)}`;
      this.activeRecordId = recordId;
      await this.ensureRecord(recordId, {
        kind: 'run',
        startedAt: new Date().toISOString(),
        ...metadata,
      });
      await this.cleanupRecords();
      return { recordId, path: this.recordPath(recordId) };
    });
  }

  finishRun(metadata = {}) {
    return this.enqueue(async () => {
      if (!this.activeRecordId) {
        return null;
      }
      const recordId = this.activeRecordId;
      const dir = await this.ensureRecord(recordId);
      await writeFile(join(dir, 'finished.json'), `${JSON.stringify({
        finishedAt: new Date().toISOString(),
        ...removeScreenshotPayload(metadata),
      }, null, 2)}\n`, 'utf8');
      this.activeRecordId = null;
      await this.cleanupRecords();
      return { recordId };
    });
  }

  activeOrSessionRecordId() {
    return this.activeRecordId ?? this.sessionRecordId;
  }

  recordEvent(event) {
    return this.enqueue(async () => {
      const recordId = this.activeOrSessionRecordId();
      const dir = await this.ensureRecord(recordId, {
        kind: this.activeRecordId ? 'run' : 'session',
      });
      const entry = removeScreenshotPayload(event);
      await appendFile(join(dir, 'events.jsonl'), `${JSON.stringify(entry)}\n`, 'utf8');
      return {
        recordId,
        path: this.publicPath(join(dir, 'events.jsonl')),
      };
    });
  }

  saveScreenshot(screenshot, metadata = {}) {
    return this.enqueue(async () => {
      const recordId = this.activeOrSessionRecordId();
      const dir = await this.ensureRecord(recordId, {
        kind: this.activeRecordId ? 'run' : 'session',
      });
      const reason = sanitizePart(screenshot.reason ?? metadata.reason ?? 'screenshot', 'screenshot');
      const uniqueSuffix = randomUUID().slice(0, 8);
      const filename = `screenshot-${compactTimestamp()}-${uniqueSuffix}-${reason}.png`;
      const filePath = join(dir, filename);
      const bytes = decodePngDataUrl(screenshot.dataUrl);
      await writeFile(filePath, bytes);
      const publicPath = this.publicPath(filePath);
      const entry = {
        at: screenshot.at,
        reason: screenshot.reason,
        mimeType: screenshot.mimeType,
        durationMs: screenshot.durationMs,
        file: {
          path: publicPath,
          bytes: bytes.length,
        },
        metadata: removeScreenshotPayload(metadata),
      };
      await appendFile(join(dir, 'screenshots.jsonl'), `${JSON.stringify(entry)}\n`, 'utf8');
      await this.cleanupRecords();
      return {
        ...screenshot,
        file: {
          path: publicPath,
          bytes: bytes.length,
        },
        recordId,
      };
    });
  }
}
