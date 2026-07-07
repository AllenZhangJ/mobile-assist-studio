const WORKFLOW_WRITE_BLOCKING_SESSION_PHASES = new Set([
  'initializing',
  'connecting',
  'waitingForDeveloperTrust',
  'disconnecting',
]);

export function workflowWriteBlockReason({ sessionSnapshot, runnerSnapshot } = {}) {
  if (runnerSnapshot?.active) {
    return 'A run is active. Stop it before changing workflow.';
  }

  const phase = sessionSnapshot?.phase;
  if (WORKFLOW_WRITE_BLOCKING_SESSION_PHASES.has(phase)) {
    return `Connection lifecycle is ${phase}. Wait until it is connected or disconnected before changing workflow.`;
  }

  return null;
}

export function manualDeviceCommandBlockReason({ sessionSnapshot, runnerSnapshot, deviceCommandSnapshot } = {}) {
  if (runnerSnapshot?.active) {
    return 'A run is active. Stop it before sending manual device commands.';
  }

  if (deviceCommandSnapshot?.active) {
    return `A device command is active (${deviceCommandSnapshot.name}). Wait until it finishes before sending another device command.`;
  }

  if (sessionSnapshot?.phase !== 'connected') {
    return 'WDA/WebDriver is not connected. Connect first.';
  }

  return null;
}
