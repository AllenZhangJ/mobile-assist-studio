#!/usr/bin/env node
import {
  manualDeviceCommandBlockReason,
  workflowWriteBlockReason,
} from './ios-assist-console-guards.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function reasonFor(phase, active = false) {
  return workflowWriteBlockReason({
    sessionSnapshot: { phase },
    runnerSnapshot: { active },
  });
}

function manualReasonFor(phase, active = false, deviceCommandActive = false) {
  return manualDeviceCommandBlockReason({
    sessionSnapshot: { phase },
    runnerSnapshot: { active },
    deviceCommandSnapshot: deviceCommandActive ? { active: true, name: 'manual screenshot' } : { active: false },
  });
}

async function main() {
  assert(reasonFor('disconnected') === null, 'Workflow writes should be allowed while disconnected');
  assert(reasonFor('connected') === null, 'Workflow writes should be allowed while connected and idle');
  assert(/run is active/i.test(reasonFor('connected', true)), 'Workflow writes should be blocked while a run is active');
  assert(/initializing/i.test(reasonFor('initializing')), 'Workflow writes should be blocked during initialization');
  assert(/connecting/i.test(reasonFor('connecting')), 'Workflow writes should be blocked during WDA connection');
  assert(/waitingForDeveloperTrust/i.test(reasonFor('waitingForDeveloperTrust')), 'Workflow writes should be blocked while waiting for trust');
  assert(/disconnecting/i.test(reasonFor('disconnecting')), 'Workflow writes should be blocked during disconnect');
  assert(manualReasonFor('connected') === null, 'Manual device commands should be allowed only while connected and idle');
  assert(/run is active/i.test(manualReasonFor('connected', true)), 'Manual device commands should be blocked while a run is active');
  assert(/device command is active/i.test(manualReasonFor('connected', false, true)), 'Manual device commands should be blocked while another device command is active');
  assert(/not connected/i.test(manualReasonFor('disconnected')), 'Manual device commands should be blocked while disconnected');
  assert(/not connected/i.test(manualReasonFor('connecting')), 'Manual device commands should be blocked during connection lifecycle');
  console.log('Console guard smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
