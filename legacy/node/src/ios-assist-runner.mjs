import { EventEmitter } from 'node:events';
import { sleep, withTimeout } from './ios-assist-session.mjs';
import {
  evaluateCondition,
  prepareWorkflowForRun,
  resolveNodeForContext,
} from './ios-assist-workflow.mjs';

function numberOrDefault(value, fallback) {
  return Number.isFinite(value) ? value : fallback;
}

function validateTapStep(step, index) {
  if (!Number.isFinite(step.x) || !Number.isFinite(step.y) || step.x < 0 || step.y < 0) {
    throw new Error(`Tap step ${index + 1} requires non-negative numeric x and y`);
  }
}

function validateWaitStep(step, index) {
  if (!Number.isFinite(step.ms) || step.ms < 0) {
    throw new Error(`Wait step ${index + 1} requires a non-negative ms value`);
  }
}

function validateWaitRandomStep(step, index) {
  if (
    !Number.isInteger(step.minMs)
    || !Number.isInteger(step.maxMs)
    || step.minMs < 0
    || step.maxMs < step.minMs
  ) {
    throw new Error(`Random wait step ${index + 1} requires integer minMs/maxMs with 0 <= minMs <= maxMs`);
  }
}

export function validateSequence(sequence) {
  if (!Array.isArray(sequence) || sequence.length === 0) {
    throw new Error('Config must include a non-empty sequence array');
  }

  for (let index = 0; index < sequence.length; index += 1) {
    const step = sequence[index];
    if (step.type === 'tap') {
      validateTapStep(step, index);
      continue;
    }
    if (step.type === 'wait') {
      validateWaitStep(step, index);
      continue;
    }
    if (step.type === 'waitRandom') {
      validateWaitRandomStep(step, index);
      continue;
    }
    throw new Error(`Unsupported step type at sequence[${index}]: ${step.type}`);
  }
}

