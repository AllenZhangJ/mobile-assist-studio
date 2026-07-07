const NODE_TYPES = new Set([
  'Tap',
  'Wait',
  'Snapshot',
  'Visual_Branch',
  'If_Else',
  'Catch',
  'Sub_Workflow',
]);

const CONDITION_OPS = new Set([
  'exists',
  'equals',
  'notEquals',
  'greaterThan',
  'lessThan',
  'and',
  'or',
  'not',
]);

function assertObject(value, path, errors) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    errors.push(`${path} must be an object`);
    return false;
  }
  return true;
}

function isValidNodeId(value) {
  return typeof value === 'string' && /^[a-zA-Z][a-zA-Z0-9_-]{0,63}$/.test(value);
}

function isContextRead(value) {
  return typeof value === 'string' && /^context\.[a-zA-Z_][a-zA-Z0-9_]*(\.[a-zA-Z_][a-zA-Z0-9_]*)*$/.test(value);
}

function isLiteral(value) {
  return value === null
    || typeof value === 'string'
    || typeof value === 'number'
    || typeof value === 'boolean';
}

function readContext(context, expression) {
  if (!isContextRead(expression)) {
    throw new Error(`Unsafe context expression: ${expression}`);
  }
  const path = expression.slice('context.'.length).split('.');
  let current = context;
  for (const part of path) {
    if (current == null || typeof current !== 'object' || !(part in current)) {
      return undefined;
    }
    current = current[part];
  }
  return current;
}

function resolveValue(value, context) {
  if (typeof value === 'string' && value.startsWith('context.')) {
    return readContext(context, value);
  }
  return value;
}

export function resolveContextValue(value, context = {}) {
  return resolveValue(value, context);
}

function ensureReference(value, path, refs, errors, { optional = true } = {}) {
  if (value == null && optional) {
    return;
  }
  if (!isValidNodeId(value)) {
    errors.push(`${path} must reference a node id`);
    return;
  }
  refs.push({ path, id: value });
}

function validateContextReadExpression(value, path, errors) {
  if (!isContextRead(value)) {
    errors.push(`${path} must be a context field read like context.last_ocr_result`);
  }
}

function validateValueExpression(value, path, errors) {
  if (isLiteral(value)) {
    if (typeof value === 'string' && value.startsWith('context.')) {
      validateContextReadExpression(value, path, errors);
    }
    return;
  }
  errors.push(`${path} must be a literal or context field read`);
}

function validateNumericExpression(value, path, errors) {
  if (Number.isFinite(value)) {
    return;
  }
  if (typeof value === 'string' && value.startsWith('context.')) {
    validateContextReadExpression(value, path, errors);
    return;
  }
  errors.push(`${path} must be a finite number or context field read`);
}

function validateOptionalStringExpression(value, path, errors) {
  if (value == null || typeof value === 'string') {
    if (typeof value === 'string' && value.startsWith('context.')) {
      validateContextReadExpression(value, path, errors);
    }
    return;
  }
  errors.push(`${path} must be a string or context field read when provided`);
}

function validateCondition(condition, path, errors) {
  if (!assertObject(condition, path, errors)) {
    return;
  }
  if (!CONDITION_OPS.has(condition.op)) {
    errors.push(`${path}.op must be one of ${Array.from(CONDITION_OPS).join(', ')}`);
    return;
  }

  if (condition.op === 'and' || condition.op === 'or') {
    if (!Array.isArray(condition.conditions) || condition.conditions.length === 0) {
      errors.push(`${path}.conditions must be a non-empty array`);
      return;
    }
    condition.conditions.forEach((child, index) => validateCondition(child, `${path}.conditions[${index}]`, errors));
    return;
  }

  if (condition.op === 'not') {
    validateCondition(condition.condition, `${path}.condition`, errors);
    return;
  }

  validateContextReadExpression(condition.left, `${path}.left`, errors);
  if (condition.op !== 'exists') {
    validateValueExpression(condition.right, `${path}.right`, errors);
  }
}

