#!/usr/bin/env node
import process from 'node:process';
import { capabilityValue, readJson } from './ios-assist-session.mjs';
import {
  resolveExecutableSequence,
  summarizeWorkflowConfig,
  validateSequence,
} from './ios-assist-workflow.mjs';

const DEFAULT_CONFIG = 'config/connected-device.sequence.json';

function readOptionValue(argv, index, name) {
  const value = argv[index + 1];
  if (!value || value.startsWith('--')) {
    throw new Error(`${name} requires a value`);
  }
  return value;
}

function parseArgs(argv) {
  const options = {
    config: DEFAULT_CONFIG,
    json: false,
  };

  for (let index = 2; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === '--config') {
      options.config = readOptionValue(argv, index, '--config');
      index += 1;
      continue;
    }
    if (arg === '--json') {
      options.json = true;
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      options.help = true;
      continue;
    }
    throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function printHelp() {
  console.log(`
Usage:
  node legacy/node/src/ios-assist-validate.mjs --config config/connected-device.sequence.json
  node legacy/node/src/ios-assist-validate.mjs --json
`);
}

function countSequence(sequence) {
  const result = {
    taps: 0,
    waits: 0,
    randomWaits: 0,
    labels: [],
  };

  for (const step of sequence) {
    if (step.type === 'tap') {
      result.taps += 1;
      result.labels.push(step.label ?? `#${result.taps}`);
    } else if (step.type === 'wait') {
      result.waits += 1;
    } else if (step.type === 'waitRandom') {
      result.randomWaits += 1;
    }
  }

  return result;
}

function validateRun(run = {}) {
  const errors = [];
  const loops = run.loops ?? 1;
  const tapDurationMs = run.tapDurationMs ?? 80;
  const initialDelayMs = run.initialDelayMs ?? 0;
  const betweenLoopsDelayMs = run.betweenLoopsDelayMs ?? 0;

  if (!Number.isInteger(loops) || loops < 1) {
    errors.push('run.loops must be a positive integer when provided');
  }
  if (!Number.isFinite(tapDurationMs) || tapDurationMs < 1) {
    errors.push('run.tapDurationMs must be >= 1 when provided');
  }
  if (!Number.isFinite(initialDelayMs) || initialDelayMs < 0) {
    errors.push('run.initialDelayMs must be >= 0 when provided');
  }
  if (!Number.isFinite(betweenLoopsDelayMs) || betweenLoopsDelayMs < 0) {
    errors.push('run.betweenLoopsDelayMs must be >= 0 when provided');
  }

  return errors;
}

function validateCapabilities(capabilities = {}) {
  const errors = [];
  const warnings = [];

  if (capabilityValue(capabilities, 'automationName') !== 'XCUITest') {
    errors.push('Appium automationName must be XCUITest');
  }
  if (!capabilityValue(capabilities, 'udid')) {
    warnings.push('No configured iPhone UDID. Run init/connect before real-device execution.');
  }
  if (!capabilityValue(capabilities, 'updatedWDABundleId')) {
    warnings.push('No updatedWDABundleId configured. Real-device WDA signing may fail.');
  }
  if (!capabilityValue(capabilities, 'xcodeOrgId')) {
    warnings.push('No xcodeOrgId configured. Real-device WDA signing may fail.');
  }

  return { errors, warnings };
}

async function main() {
  const options = parseArgs(process.argv);
  if (options.help) {
    printHelp();
    return;
  }

  const config = await readJson(options.config);
  const errors = [];
  const warnings = [];

  const workflowResult = summarizeWorkflowConfig(config);
  errors.push(...workflowResult.errors);
  warnings.push(...workflowResult.warnings);

  let executableSequence = [];
  let linearSequenceError = null;
  try {
    executableSequence = resolveExecutableSequence(config);
    validateSequence(executableSequence);
  } catch (error) {
    linearSequenceError = error.message;
    if (!workflowResult.ok) {
      errors.push(error.message);
    }
  }

  errors.push(...validateRun(config.run));
  const capabilityResult = validateCapabilities(config.appium?.capabilities);
  errors.push(...capabilityResult.errors);
  warnings.push(...capabilityResult.warnings);

  const sequence = countSequence(executableSequence);
  const result = {
    ok: errors.length === 0,
    config: options.config,
    sequence,
    workflow: {
      ...workflowResult.summary,
      linear: !linearSequenceError,
      linearError: linearSequenceError,
    },
    warnings,
    errors,
  };

  if (options.json) {
    console.log(JSON.stringify(result, null, 2));
  } else if (result.ok) {
    if (linearSequenceError) {
      console.log(`Config valid: workflow graph with ${workflowResult.summary.nodeCount} node(s).`);
    } else {
      console.log(`Config valid: ${sequence.taps} tap(s), ${sequence.waits} fixed wait(s), ${sequence.randomWaits} random wait(s).`);
    }
    if (warnings.length > 0) {
      for (const warning of warnings) {
        console.log(`Warning: ${warning}`);
      }
    }
  } else {
    for (const error of errors) {
      console.error(`Error: ${error}`);
    }
  }

  if (!result.ok) {
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
