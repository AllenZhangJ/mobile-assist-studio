#!/usr/bin/env node
import {
  normalizeWorkflow,
  resolveNodeForContext,
  resolveExecutableSequence,
  sequenceToWorkflow,
  validateWorkflow,
  workflowToExecutableSequence,
} from './ios-assist-workflow.mjs';

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function legacySequence() {
  return [
    { type: 'tap', label: 'A', x: 10, y: 20 },
    { type: 'wait', ms: 50 },
    { type: 'tap', label: 'B', x: 30, y: 40 },
  ];
}

async function main() {
  const workflow = sequenceToWorkflow(legacySequence());
  const result = validateWorkflow(workflow);
  assert(result.ok, 'Legacy sequence should map to a valid workflow');
  assert(result.summary.nodeCount === 3, 'Workflow summary should count mapped nodes');
  assert(result.summary.nodeTypes.Tap === 2, 'Workflow summary should count Tap nodes');

  const roundTrip = workflowToExecutableSequence(workflow);
  assert(roundTrip.length === 3, 'Linear workflow should convert back to a sequence');
  assert(roundTrip[0].type === 'tap' && roundTrip[0].label === 'A', 'Round-trip sequence should preserve tap labels');

  const configSequence = resolveExecutableSequence({ sequence: legacySequence() });
  assert(configSequence.length === 3, 'Config sequence should remain executable');

  const configWorkflow = resolveExecutableSequence({ workflow });
  assert(configWorkflow.length === 3, 'Config workflow should be executable when linear');

  const noisyWorkflow = {
    ...workflow,
    extraSecret: 'remove-me',
    nodes: workflow.nodes.map((node) => ({
      ...node,
      extraSecret: 'remove-me',
      params: node.params ? { ...node.params, extraSecret: 'remove-me' } : node.params,
    })),
  };
  const normalizedWorkflow = normalizeWorkflow(noisyWorkflow);
  assert(!('extraSecret' in normalizedWorkflow), 'Workflow normalization should strip root extras');
  assert(!('extraSecret' in normalizedWorkflow.nodes[0]), 'Workflow normalization should strip node extras');
  assert(!('extraSecret' in normalizedWorkflow.nodes[0].params), 'Workflow normalization should strip params extras');

  const branching = {
    version: 1,
    id: 'branching',
    entry: 'check',
    nodes: [
      {
        id: 'check',
        type: 'If_Else',
        condition: { op: 'exists', left: 'context.last_visual_result' },
        trueNext: 'tapA',
        falseNext: 'tapB',
      },
      { id: 'tapA', type: 'Tap', params: { x: 1, y: 2 } },
      { id: 'tapB', type: 'Tap', params: { x: 3, y: 4 } },
    ],
  };
  assert(validateWorkflow(branching).ok, 'Context-read If_Else workflow should validate');

  const catchWorkflow = {
    version: 1,
    id: 'catch-flow',
    entry: 'tapA',
    nodes: [
      { id: 'tapA', type: 'Tap', params: { x: 1, y: 2 }, onError: 'catchA' },
      { id: 'catchA', type: 'Catch', next: 'waitA' },
      { id: 'waitA', type: 'Wait', params: { ms: 1 } },
    ],
  };
  assert(validateWorkflow(catchWorkflow).ok, 'Catch workflow should validate onError and next references');
  const normalizedCatch = normalizeWorkflow(catchWorkflow);
  assert(normalizedCatch.nodes[0].onError === 'catchA', 'Workflow normalization should preserve onError references');
  assert(normalizedCatch.nodes[1].type === 'Catch', 'Workflow normalization should preserve Catch nodes');

  const contextParamWorkflow = {
    version: 1,
    id: 'context-params',
    entry: 'tap',
    nodes: [
      {
        id: 'tap',
        type: 'Tap',
        params: {
          label: 'context.currentNodeId',
          x: 'context.target.x',
          y: 'context.target.y',
        },
        next: 'wait',
      },
      { id: 'wait', type: 'Wait', params: { ms: 'context.waitMs' } },
    ],
  };
  assert(validateWorkflow(contextParamWorkflow).ok, 'Tap and Wait params should allow context field reads');
  const resolvedTap = resolveNodeForContext(contextParamWorkflow.nodes[0], {
    currentNodeId: 'tap',
    target: { x: 12, y: 34 },
  });
  assert(resolvedTap.params.x === 12 && resolvedTap.params.y === 34, 'Context params should resolve at runtime');
  assert(resolvedTap.params.label === 'tap', 'Context label should resolve at runtime');
  assert(
    !validateWorkflow({
      ...contextParamWorkflow,
      nodes: [
        {
          id: 'tap',
          type: 'Tap',
          params: {
            x: 'Math.random()',
            y: 'context.target.y',
          },
        },
        { id: 'wait', type: 'Wait', params: { ms: 1 } },
      ],
    }).ok,
    'Unsafe Tap param expression should not validate'
  );

  assert(
    !validateWorkflow({
      ...branching,
      nodes: [
        {
          id: 'check',
          type: 'If_Else',
          condition: { op: 'exists', left: 'process.exit()' },
          trueNext: 'tapA',
          falseNext: 'tapB',
        },
        { id: 'tapA', type: 'Tap', params: { x: 1, y: 2 } },
        { id: 'tapB', type: 'Tap', params: { x: 3, y: 4 } },
      ],
    }).ok,
    'Unsafe expression should not validate'
  );

  const cyclic = {
    version: 1,
    id: 'cyclic',
    entry: 'a',
    nodes: [
      { id: 'a', type: 'Wait', params: { ms: 1 }, next: 'b' },
      { id: 'b', type: 'Wait', params: { ms: 1 }, next: 'a' },
    ],
  };
  assert(!validateWorkflow(cyclic).ok, 'Workflow validator should reject cycles');

  console.log('Workflow smoke passed');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