function validateTapNode(node, path, errors) {
  const params = node.params ?? {};
  validateNumericExpression(params.x, `${path}.params.x`, errors);
  validateNumericExpression(params.y, `${path}.params.y`, errors);
  if (Number.isFinite(params.x) && params.x < 0) {
    errors.push(`${path}.params.x must be non-negative`);
  }
  if (Number.isFinite(params.y) && params.y < 0) {
    errors.push(`${path}.params.y must be non-negative`);
  }
  validateOptionalStringExpression(params.label, `${path}.params.label`, errors);
}

function validateWaitNode(node, path, errors) {
  const params = node.params ?? {};
  if ('ms' in params) {
    validateNumericExpression(params.ms, `${path}.params.ms`, errors);
    if (Number.isFinite(params.ms) && params.ms < 0) {
      errors.push(`${path}.params.ms must be non-negative`);
    }
    return;
  }
  validateNumericExpression(params.minMs, `${path}.params.minMs`, errors);
  validateNumericExpression(params.maxMs, `${path}.params.maxMs`, errors);
  if (Number.isFinite(params.minMs) && (!Number.isInteger(params.minMs) || params.minMs < 0)) {
    errors.push(`${path}.params.minMs must be a non-negative integer`);
  }
  if (Number.isFinite(params.maxMs) && (!Number.isInteger(params.maxMs) || params.maxMs < params.minMs)) {
    errors.push(`${path}.params.maxMs must be an integer greater than or equal to minMs`);
  }
}

function validateSnapshotNode(node, path, errors) {
  const params = node.params ?? {};
  validateOptionalStringExpression(params.reason, `${path}.params.reason`, errors);
}

function validateVisualBranchNode(node, path, refs, errors) {
  const params = node.params ?? {};
  if (!Array.isArray(params.rules)) {
    errors.push(`${path}.params.rules must be an array`);
  } else {
    params.rules.forEach((rule, index) => {
      if (!assertObject(rule, `${path}.params.rules[${index}]`, errors)) {
        return;
      }
      if (typeof rule.id !== 'string') {
        errors.push(`${path}.params.rules[${index}].id must be a string`);
      }
      if (!Number.isFinite(rule.minConfidence) || rule.minConfidence < 0 || rule.minConfidence > 1) {
        errors.push(`${path}.params.rules[${index}].minConfidence must be between 0 and 1`);
      }
      ensureReference(rule.next, `${path}.params.rules[${index}].next`, refs, errors, { optional: false });
    });
  }
  ensureReference(node.defaultNext, `${path}.defaultNext`, refs, errors);
  ensureReference(node.lowConfidenceNext, `${path}.lowConfidenceNext`, refs, errors);
}

function validateIfElseNode(node, path, refs, errors) {
  validateCondition(node.condition, `${path}.condition`, errors);
  ensureReference(node.trueNext, `${path}.trueNext`, refs, errors, { optional: false });
  ensureReference(node.falseNext, `${path}.falseNext`, refs, errors, { optional: false });
}

function validateSubWorkflowNode(node, path, errors) {
  const params = node.params ?? {};
  if (typeof params.workflowId !== 'string' || params.workflowId.length === 0) {
    errors.push(`${path}.params.workflowId must be a non-empty string`);
  }
}

function validateNode(node, index, refs, errors) {
  const path = `workflow.nodes[${index}]`;
  if (!assertObject(node, path, errors)) {
    return;
  }
  if (!isValidNodeId(node.id)) {
    errors.push(`${path}.id must be a stable node id`);
  }
  if (!NODE_TYPES.has(node.type)) {
    errors.push(`${path}.type must be one of ${Array.from(NODE_TYPES).join(', ')}`);
    return;
  }
  if (node.params != null) {
    assertObject(node.params, `${path}.params`, errors);
  }

  if (node.type === 'Tap') {
    validateTapNode(node, path, errors);
  } else if (node.type === 'Wait') {
    validateWaitNode(node, path, errors);
  } else if (node.type === 'Snapshot') {
    validateSnapshotNode(node, path, errors);
  } else if (node.type === 'Visual_Branch') {
    validateVisualBranchNode(node, path, refs, errors);
  } else if (node.type === 'If_Else') {
    validateIfElseNode(node, path, refs, errors);
  } else if (node.type === 'Sub_Workflow') {
    validateSubWorkflowNode(node, path, errors);
  }

  ensureReference(node.next, `${path}.next`, refs, errors);
  ensureReference(node.onError, `${path}.onError`, refs, errors);
}

