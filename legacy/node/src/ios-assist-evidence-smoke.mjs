#!/usr/bin/env node
import { mkdtemp, readFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { EvidenceStore } from './ios-assist-evidence.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

async function main() {
  const root = await mkdtemp(join(tmpdir(), 'ios-assist-evidence-'));
  const store = new EvidenceStore({
    root,
    maxRecords: 2,
    maxAgeMs: 24 * 60 * 60 * 1000,
  });

  const run = await store.startRun({ type: 'runStart', loops: 1 });
  assert(run.recordId.startsWith('run-'), 'Run evidence should use a run record id');

  await store.recordEvent({
    type: 'stepStart',
    step: { type: 'tap', label: 'A', x: 10, y: 20 },
    dataUrl: 'data:image/png;base64,ignored',
  });
  const localPath = `${process.env.HOME || '/tmp/example-home'}/Documents/project/file.txt`;
  const deviceId = [
    '00000000',
    '00000000',
    '0000000000000000',
  ].join('-');
  await store.recordEvent({
    type: 'runError',
    message: `failed at ${localPath} on ${deviceId}`,
  });

  const saved = await store.saveScreenshot({
    at: new Date().toISOString(),
    reason: 'run-error',
    mimeType: 'image/png',
    dataUrl: `data:image/png;base64,${Buffer.from('png').toString('base64')}`,
    durationMs: 3,
  });
  assert(saved.file?.path.includes('screenshot-'), 'Saved screenshot should expose a relative file path');
  assert(!saved.file.path.startsWith('/'), 'Saved screenshot path should not be absolute');
  assert(!saved.file.path.includes('../'), 'Saved screenshot path should not escape through parent segments');
  assert(saved.file.bytes === 3, 'Saved screenshot should report file bytes');

  const secondSaved = await store.saveScreenshot({
    at: saved.at,
    reason: 'run-error',
    mimeType: 'image/png',
    dataUrl: `data:image/png;base64,${Buffer.from('png2').toString('base64')}`,
    durationMs: 4,
  });
  assert(secondSaved.file.path !== saved.file.path, 'Screenshots with the same timestamp and reason should not overwrite each other');
  assert(!secondSaved.file.path.includes('../'), 'Second screenshot path should not escape through parent segments');

  await store.finishRun({ status: 'ok' });

  const entries = await readdir(root);
  assert(entries.length === 1, 'Evidence store should create one record directory');
  const eventLines = await readFile(join(root, entries[0], 'events.jsonl'), 'utf8');
  assert(eventLines.includes('"stepStart"'), 'Evidence event log should include run events');
  assert(!eventLines.includes('data:image/png'), 'Evidence event log should not duplicate screenshot data URLs');
  assert(!eventLines.includes(localPath), 'Evidence event log should not expose local paths');
  assert(!eventLines.includes(deviceId), 'Evidence event log should not expose device identifiers');
  assert(eventLines.includes('[path]'), 'Evidence event log should include redacted path marker');
  assert(eventLines.includes('[device-id]'), 'Evidence event log should include redacted device marker');

  const queuedRoot = await mkdtemp(join(tmpdir(), 'ios-assist-evidence-queued-'));
  const queuedStore = new EvidenceStore({ root: queuedRoot });
  const startPromise = queuedStore.startRun({ type: 'runStart', loops: 1 });
  const eventPromise = queuedStore.recordEvent({ type: 'runEnd', status: 'ok' });
  const finishPromise = queuedStore.finishRun({ status: 'ok' });
  const [queuedRun, queuedEvent, queuedFinish] = await Promise.all([startPromise, eventPromise, finishPromise]);
  assert(queuedRun.recordId === queuedEvent.recordId, 'Queued event should be written into the active run record');
  assert(queuedRun.recordId === queuedFinish.recordId, 'Queued finish should close the same run record');
  assert(queuedStore.summary().activeRecordId === null, 'Queued finish should clear the active run record');

  const externalRoot = await mkdtemp(join(tmpdir(), 'ios-assist-external-evidence-'));
  const externalStore = new EvidenceStore({ root: externalRoot });
  const externalSummary = externalStore.summary();
  assert(externalSummary.root === 'external-evidence', 'External evidence root should be hidden in public summary');
  const externalScreenshot = await externalStore.saveScreenshot({
    at: new Date().toISOString(),
    reason: 'external',
    mimeType: 'image/png',
    dataUrl: `data:image/png;base64,${Buffer.from('png3').toString('base64')}`,
    durationMs: 5,
  });
  assert(externalScreenshot.file.path.startsWith('external-evidence/'), 'External screenshot path should use a safe public prefix');
  assert(!externalScreenshot.file.path.includes(externalRoot), 'External screenshot path should not expose its absolute root');

  console.log('Evidence smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