function randomIntegerInclusive(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function resolveWaitMs(step) {
  if (step.type === 'wait') {
    return step.ms;
  }
  return randomIntegerInclusive(step.minMs, step.maxMs);
}

const DEFAULT_LOW_CONFIDENCE_THRESHOLD = 0.75;

function stepSummary(step, stepIndex) {
  if (step.type === 'tap') {
    return {
      type: 'tap',
      label: step.label ?? `#${stepIndex + 1}`,
      x: step.x,
      y: step.y,
    };
  }
  if (step.type === 'wait') {
    return {
      type: 'wait',
      ms: step.ms,
    };
  }
  if (step.type === 'waitRandom') {
    return {
      type: 'waitRandom',
      minMs: step.minMs,
      maxMs: step.maxMs,
    };
  }
  return { type: step.type };
}

function nodeSummary(node, executionIndex) {
  if (node.type === 'Tap') {
    return {
      type: 'tap',
      nodeId: node.id,
      nodeType: node.type,
      label: node.params.label ?? node.id ?? `#${executionIndex + 1}`,
      x: node.params.x,
      y: node.params.y,
    };
  }
  if (node.type === 'Wait') {
    if ('ms' in node.params) {
      return {
        type: 'wait',
        nodeId: node.id,
        nodeType: node.type,
        ms: node.params.ms,
      };
    }
    return {
      type: 'waitRandom',
      nodeId: node.id,
      nodeType: node.type,
      minMs: node.params.minMs,
      maxMs: node.params.maxMs,
    };
  }
  if (node.type === 'Snapshot') {
    return {
      type: 'snapshot',
      nodeId: node.id,
      nodeType: node.type,
      reason: node.params?.reason ?? node.id,
    };
  }
  if (node.type === 'If_Else') {
    return {
      type: 'ifElse',
      nodeId: node.id,
      nodeType: node.type,
    };
  }
  if (node.type === 'Visual_Branch') {
    return {
      type: 'visualBranch',
      nodeId: node.id,
      nodeType: node.type,
    };
  }
  return {
    type: node.type,
    nodeId: node.id,
    nodeType: node.type,
  };
}

function nodeToStep(node) {
  if (node.type === 'Tap') {
    return {
      type: 'tap',
      x: node.params.x,
      y: node.params.y,
      label: node.params.label ?? node.id,
    };
  }
  if (node.type === 'Wait') {
    if ('ms' in node.params) {
      return { type: 'wait', ms: node.params.ms };
    }
    return { type: 'waitRandom', minMs: node.params.minMs, maxMs: node.params.maxMs };
  }
  return { type: node.type };
}

function tapActions(step, tapDurationMs) {
  return [
    { type: 'pointerMove', duration: 0, x: step.x, y: step.y },
    { type: 'pointerDown', button: 0 },
    { type: 'pause', duration: tapDurationMs },
    { type: 'pointerUp', button: 0 },
  ];
}

const DEFAULT_ACTION_RELEASE_TIMEOUT_MS = 3000;
const DEFAULT_BEFORE_STEP_MAX_PAUSES = 2;

async function performPointerTap(driver, step, tapDurationMs, actionReleaseTimeoutMs = DEFAULT_ACTION_RELEASE_TIMEOUT_MS) {
  let actionError = null;
  try {
    await driver.performActions([
      {
        type: 'pointer',
        id: 'finger1',
        parameters: { pointerType: 'touch' },
        actions: tapActions(step, tapDurationMs),
      },
    ]);
  } catch (error) {
    actionError = error;
  }

  try {
    await withTimeout(
      driver.releaseActions(),
      actionReleaseTimeoutMs,
      `Pointer action release timed out after ${actionReleaseTimeoutMs}ms`
    );
  } catch (releaseError) {
    if (!actionError) {
      throw releaseError;
    }
  }

  if (actionError) {
    throw actionError;
  }
}

async function cancellableSleep(ms, shouldStop) {
  const startedAt = Date.now();
  while (Date.now() - startedAt < ms) {
    if (shouldStop()) {
      return;
    }
    await sleep(Math.min(100, ms - (Date.now() - startedAt)));
  }
}

export class AssistRunner extends EventEmitter {
  constructor({
    session,
    loadConfig,
    hooks = {},
    actionReleaseTimeoutMs = DEFAULT_ACTION_RELEASE_TIMEOUT_MS,
    beforeStepMaxPauses = DEFAULT_BEFORE_STEP_MAX_PAUSES,
  }) {
    super();
    this.session = session;
    this.loadConfig = loadConfig;
    this.hooks = hooks;
    this.actionReleaseTimeoutMs = actionReleaseTimeoutMs;
    this.beforeStepMaxPauses = Math.max(1, Math.floor(numberOrDefault(beforeStepMaxPauses, DEFAULT_BEFORE_STEP_MAX_PAUSES)));
    this.task = null;
    this.starting = false;
    this.stopRequested = false;
    this.resumePausedRun = null;
  }

  snapshot() {
    if (!this.task && !this.starting) {
      return {
        active: false,
        status: 'idle',
        loops: null,
        completedLoops: 0,
      };
    }

    if (!this.task && this.starting) {
      return {
        active: true,
        status: 'starting',
        loops: null,
        completedLoops: 0,
      };
    }

    return {
      active: true,
      status: this.task.status,
      loops: this.task.loops,
      completedLoops: this.task.completedLoops,
      startedAt: this.task.startedAt,
      currentStep: this.task.currentStep,
      pauseReason: this.task.pauseReason ?? null,
    };
  }

  emitStatus() {
    this.emit('status', this.snapshot());
  }

  emitLog(stream, message) {
    this.emit('log', { stream, message });
  }

  emitRunEvent(event) {
    this.emit('runEvent', {
      at: new Date().toISOString(),
      ...event,
    });
  }

  requestStop() {
    if (!this.task) {
      if (this.starting) {
        this.stopRequested = true;
        this.emitLog('system', 'Stop requested while the run is starting.');
        this.emitStatus();
      }
      return this.snapshot();
    }
    this.stopRequested = true;
    this.task.status = 'stopping';
    if (this.resumePausedRun) {
      this.resumePausedRun();
      this.resumePausedRun = null;
    }
    this.emitLog('system', 'Stop requested. The current step will finish before the run stops.');
    this.emitStatus();
    return this.snapshot();
  }

  resume() {
    if (!this.task || this.task.status !== 'paused') {
      return this.snapshot();
    }
    this.task.status = 'running';
    this.task.pauseReason = null;
    this.emitLog('system', 'Paused run resumed by user.');
    this.emitRunEvent({
      type: 'runResumed',
      status: 'running',
    });
    if (this.resumePausedRun) {
      this.resumePausedRun();
      this.resumePausedRun = null;
    }
    this.emitStatus();
    return this.snapshot();
  }

  waitForIdle(timeoutMs = 5000) {
    const current = this.snapshot();
    if (!current.active) {
      return Promise.resolve(current);
    }

    return new Promise((resolveWait, rejectWait) => {
      let settled = false;
      const cleanup = () => {
        this.off('status', onStatus);
        clearTimeout(timer);
      };
      const finish = (callback, value) => {
        if (settled) {
          return;
        }
        settled = true;
        cleanup();
        callback(value);
      };
      const onStatus = (snapshot) => {
        if (!snapshot.active) {
          finish(resolveWait, snapshot);
        }
      };
      const timer = setTimeout(() => {
        finish(rejectWait, new Error(`Runner did not become idle within ${timeoutMs}ms`));
      }, timeoutMs);

      this.on('status', onStatus);
      onStatus(this.snapshot());
    });
  }

  async waitWhilePaused(reason) {
    if (!this.task || this.stopRequested) {
      return;
    }
    this.task.status = 'paused';
    this.task.pauseReason = reason;
    this.emitLog('system', `Run paused: ${reason}`);
    this.emitRunEvent({
      type: 'runPaused',
      status: 'paused',
      reason,
      currentStep: this.task.currentStep,
    });
    this.emitStatus();
    await new Promise((resolvePause) => {
      this.resumePausedRun = resolvePause;
    });
  }

  async runHook(name, payload, options = {}) {
    const hook = this.hooks[name];
    if (typeof hook !== 'function') {
      return null;
    }
    try {
      return await hook(payload);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.emitLog('system', `${name} hook failed: ${message}`);
      this.emitRunEvent({
        type: 'runtimeWarning',
        status: 'warning',
        hook: name,
        message,
      });
      if (options.pauseOnError) {
        return {
          pause: true,
          reason: `${name} hook failed: ${message}`,
        };
      }
      return null;
    }
  }

  async runWorkflowNode({ node, sourceNode, summary, context }) {
    if (node.type === 'Tap') {
      const step = nodeToStep(node);
      validateTapStep(step, context.executionIndex);
      await performPointerTap(this.session.driver, step, context.tapDurationMs, this.actionReleaseTimeoutMs);
      context.last_step_result = {
        nodeId: node.id,
        type: node.type,
        status: 'ok',
        summary,
      };
      return { nextNodeId: node.next ?? null, status: 'ok' };
    }

    if (node.type === 'Wait') {
      const step = nodeToStep(node);
      if (step.type === 'wait') {
        validateWaitStep(step, context.executionIndex);
      } else {
        validateWaitRandomStep(step, context.executionIndex);
      }
      await cancellableSleep(resolveWaitMs(step), () => this.stopRequested);
      const status = this.stopRequested ? 'stopping' : 'ok';
      context.last_step_result = {
        nodeId: node.id,
        type: node.type,
        status,
        summary,
      };
      return { nextNodeId: node.next ?? null, status };
    }

    if (node.type === 'Snapshot') {
      const result = await this.runHook('snapshot', {
        node,
        sourceNode,
        summary,
        reason: node.params?.reason ?? node.id,
        context,
      });
      context.last_snapshot_result = result;
      context.last_step_result = {
        nodeId: node.id,
        type: node.type,
        status: 'ok',
        summary,
      };
      return { nextNodeId: node.next ?? null, status: 'ok' };
    }

    if (node.type === 'If_Else') {
      const passed = evaluateCondition(node.condition, context);
      context.last_condition_result = {
        nodeId: node.id,
        passed,
      };
      return {
        nextNodeId: passed ? node.trueNext : node.falseNext,
        status: 'ok',
        output: { passed },
      };
    }

    if (node.type === 'Visual_Branch') {
      const result = await this.runHook('visualBranch', {
        node,
        sourceNode,
        summary,
        context,
      });
      const analysis = result?.analysis ?? result ?? context.last_visual_result ?? null;
      context.last_visual_result = analysis;
      const decision = analysis?.decision ?? null;
      const matchedRule = node.params.rules.find(
        (rule) => rule.id === decision?.ruleId && Number(decision?.confidence) >= rule.minConfidence
      );
      if (matchedRule) {
        return {
          nextNodeId: matchedRule.next,
          status: decision?.action === 'pause' ? 'paused' : 'ok',
          output: { decision, matchedRuleId: matchedRule.id },
        };
      }
      if (!decision || !Number.isFinite(Number(decision.confidence)) || Number(decision.confidence) < DEFAULT_LOW_CONFIDENCE_THRESHOLD) {
        return {
          nextNodeId: node.lowConfidenceNext ?? node.defaultNext ?? node.next ?? null,
          status: 'paused',
          output: {
            decision: decision ?? {
              action: 'pause',
              confidence: 0,
              reason: 'Visual branch produced no reliable decision.',
            },
            matchedRuleId: null,
            lowConfidence: true,
          },
        };
      }
      return {
        nextNodeId: node.defaultNext ?? node.next ?? null,
        status: 'ok',
        output: { decision, matchedRuleId: null },
      };
    }

    if (node.type === 'Catch') {
      context.last_step_result = {
        nodeId: node.id,
        type: node.type,
        status: 'ok',
        summary,
        handledError: context.last_error ?? null,
      };
      return {
        nextNodeId: node.next ?? null,
        status: 'ok',
        output: {
          handledError: context.last_error ?? null,
        },
      };
    }

    if (node.type === 'Sub_Workflow') {
      const result = await this.runHook('subWorkflow', {
        node,
        sourceNode,
        summary,
        context,
      });
      context.last_sub_workflow_result = result;
      return { nextNodeId: node.next ?? null, status: 'ok' };
    }

    throw new Error(`Unsupported workflow node type: ${node.type}`);
  }

  async run({ loops }) {
    const parsedLoops = Number(loops);
    if (!Number.isInteger(parsedLoops) || parsedLoops < 1) {
      throw new Error('loops must be a positive integer');
    }
    if (this.task) {
      throw new Error('A run is already active.');
    }
    if (!this.session.driver) {
      throw new Error('WDA/WebDriver is not connected. Connect first.');
    }
    if (this.starting) {
      throw new Error('A run is already starting.');
    }

    this.stopRequested = false;
    this.starting = true;
    this.emitStatus();

    let config;
    let workflow;
    let nodeMap;
    let tapDurationMs;
    let betweenLoopsDelayMs;
    try {
      config = await this.loadConfig();
      workflow = prepareWorkflowForRun(config);
      nodeMap = new Map(workflow.nodes.map((node) => [node.id, node]));
      const run = config.run ?? {};
      tapDurationMs = Math.max(1, numberOrDefault(run.tapDurationMs, 80));
      betweenLoopsDelayMs = Math.max(0, numberOrDefault(run.betweenLoopsDelayMs, 0));
    } catch (error) {
      this.starting = false;
      this.emitLog('stderr', error.message);
      this.emitRunEvent({
        type: 'runError',
        status: 'error',
        message: error.message,
        currentStep: null,
      });
      this.emitRunEvent({
        type: 'runEnd',
        status: 'error',
        stopped: false,
        completedLoops: 0,
        loops: parsedLoops,
      });
      this.emitStatus();
      throw error;
    }

    this.starting = false;
    if (this.stopRequested) {
      this.emitLog('system', 'Run start was cancelled before the first step.');
      this.emitRunEvent({
        type: 'runEnd',
        status: 'stopped',
        stopped: true,
        completedLoops: 0,
        loops: parsedLoops,
      });
      this.emitStatus();
      this.stopRequested = false;
      return { stopped: true, completedLoops: 0, loops: parsedLoops };
    }

    this.task = {
      status: 'running',
      loops: parsedLoops,
      completedLoops: 0,
      startedAt: new Date().toISOString(),
      currentStep: null,
    };
    this.emitLog('system', `Run starting on persistent session: loops=${parsedLoops}`);
    this.emitRunEvent({
      type: 'runStart',
      status: 'running',
      loops: parsedLoops,
    });
    this.emitStatus();

    try {
      for (let loopIndex = 0; loopIndex < parsedLoops; loopIndex += 1) {
        if (this.stopRequested) {
          break;
        }
        let completedAllSteps = true;

        this.emitRunEvent({
          type: 'loopStart',
          status: 'running',
          loopIndex,
          loopNumber: loopIndex + 1,
          loops: parsedLoops,
        });

        let currentNodeId = workflow.entry;
        let executionIndex = 0;
        const context = {
          loopIndex,
          loopNumber: loopIndex + 1,
          loops: parsedLoops,
          completedLoops: this.task.completedLoops,
          tapDurationMs,
        };

        while (currentNodeId) {
          if (this.stopRequested) {
            completedAllSteps = false;
            break;
          }

          const node = nodeMap.get(currentNodeId);
          if (!node) {
            throw new Error(`Workflow referenced missing node at runtime: ${currentNodeId}`);
          }
          context.currentNodeId = node.id;
          context.currentNodeType = node.type;
          context.executionIndex = executionIndex;
          const executableNode = resolveNodeForContext(node, context);
          const step = nodeToStep(executableNode);
          const summary = nodeSummary(executableNode, executionIndex);
          const stepStartedAt = Date.now();
          this.task.currentStep = summary;
          this.emitRunEvent({
            type: 'stepStart',
            status: 'running',
            loopIndex,
            loopNumber: loopIndex + 1,
            loops: parsedLoops,
            stepIndex: executionIndex,
            stepNumber: executionIndex + 1,
            nodeId: node.id,
            nodeType: node.type,
            step: summary,
          });
          this.emitStatus();

          let pauseCount = 0;
          if (node.type === 'Tap') {
            while (!this.stopRequested) {
              const beforeDecision = await this.runHook('beforeStep', {
                loopIndex,
                loopNumber: loopIndex + 1,
                loops: parsedLoops,
                stepIndex: executionIndex,
                stepNumber: executionIndex + 1,
                node: executableNode,
                sourceNode: node,
                step,
                summary,
                context,
                pauseCount,
              }, { pauseOnError: true });
              if (!beforeDecision?.pause) {
                break;
              }
              pauseCount += 1;
              await this.waitWhilePaused(beforeDecision.reason ?? 'Visual guard requested manual review.');
              if (this.stopRequested) {
                break;
              }
              if (pauseCount >= this.beforeStepMaxPauses) {
                const message = `Visual guard reached ${this.beforeStepMaxPauses} pause attempt(s); continuing after manual confirmation.`;
                this.emitLog('system', message);
                this.emitRunEvent({
                  type: 'runtimeWarning',
                  status: 'warning',
                  hook: 'beforeStep',
                  message,
                  nodeId: node.id,
                  step: summary,
                  pauseCount,
                  maxPauseCount: this.beforeStepMaxPauses,
                });
                break;
              }
            }
          }
          if (this.stopRequested) {
            completedAllSteps = false;
            this.emitRunEvent({
              type: 'stepEnd',
              status: 'stopping',
              loopIndex,
              loopNumber: loopIndex + 1,
              loops: parsedLoops,
              stepIndex: executionIndex,
              stepNumber: executionIndex + 1,
              nodeId: node.id,
              nodeType: node.type,
              step: summary,
              output: {
                reason: 'Stopped before executing the step.',
              },
              durationMs: Date.now() - stepStartedAt,
            });
            break;
          }

          let nodeResult;
          try {
            nodeResult = await this.runWorkflowNode({
              node: executableNode,
              sourceNode: node,
              summary,
              context,
            });

            if (node.type === 'Tap') {
              await this.runHook('afterStep', {
                loopIndex,
                loopNumber: loopIndex + 1,
                loops: parsedLoops,
                stepIndex: executionIndex,
                stepNumber: executionIndex + 1,
                node: executableNode,
                sourceNode: node,
                step,
                summary,
                status: 'ok',
                context,
              });
            }
          } catch (error) {
            if (!node.onError) {
              throw error;
            }
            const message = error instanceof Error ? error.message : String(error);
            const handledError = {
              nodeId: node.id,
              nodeType: node.type,
              message,
            };
            context.last_error = handledError;
            context.last_step_result = {
              nodeId: node.id,
              type: node.type,
              status: 'handledError',
              summary,
              error: handledError,
            };
            this.emitRunEvent({
              type: 'stepError',
              status: 'handledError',
              loopIndex,
              loopNumber: loopIndex + 1,
              loops: parsedLoops,
              stepIndex: executionIndex,
              stepNumber: executionIndex + 1,
              nodeId: node.id,
              nodeType: node.type,
              step: summary,
              error: handledError,
              nextNodeId: node.onError,
            });
            nodeResult = {
              nextNodeId: node.onError,
              status: 'handledError',
              output: {
                error: handledError,
                onError: node.onError,
              },
            };
          }

          if (this.stopRequested) {
            completedAllSteps = false;
          }
          this.emitRunEvent({
            type: 'stepEnd',
            status: this.stopRequested ? 'stopping' : nodeResult.status,
            loopIndex,
            loopNumber: loopIndex + 1,
            loops: parsedLoops,
            stepIndex: executionIndex,
            stepNumber: executionIndex + 1,
            nodeId: node.id,
            nodeType: node.type,
            step: summary,
            output: nodeResult.output ?? null,
            durationMs: Date.now() - stepStartedAt,
          });
          if (!this.stopRequested && nodeResult.status === 'paused') {
            await this.waitWhilePaused(nodeResult.output?.decision?.reason ?? 'Workflow requested manual review.');
            if (this.stopRequested) {
              completedAllSteps = false;
              currentNodeId = null;
            }
          }
          executionIndex += 1;
          currentNodeId = this.stopRequested ? null : nodeResult.nextNodeId;
        }

        if (completedAllSteps) {
          this.task.completedLoops = loopIndex + 1;
        }
        this.emitRunEvent({
          type: 'loopEnd',
          status: this.stopRequested ? 'stopping' : 'ok',
          loopIndex,
          loopNumber: loopIndex + 1,
          loops: parsedLoops,
          completedLoops: this.task.completedLoops,
        });
        this.emitStatus();

        if (!this.stopRequested && loopIndex < parsedLoops - 1 && betweenLoopsDelayMs > 0) {
          await cancellableSleep(betweenLoopsDelayMs, () => this.stopRequested);
        }
      }

      const stopped = this.stopRequested;
      const completedLoops = this.task.completedLoops;
      this.emitLog('system', stopped
        ? `Run stopped after ${completedLoops}/${parsedLoops} loop(s).`
        : `Run finished: loops=${completedLoops}`);
      this.emitRunEvent({
        type: 'runEnd',
        status: stopped ? 'stopped' : 'ok',
        stopped,
        completedLoops,
        loops: parsedLoops,
      });
      return { stopped, completedLoops, loops: parsedLoops };
    } catch (error) {
      this.emitLog('stderr', error.message);
      this.emitRunEvent({
        type: 'runError',
        status: 'error',
        message: error.message,
        currentStep: this.task?.currentStep ?? null,
      });
      this.emitRunEvent({
        type: 'runEnd',
        status: 'error',
        stopped: false,
        completedLoops: this.task?.completedLoops ?? 0,
        loops: parsedLoops,
      });
      throw error;
    } finally {
      this.starting = false;
      this.task = null;
      this.stopRequested = false;
      this.emitStatus();
    }
  }
}