function collectReachable(entry, nodeMap) {
  const reachable = new Set();
  const visiting = new Set();
  const cycles = [];

  const visit = (id, path = []) => {
    if (!nodeMap.has(id)) {
      return;
    }
    if (visiting.has(id)) {
      cycles.push([...path, id]);
      return;
    }
    if (reachable.has(id)) {
      return;
    }
    visiting.add(id);
    reachable.add(id);
    const node = nodeMap.get(id);
    for (const target of nodeEdges(node)) {
      visit(target, [...path, id]);
    }
    visiting.delete(id);
  };

  visit(entry);
  return { reachable, cycles };
}

function nodeEdges(node) {
  const edges = [];
  for (const key of ['next', 'onError', 'trueNext', 'falseNext', 'defaultNext', 'lowConfidenceNext']) {
    if (node[key]) {
      edges.push(node[key]);
    }
  }
  for (const rule of node.params?.rules ?? []) {
    if (rule.next) {
      edges.push(rule.next);
    }
  }
  return edges;
}

function firstAvailableNext(node) {
  if (node.next) {
    return node.next;
  }
  if (node.trueNext) {
    return node.trueNext;
  }
  if (node.defaultNext) {
    return node.defaultNext;
  }
  return null;
}

function summarizeNodeTypes(nodes) {
  const types = {};
  for (const node of nodes) {
    types[node.type] = (types[node.type] ?? 0) + 1;
  }
  return types;
}

export function validateSequence(sequence) {
  const errors = [];
  if (!Array.isArray(sequence) || sequence.length === 0) {
    throw new Error('Config must include a non-empty sequence array');
  }
  sequence.forEach((step, index) => {
    const path = `sequence[${index}]`;
    if (!assertObject(step, path, errors)) {
      return;
    }
    if (step.type === 'tap') {
      validateTapNode({ params: step }, path, errors);
    } else if (step.type === 'wait') {
      validateWaitNode({ params: step }, path, errors);
    } else if (step.type === 'waitRandom') {
      validateWaitNode({ params: step }, path, errors);
    } else {
      errors.push(`Unsupported step type at ${path}: ${step.type}`);
    }
  });
  if (errors.length > 0) {
    throw new Error(errors.join('\n'));
  }
}

export function sequenceToWorkflow(sequence, { id = 'legacy-sequence' } = {}) {
  validateSequence(sequence);
  const nodes = sequence.map((step, index) => {
    const nodeId = `n${index + 1}`;
    const next = index < sequence.length - 1 ? `n${index + 2}` : null;
    if (step.type === 'tap') {
      return {
        id: nodeId,
        type: 'Tap',
        params: {
          x: step.x,
          y: step.y,
          label: step.label ?? `#${index + 1}`,
        },
        next,
      };
    }
    if (step.type === 'wait') {
      return {
        id: nodeId,
        type: 'Wait',
        params: { ms: step.ms },
        next,
      };
    }
    return {
      id: nodeId,
      type: 'Wait',
      params: {
        minMs: step.minMs,
        maxMs: step.maxMs,
      },
      next,
    };
  });
  return {
    version: 1,
    id,
    entry: nodes[0].id,
    nodes,
  };
}

