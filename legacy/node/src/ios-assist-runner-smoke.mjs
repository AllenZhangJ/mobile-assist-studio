#!/usr/bin/env node
import { AssistRunner } from './ios-assist-runner.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function fakeDriver() {
  const calls = [];
  return {
    calls,
    async performActions(actions) {
      calls.push({ type: 'performActions', actions });
    },
    async releaseActions() {
      calls.push({ type: 'releaseActions' });
    },
  };
}

function throwingDriver() {
  const calls = [];
  return {
    calls,
    async performActions(actions) {
      calls.push({ type: 'performActions', actions });
      throw new Error('tap failed');
    },
    async releaseActions() {
      calls.push({ type: 'releaseActions' });
    },
  };
}

function throwingOnceDriver() {
  const calls = [];
  let failed = false;
  return {
    calls,
    async performActions(actions) {
      calls.push({ type: 'performActions', actions });
      if (!failed) {
        failed = true;
        throw new Error('tap failed once');
      }
    },
    async releaseActions() {
      calls.push({ type: 'releaseActions' });
    },
  };
}

function hangingReleaseDriver() {
  const calls = [];
  return {
    calls,
    async performActions(actions) {
      calls.push({ type: 'performActions', actions });
    },
    async releaseActions() {
      calls.push({ type: 'releaseActions' });
      return new Promise(() => {});
    },
  };
}

async function runCompleteScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
        { type: 'wait', ms: 1 },
        { type: 'tap', label: 'B', x: 3, y: 4 },
      ],
    }),
  });

  runner.on('runEvent', (event) => events.push(event));
  const result = await runner.run({ loops: 1 });

  assert(result.stopped === false, 'Complete run should not be stopped');
  assert(result.completedLoops === 1, 'Complete run should finish one loop');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 2, 'Complete run should tap twice');
  assert(events.some((event) => event.type === 'runStart'), 'Complete run should emit runStart');
  assert(events.filter((event) => event.type === 'stepEnd').length === 3, 'Complete run should emit three stepEnd events');
  assert(events.at(-1)?.type === 'runEnd', 'Complete run should end with runEnd');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after completion');
}

async function runStopScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
        { type: 'wait', ms: 200 },
        { type: 'tap', label: 'B', x: 3, y: 4 },
      ],
    }),
  });

  runner.on('runEvent', (event) => events.push(event));
  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  const stopSnapshot = runner.requestStop();
  const result = await runPromise;

  assert(stopSnapshot.status === 'stopping', 'Stop request should move runner to stopping');
  assert(result.stopped === true, 'Stopped run should report stopped=true');
  assert(result.completedLoops === 0, 'Stopped run should not count an interrupted loop as completed');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'Stopped run should not tap after stop');
  assert(events.some((event) => event.type === 'stepEnd' && event.status === 'stopping'), 'Stopped wait should emit stopping stepEnd');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after stop');
}

async function runWaitForIdleAfterStopScenario() {
  const driver = fakeDriver();
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
        { type: 'wait', ms: 120 },
        { type: 'tap', label: 'B', x: 3, y: 4 },
      ],
    }),
  });

  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  runner.requestStop();
  const idleSnapshot = await runner.waitForIdle(500);
  const result = await runPromise;

  assert(idleSnapshot.status === 'idle', 'waitForIdle should resolve after a stopped run returns to idle');
  assert(result.stopped === true, 'waitForIdle stop scenario should still stop the run');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'waitForIdle stop scenario should not tap after stop');
}

async function runPauseResumeScenario() {
  const driver = fakeDriver();
  const events = [];
  let pausedOnce = false;
  let hookCalls = 0;
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
      ],
    }),
    hooks: {
      beforeStep: async () => {
        hookCalls += 1;
        if (pausedOnce) {
          return null;
        }
        pausedOnce = true;
        return { pause: true, reason: 'manual review' };
      },
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert(runner.snapshot().status === 'paused', 'Visual guard should pause the run');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 0, 'Paused run should not tap before resume');
  runner.resume();
  const result = await runPromise;

  assert(result.stopped === false, 'Resumed run should complete');
  assert(hookCalls === 2, 'Resumed run should re-check the visual guard before tapping');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'Resumed run should tap once');
  assert(events.some((event) => event.type === 'runPaused'), 'Paused run should emit runPaused');
  assert(events.some((event) => event.type === 'runResumed'), 'Resumed run should emit runResumed');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after resume completion');
}

async function runWaitForIdleTimeoutScenario() {
  const driver = fakeDriver();
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
      ],
    }),
    hooks: {
      beforeStep: async () => ({ pause: true, reason: 'manual review' }),
    },
  });

  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  let timedOut = false;
  try {
    await runner.waitForIdle(20);
  } catch (error) {
    timedOut = /Runner did not become idle/i.test(error.message);
  }
  runner.requestStop();
  await runPromise;

  assert(timedOut, 'waitForIdle should time out while a paused run remains active');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after stopping timed-out wait scenario');
}

async function runPausedStopScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
      ],
    }),
    hooks: {
      beforeStep: async () => ({ pause: true, reason: 'manual review' }),
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert(runner.snapshot().status === 'paused', 'Run should pause before tap');
  runner.requestStop();
  const result = await runPromise;

  assert(result.stopped === true, 'Stopped paused run should report stopped');
  assert(result.completedLoops === 0, 'Stopped paused run should not count the loop');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 0, 'Stopped paused run should not tap');
  assert(events.some((event) => event.type === 'stepStart'), 'Stopped paused run should emit stepStart');
  assert(events.some((event) => event.type === 'stepEnd' && event.status === 'stopping'), 'Stopped paused run should close the current step');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after stopping while paused');
}

async function runBeforeStepMaxPauseScenario() {
  const driver = fakeDriver();
  const events = [];
  let hookCalls = 0;
  const runner = new AssistRunner({
    session: { driver },
    beforeStepMaxPauses: 2,
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
      ],
    }),
    hooks: {
      beforeStep: async () => {
        hookCalls += 1;
        return { pause: true, reason: 'manual review' };
      },
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert(runner.snapshot().status === 'paused', 'Max-pause visual guard should pause before the first tap');
  runner.resume();
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert(runner.snapshot().status === 'paused', 'Max-pause visual guard should pause a second time before manual confirmation');
  runner.resume();
  const result = await runPromise;

  assert(result.stopped === false, 'Max-pause visual guard should complete after explicit confirmation');
  assert(hookCalls === 2, 'Max-pause visual guard should not re-check forever after the threshold');
  assert(events.filter((event) => event.type === 'runPaused').length === 2, 'Max-pause visual guard should pause exactly twice');
  assert(events.some((event) => event.type === 'runtimeWarning' && event.maxPauseCount === 2), 'Max-pause visual guard should emit a threshold warning');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'Max-pause visual guard should tap once after confirmation');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after max-pause completion');
}

async function runBeforeStepHookFailurePausesScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
      ],
    }),
    hooks: {
      beforeStep: async () => {
        throw new Error('visual guard unavailable');
      },
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert(runner.snapshot().status === 'paused', 'Failed visual guard hook should pause the run');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 0, 'Failed visual guard hook should not allow tap');
  assert(events.some((event) => event.type === 'runtimeWarning' && event.hook === 'beforeStep'), 'Failed visual guard hook should emit runtimeWarning');
  runner.requestStop();
  const result = await runPromise;

  assert(result.stopped === true, 'Stopped hook-failure pause should report stopped');
  assert(result.completedLoops === 0, 'Stopped hook-failure pause should not count the loop');
  assert(events.some((event) => event.type === 'stepEnd' && event.status === 'stopping'), 'Stopped hook-failure pause should close the current step');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after stopping hook-failure pause');
}