export function validateWorkflow(workflow) {
  const errors = [];
  const warnings = [];
  const refs = [];
  if (!assertObject(workflow, 'workflow', errors)) {
    return { ok: false, errors, warnings, summary: null };
  }
  if (workflow.version !== 1) {
    errors.push('workflow.version must be 1');
  }
  if (typeof workflow.id !== 'string' || workflow.id.length === 0) {
    errors.push('workflow.id must be a non-empty string');
  }
  if (!isValidNodeId(workflow.entry)) {
    errors.push('workflow.entry must reference a node id');
  }
  if (!Array.isArray(workflow.nodes) || workflow.nodes.length === 0) {
    errors.push('workflow.nodes must be a non-empty array');
  }

  const nodeMap = new Map();
  for (const [index, node] of (workflow.nodes ?? []).entries()) {
    validateNode(node, index, refs, errors);
    if (isValidNodeId(node?.id)) {
      if (nodeMap.has(node.id)) {
        errors.push(`workflow.nodes[${index}].id duplicates node id ${node.id}`);
      } else {
        nodeMap.set(node.id, node);
      }
    }
  }

  if (workflow.entry && !nodeMap.has(workflow.entry)) {
    errors.push(`workflow.entry references missing node ${workflow.entry}`);
  }
  for (const ref of refs) {
    if (!nodeMap.has(ref.id)) {
      errors.push(`${ref.path} references missing node ${ref.id}`);
    }
  }

  if (errors.length === 0) {
    const { reachable, cycles } = collectReachable(workflow.entry, nodeMap);
    for (const cycle of cycles) {
      errors.push(`workflow graph contains a cycle: ${cycle.join(' -> ')}`);
    }
    for (const node of workflow.nodes) {
      if (!reachable.has(node.id)) {
        errors.push(`workflow node ${node.id} is not reachable from entry`);
      }
    }
  }

  return {
    ok: errors.length === 0,
    errors,
    warnings,
    summary: {
      id: workflow.id,
      version: workflow.version,
      entry: workflow.entry,
      nodeCount: workflow.nodes?.length ?? 0,
      nodeTypes: summarizeNodeTypes(workflow.nodes ?? []),
    },
  };
}

export function evaluateCondition(condition, context = {}) {
  if (!condition || typeof condition !== 'object') {
    throw new Error('Condition must be an object');
  }
  if (condition.op === 'and') {
    return condition.conditions.every((child) => evaluateCondition(child, context));
  }
  if (condition.op === 'or') {
    return condition.conditions.some((child) => evaluateCondition(child, context));
  }
  if (condition.op === 'not') {
    return !evaluateCondition(condition.condition, context);
  }

  const left = readContext(context, condition.left);
  if (condition.op === 'exists') {
    return left !== undefined && left !== null;
  }
  const right = resolveValue(condition.right, context);
  if (condition.op === 'equals') {
    return left === right;
  }
  if (condition.op === 'notEquals') {
    return left !== right;
  }
  if (condition.op === 'greaterThan') {
    return Number(left) > Number(right);
  }
  if (condition.op === 'lessThan') {
    return Number(left) < Number(right);
  }
  throw new Error(`Unsupported condition op: ${condition.op}`);
}

function normalizeCondition(condition) {
  if (condition.op === 'and' || condition.op === 'or') {
    return {
      op: condition.op,
      conditions: condition.conditions.map(normalizeCondition),
    };
  }
  if (condition.op === 'not') {
    return {
      op: condition.op,
      condition: normalizeCondition(condition.condition),
    };
  }
  if (condition.op === 'exists') {
    return {
      op: condition.op,
      left: condition.left,
    };
  }
  return {
    op: condition.op,
    left: condition.left,
    right: condition.right,
  };
}

function assignReference(target, source, key) {
  if (source[key]) {
    target[key] = source[key];
  }
}