async function runTapFailureReleasesActionsScenario() {
  const driver = throwingDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
      ],
    }),
  });

  runner.on('runEvent', (event) => events.push(event));
  let failed = false;
  try {
    await runner.run({ loops: 1 });
  } catch (error) {
    failed = error.message === 'tap failed';
  }

  assert(failed, 'Tap failure should reject the run with the original error');
  assert(driver.calls.some((call) => call.type === 'releaseActions'), 'Tap failure should still release pointer actions');
  assert(events.some((event) => event.type === 'runError'), 'Tap failure should emit runError');
  assert(events.some((event) => event.type === 'runEnd' && event.status === 'error'), 'Tap failure should emit error runEnd');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after tap failure');
}

async function runHangingReleaseActionsScenario() {
  const driver = hangingReleaseDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    actionReleaseTimeoutMs: 30,
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      sequence: [
        { type: 'tap', label: 'A', x: 1, y: 2 },
      ],
    }),
  });

  runner.on('runEvent', (event) => events.push(event));
  let failed = false;
  try {
    await runner.run({ loops: 1 });
  } catch (error) {
    failed = /Pointer action release timed out/i.test(error.message);
  }

  assert(failed, 'Hanging releaseActions should fail the run with a timeout');
  assert(driver.calls.some((call) => call.type === 'releaseActions'), 'Hanging releaseActions scenario should attempt release');
  assert(events.some((event) => event.type === 'runEnd' && event.status === 'error'), 'Hanging releaseActions should emit error runEnd');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after releaseActions timeout');
}

async function runCatchWorkflowScenario() {
  const driver = throwingOnceDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      workflow: {
        version: 1,
        id: 'catch-runtime',
        entry: 'tapA',
        nodes: [
          { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2 }, onError: 'catchA' },
          { id: 'catchA', type: 'Catch', next: 'tapRecovery' },
          { id: 'tapRecovery', type: 'Tap', params: { label: 'Recovery', x: 3, y: 4 } },
        ],
      },
    }),
  });

  runner.on('runEvent', (event) => events.push(event));
  const result = await runner.run({ loops: 1 });

  assert(result.completedLoops === 1, 'Catch workflow should complete the loop after handling the tap error');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 2, 'Catch workflow should attempt the failing tap and recovery tap');
  assert(events.some((event) => event.type === 'stepError' && event.status === 'handledError' && event.nextNodeId === 'catchA'), 'Catch workflow should emit a handled stepError');
  assert(events.some((event) => event.type === 'stepEnd' && event.nodeId === 'tapA' && event.status === 'handledError'), 'Catch workflow should close the failed step as handledError');
  assert(events.some((event) => event.type === 'stepEnd' && event.nodeId === 'catchA' && event.output?.handledError?.message === 'tap failed once'), 'Catch node should expose the handled error');
  assert(!events.some((event) => event.type === 'runError'), 'Catch workflow should not emit runError for a handled error');
  assert(events.some((event) => event.type === 'runEnd' && event.status === 'ok'), 'Catch workflow should end successfully');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after Catch workflow completion');
}

async function runConfigLoadFailureScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => {
      throw new Error('config invalid');
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  let failed = false;
  try {
    await runner.run({ loops: 1 });
  } catch (error) {
    failed = error.message === 'config invalid';
  }

  assert(failed, 'Config load failure should reject the run with the original error');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 0, 'Config load failure should not perform any tap');
  assert(events.some((event) => event.type === 'runError' && event.currentStep === null), 'Config load failure should emit runError without a current step');
  assert(events.some((event) => event.type === 'runEnd' && event.status === 'error' && event.completedLoops === 0), 'Config load failure should emit error runEnd');
  assert(runner.snapshot().status === 'idle', 'Runner should return to idle after config load failure');
}