function normalizeNode(node) {
  const normalized = {
    id: node.id,
    type: node.type,
  };

  if (node.type === 'Tap') {
    normalized.params = {
      x: node.params.x,
      y: node.params.y,
    };
    if (node.params.label != null) {
      normalized.params.label = node.params.label;
    }
  } else if (node.type === 'Wait') {
    if ('ms' in node.params) {
      normalized.params = { ms: node.params.ms };
    } else {
      normalized.params = {
        minMs: node.params.minMs,
        maxMs: node.params.maxMs,
      };
    }
  } else if (node.type === 'Snapshot') {
    normalized.params = {};
    if (node.params?.reason != null) {
      normalized.params.reason = node.params.reason;
    }
  } else if (node.type === 'Visual_Branch') {
    normalized.params = {
      rules: node.params.rules.map((rule) => ({
        id: rule.id,
        minConfidence: rule.minConfidence,
        next: rule.next,
      })),
    };
  } else if (node.type === 'If_Else') {
    normalized.condition = normalizeCondition(node.condition);
    normalized.trueNext = node.trueNext;
    normalized.falseNext = node.falseNext;
  } else if (node.type === 'Sub_Workflow') {
    normalized.params = {
      workflowId: node.params.workflowId,
    };
  }

  for (const key of ['next', 'onError', 'defaultNext', 'lowConfidenceNext']) {
    assignReference(normalized, node, key);
  }
  return normalized;
}

export function resolveNodeForContext(node, context = {}) {
  if (node.type !== 'Tap' && node.type !== 'Wait' && node.type !== 'Snapshot' && node.type !== 'Sub_Workflow') {
    return node;
  }

  const resolved = {
    ...node,
    params: { ...(node.params ?? {}) },
  };
  for (const [key, value] of Object.entries(resolved.params)) {
    resolved.params[key] = resolveValue(value, context);
  }
  return resolved;
}

export function normalizeWorkflow(workflow) {
  const result = validateWorkflow(workflow);
  if (!result.ok) {
    throw new Error(result.errors.join('\n'));
  }
  return {
    version: 1,
    id: workflow.id,
    entry: workflow.entry,
    nodes: workflow.nodes.map(normalizeNode),
  };
}

export function workflowFromConfig(config) {
  if (config?.workflow) {
    return config.workflow;
  }
  return sequenceToWorkflow(config?.sequence ?? [], { id: 'legacy-sequence' });
}

export function prepareWorkflowForRun(config) {
  const workflow = workflowFromConfig(config);
  const result = validateWorkflow(workflow);
  if (!result.ok) {
    throw new Error(result.errors.join('\n'));
  }
  return workflow;
}

export function workflowToExecutableSequence(workflow) {
  const result = validateWorkflow(workflow);
  if (!result.ok) {
    throw new Error(result.errors.join('\n'));
  }

  const nodeMap = new Map(workflow.nodes.map((node) => [node.id, node]));
  const sequence = [];
  let current = workflow.entry;
  const seen = new Set();
  while (current) {
    if (seen.has(current)) {
      throw new Error(`Workflow linearization encountered a cycle at ${current}`);
    }
    seen.add(current);
    const node = nodeMap.get(current);
    if (node.type === 'Tap') {
      sequence.push({
        type: 'tap',
        x: node.params.x,
        y: node.params.y,
        label: node.params.label,
      });
    } else if (node.type === 'Wait') {
      if ('ms' in node.params) {
        sequence.push({ type: 'wait', ms: node.params.ms });
      } else {
        sequence.push({ type: 'waitRandom', minMs: node.params.minMs, maxMs: node.params.maxMs });
      }
    } else {
      throw new Error(`Workflow node ${node.id} (${node.type}) cannot be executed by the legacy linear runner yet`);
    }
    current = node.next ?? null;
  }
  validateSequence(sequence);
  return sequence;
}

export function resolveExecutableSequence(config) {
  if (config?.workflow) {
    return workflowToExecutableSequence(config.workflow);
  }
  if (Array.isArray(config?.sequence)) {
    validateSequence(config.sequence);
    return config.sequence;
  }
  throw new Error('Config must include sequence or workflow');
}

export function summarizeWorkflowConfig(config) {
  const workflow = workflowFromConfig(config);
  const result = validateWorkflow(workflow);
  return {
    ...result,
    firstExecutableNode: result.ok ? firstAvailableNext({ next: workflow.entry }) : null,
  };
}