async function runIfElseWorkflowScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      workflow: {
        version: 1,
        id: 'if-else-runtime',
        entry: 'branch',
        nodes: [
          {
            id: 'branch',
            type: 'If_Else',
            condition: { op: 'equals', left: 'context.loopNumber', right: 1 },
            trueNext: 'tapA',
            falseNext: 'tapB',
          },
          { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2 } },
          { id: 'tapB', type: 'Tap', params: { label: 'B', x: 3, y: 4 } },
        ],
      },
    }),
  });

  runner.on('runEvent', (event) => events.push(event));
  const result = await runner.run({ loops: 2 });

  assert(result.completedLoops === 2, 'If_Else workflow should complete two loops');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 2, 'If_Else workflow should tap once per loop');
  const tapStarts = events.filter((event) => event.type === 'stepStart' && event.nodeType === 'Tap');
  assert(tapStarts[0].step.label === 'A', 'If_Else should take true branch on loop 1');
  assert(tapStarts[1].step.label === 'B', 'If_Else should take false branch on loop 2');
}

async function runContextParamWorkflowScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      workflow: {
        version: 1,
        id: 'context-param-runtime',
        entry: 'tapA',
        nodes: [
          {
            id: 'tapA',
            type: 'Tap',
            params: {
              label: 'context.currentNodeId',
              x: 'context.loopNumber',
              y: 'context.loops',
            },
            next: 'waitA',
          },
          { id: 'waitA', type: 'Wait', params: { ms: 'context.loopIndex' } },
        ],
      },
    }),
  });

  runner.on('runEvent', (event) => events.push(event));
  const result = await runner.run({ loops: 2 });
  const tapCalls = driver.calls.filter((call) => call.type === 'performActions');
  const tapStarts = events.filter((event) => event.type === 'stepStart' && event.nodeType === 'Tap');

  assert(result.completedLoops === 2, 'Context-param workflow should complete two loops');
  assert(tapCalls.length === 2, 'Context-param workflow should tap once per loop');
  assert(tapStarts[0].step.label === 'tapA', 'Context label should resolve for event summaries');
  assert(tapStarts[1].step.x === 2 && tapStarts[1].step.y === 2, 'Context coordinates should resolve for event summaries');
  assert(tapCalls[1].actions[0].actions[0].x === 2, 'Resolved context x should be sent to WebDriver');
  assert(tapCalls[1].actions[0].actions[0].y === 2, 'Resolved context y should be sent to WebDriver');
}

async function runSnapshotWorkflowScenario() {
  const driver = fakeDriver();
  let snapshotCalls = 0;
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      workflow: {
        version: 1,
        id: 'snapshot-runtime',
        entry: 'shot',
        nodes: [
          { id: 'shot', type: 'Snapshot', params: { reason: 'before' }, next: 'tapA' },
          { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2 } },
        ],
      },
    }),
    hooks: {
      snapshot: async () => {
        snapshotCalls += 1;
        return { ok: true };
      },
    },
  });

  const result = await runner.run({ loops: 1 });
  assert(result.completedLoops === 1, 'Snapshot workflow should complete');
  assert(snapshotCalls === 1, 'Snapshot node should call snapshot hook');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'Snapshot workflow should continue to tap');
}

async function runVisualBranchWorkflowScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      workflow: {
        version: 1,
        id: 'visual-branch-runtime',
        entry: 'visual',
        nodes: [
          {
            id: 'visual',
            type: 'Visual_Branch',
            params: {
              rules: [
                { id: 'target.visible', minConfidence: 0.9, next: 'tapA' },
              ],
            },
            defaultNext: 'tapB',
          },
          { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2 } },
          { id: 'tapB', type: 'Tap', params: { label: 'B', x: 3, y: 4 } },
        ],
      },
    }),
    hooks: {
      visualBranch: async () => ({
        analysis: {
          decision: {
            ruleId: 'target.visible',
            confidence: 0.95,
            action: 'continue',
            reason: 'target visible',
          },
        },
      }),
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  const result = await runner.run({ loops: 1 });
  const tapStart = events.find((event) => event.type === 'stepStart' && event.nodeType === 'Tap');

  assert(result.completedLoops === 1, 'Visual_Branch workflow should complete');
  assert(tapStart?.step.label === 'A', 'Visual_Branch should follow matched rule');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'Visual_Branch workflow should tap once');
}

async function runVisualBranchLowConfidencePauseScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      workflow: {
        version: 1,
        id: 'visual-low-confidence-runtime',
        entry: 'visual',
        nodes: [
          {
            id: 'visual',
            type: 'Visual_Branch',
            params: {
              rules: [
                { id: 'target.visible', minConfidence: 0.9, next: 'tapA' },
              ],
            },
            defaultNext: 'tapB',
          },
          { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2 } },
          { id: 'tapB', type: 'Tap', params: { label: 'B', x: 3, y: 4 } },
        ],
      },
    }),
    hooks: {
      visualBranch: async () => ({
        analysis: {
          decision: {
            ruleId: 'target.visible',
            confidence: 0.4,
            action: 'continue',
            reason: 'target uncertain',
          },
        },
      }),
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert(runner.snapshot().status === 'paused', 'Low-confidence Visual_Branch should pause before default branch');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 0, 'Low-confidence Visual_Branch should not tap before resume');
  runner.resume();
  const result = await runPromise;
  const tapStart = events.find((event) => event.type === 'stepStart' && event.nodeType === 'Tap');

  assert(result.completedLoops === 1, 'Resumed low-confidence Visual_Branch workflow should complete');
  assert(tapStart?.step.label === 'B', 'Low-confidence Visual_Branch should continue to default branch only after resume');
  assert(events.some((event) => event.type === 'runPaused'), 'Low-confidence Visual_Branch should emit runPaused');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'Resumed low-confidence Visual_Branch should tap once');
}

async function runVisualBranchNoDecisionPauseScenario() {
  const driver = fakeDriver();
  const events = [];
  const runner = new AssistRunner({
    session: { driver },
    loadConfig: async () => ({
      run: { tapDurationMs: 1 },
      workflow: {
        version: 1,
        id: 'visual-no-decision-runtime',
        entry: 'visual',
        nodes: [
          {
            id: 'visual',
            type: 'Visual_Branch',
            params: {
              rules: [
                { id: 'target.visible', minConfidence: 0.9, next: 'tapA' },
              ],
            },
            defaultNext: 'tapB',
          },
          { id: 'tapA', type: 'Tap', params: { label: 'A', x: 1, y: 2 } },
          { id: 'tapB', type: 'Tap', params: { label: 'B', x: 3, y: 4 } },
        ],
      },
    }),
    hooks: {
      visualBranch: async () => null,
    },
  });

  runner.on('runEvent', (event) => events.push(event));
  const runPromise = runner.run({ loops: 1 });
  await new Promise((resolve) => setTimeout(resolve, 20));
  assert(runner.snapshot().status === 'paused', 'Visual_Branch without a decision should pause before default branch');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 0, 'Visual_Branch without a decision should not tap before resume');
  runner.resume();
  const result = await runPromise;
  const tapStart = events.find((event) => event.type === 'stepStart' && event.nodeType === 'Tap');

  assert(result.completedLoops === 1, 'Resumed no-decision Visual_Branch workflow should complete');
  assert(tapStart?.step.label === 'B', 'No-decision Visual_Branch should continue to default branch only after resume');
  assert(events.some((event) => event.type === 'runPaused'), 'No-decision Visual_Branch should emit runPaused');
  assert(driver.calls.filter((call) => call.type === 'performActions').length === 1, 'Resumed no-decision Visual_Branch should tap once');
}

async function main() {
  await runCompleteScenario();
  await runStopScenario();
  await runWaitForIdleAfterStopScenario();
  await runPauseResumeScenario();
  await runWaitForIdleTimeoutScenario();
  await runPausedStopScenario();
  await runBeforeStepMaxPauseScenario();
  await runBeforeStepHookFailurePausesScenario();
  await runTapFailureReleasesActionsScenario();
  await runHangingReleaseActionsScenario();
  await runCatchWorkflowScenario();
  await runConfigLoadFailureScenario();
  await runIfElseWorkflowScenario();
  await runContextParamWorkflowScenario();
  await runSnapshotWorkflowScenario();
  await runVisualBranchWorkflowScenario();
  await runVisualBranchLowConfidencePauseScenario();
  await runVisualBranchNoDecisionPauseScenario();
  console.log('Runner smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
