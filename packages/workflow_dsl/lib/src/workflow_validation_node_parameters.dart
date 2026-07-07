part of '../workflow_dsl.dart';

// 节点参数校验分片，只承载按节点类型展开的参数和分支约束。
// 主 Validator 仍负责整体结构、引用和可达性校验。

// 按节点类型校验参数和分支数量。
void _validateNodeParameters(WorkflowNode node, List<String> errors) {
  for (final parameter in node.parameters.values) {
    if (parameter is String && parameter.contains('eval(')) {
      errors.add('Unsafe expression in node ${node.id}.');
    }
  }
  switch (node.type) {
    case WorkflowNodeType.condition:
      _validateConditionNode(node, errors);
    case WorkflowNodeType.visualBranch:
      _validateVisualBranchNode(node, errors);
    case WorkflowNodeType.waitForTarget:
      _validateWaitForTargetNode(node, errors);
    case WorkflowNodeType.tap:
      _validateTapNode(node, errors);
    case WorkflowNodeType.wait:
      _validateWaitNode(node, errors);
    case WorkflowNodeType.swipe:
      _validateSwipeNode(node, errors);
    case WorkflowNodeType.input:
      _validateInputNode(node, errors);
    case WorkflowNodeType.snapshot:
      _validateSnapshotNode(node, errors);
    case WorkflowNodeType.loop:
      _validateLoopNode(node, errors);
    case WorkflowNodeType.catchNodes:
      _validateCatchNode(node, errors);
    case WorkflowNodeType.subWorkflow:
      _validateSubWorkflowNode(node, errors);
    case WorkflowNodeType.start || WorkflowNodeType.end:
      break;
  }
}

// 校验 Condition 表达式和分支数量。
void _validateConditionNode(WorkflowNode node, List<String> errors) {
  final expression = node.parameters['expression'];
  if (expression is! String || !isSafeContextExpression(expression)) {
    errors.add('Unsafe condition expression in node ${node.id}.');
  }
  if (node.next.length > 2) {
    errors.add('Condition node ${node.id} can have at most two branches.');
  }
}

// 校验 Visual Branch 的置信度阈值和成功分支数量。
void _validateVisualBranchNode(WorkflowNode node, List<String> errors) {
  _optionalTargetRef(node, errors);
  _validateConfidenceThreshold(node, errors, label: 'Visual Branch');
  if (node.next.length > 1) {
    errors.add(
      'Visual Branch node ${node.id} can have only one success branch.',
    );
  }
}

// 校验 Wait For Target 的目标引用、轮询参数和主分支数量。
void _validateWaitForTargetNode(WorkflowNode node, List<String> errors) {
  _requiredTargetRef(node, errors);
  _validateConfidenceThreshold(node, errors, label: 'Wait For Target');
  final timeoutMs = node.parameters['timeoutMs'];
  if (timeoutMs is! int || timeoutMs <= 0 || timeoutMs > 600000) {
    errors.add(
      'Wait For Target node ${node.id} timeoutMs must be an integer from 1 to 600000.',
    );
  }
  final intervalMs = node.parameters['intervalMs'];
  if (intervalMs != null &&
      (intervalMs is! int || intervalMs <= 0 || intervalMs > 60000)) {
    errors.add(
      'Wait For Target node ${node.id} intervalMs must be an integer from 1 to 60000.',
    );
  }
  if (timeoutMs is int && intervalMs is int && intervalMs > timeoutMs) {
    errors.add(
      'Wait For Target node ${node.id} intervalMs must not exceed timeoutMs.',
    );
  }
  if (node.next.length > 1) {
    errors.add(
      'Wait For Target node ${node.id} can have only one main branch.',
    );
  }
}

// 校验视觉类节点的置信阈值。
void _validateConfidenceThreshold(
  WorkflowNode node,
  List<String> errors, {
  required String label,
}) {
  final confidenceThreshold = node.parameters['confidenceThreshold'];
  if (confidenceThreshold != null &&
      (confidenceThreshold is! num ||
          !confidenceThreshold.isFinite ||
          confidenceThreshold < 0 ||
          confidenceThreshold > 1)) {
    errors.add(
      '$label node ${node.id} confidenceThreshold must be between 0 and 1.',
    );
  }
}

// 校验 Tap 坐标、可选时长和主分支数量。
void _validateTapNode(WorkflowNode node, List<String> errors) {
  final targetRef = _optionalTargetRef(node, errors);
  _validateConfidenceThreshold(node, errors, label: 'Tap');
  if (targetRef == null) {
    for (final key in ['x', 'y']) {
      final value = node.parameters[key];
      if (value is! int) {
        errors.add('Tap node ${node.id} $key must be an integer.');
      }
    }
  } else {
    for (final key in ['x', 'y']) {
      final value = node.parameters[key];
      if (value != null && value is! int) {
        errors.add('Tap node ${node.id} $key must be an integer.');
      }
    }
  }
  final durationMs = node.parameters['durationMs'];
  if (durationMs != null && (durationMs is! int || durationMs < 0)) {
    errors.add('Tap node ${node.id} durationMs must be non-negative.');
  }
  if (node.next.length > 1) {
    errors.add('Tap node ${node.id} can have only one main branch.');
  }
}

// 校验节点 targetRef 的基本形态。
// 目标是否存在属于 Runtime 项目级校验，不放在纯 DSL 包里。
String? _optionalTargetRef(WorkflowNode node, List<String> errors) {
  final value = node.parameters['targetRef'];
  if (value == null) return null;
  return _validateTargetRef(node, value, errors);
}

// 校验必填 targetRef。
String? _requiredTargetRef(WorkflowNode node, List<String> errors) {
  final value = node.parameters['targetRef'];
  if (value == null) {
    errors.add('Node ${node.id} targetRef is required.');
    return null;
  }
  return _validateTargetRef(node, value, errors);
}

// 校验 targetRef 字段形态并返回归一化 ID。
String? _validateTargetRef(
  WorkflowNode node,
  Object? value,
  List<String> errors,
) {
  if (value is! String || value.trim().isEmpty) {
    errors.add('Node ${node.id} targetRef must be a non-empty string.');
    return null;
  }
  final normalized = value.trim();
  if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(normalized)) {
    errors.add('Node ${node.id} targetRef is invalid.');
  }
  return normalized;
}

// 校验 Wait 等待时间和主分支数量。
void _validateWaitNode(WorkflowNode node, List<String> errors) {
  final ms = node.parameters['ms'];
  if (ms is! int || ms < 0) {
    errors.add('Wait node ${node.id} ms must be non-negative.');
  }
  if (node.next.length > 1) {
    errors.add('Wait node ${node.id} can have only one main branch.');
  }
}

// 校验 Swipe 坐标、时长和主分支数量。
void _validateSwipeNode(WorkflowNode node, List<String> errors) {
  for (final key in ['fromX', 'fromY', 'toX', 'toY']) {
    final value = node.parameters[key];
    if (value is! int) {
      errors.add('Swipe node ${node.id} $key must be an integer.');
    }
  }
  final durationMs = node.parameters['durationMs'];
  if (durationMs != null && (durationMs is! int || durationMs < 0)) {
    errors.add('Swipe node ${node.id} durationMs must be non-negative.');
  }
  if (node.next.length > 1) {
    errors.add('Swipe node ${node.id} can have only one main branch.');
  }
}

// 校验 Input 文本和主分支数量。
void _validateInputNode(WorkflowNode node, List<String> errors) {
  final text = node.parameters['text'];
  if (text is! String) {
    errors.add('Input node ${node.id} text is required.');
  }
  if (node.next.length > 1) {
    errors.add('Input node ${node.id} can have only one main branch.');
  }
}

// 校验 Snapshot 证据开关和主分支数量。
void _validateSnapshotNode(WorkflowNode node, List<String> errors) {
  final saveEvidence = node.parameters['saveEvidence'];
  if (saveEvidence != null && saveEvidence is! bool) {
    errors.add('Snapshot node ${node.id} saveEvidence must be a boolean.');
  }
  if (node.next.length > 1) {
    errors.add('Snapshot node ${node.id} can have only one main branch.');
  }
}

// 校验 Loop 有限次数和 body/after 分支。
void _validateLoopNode(WorkflowNode node, List<String> errors) {
  final count = node.parameters['count'];
  if (count is! int || count < 0 || count > 1000) {
    errors.add('Loop node ${node.id} count must be an integer from 0 to 1000.');
  }
  if (node.next.length > 2) {
    errors.add('Loop node ${node.id} can have at most two branches.');
  }
  if (count is int && count > 0 && node.next.length != 2) {
    errors.add(
      'Loop node ${node.id} requires body and after branches when count is positive.',
    );
  }
}

// 校验 Catch 重试次数和主分支数量。
void _validateCatchNode(WorkflowNode node, List<String> errors) {
  final maxRetries = node.parameters['maxRetries'];
  if (maxRetries != null && (maxRetries is! int || maxRetries < 0)) {
    errors.add('Catch node ${node.id} maxRetries must be non-negative.');
  }
  if (node.next.length > 1) {
    errors.add('Catch node ${node.id} can have only one main branch.');
  }
}

// 校验 Sub Workflow 引用字段和主分支数量。
void _validateSubWorkflowNode(WorkflowNode node, List<String> errors) {
  final workflowId = node.parameters['workflowId'];
  if (workflowId is! String || workflowId.trim().isEmpty) {
    errors.add('Sub Workflow node ${node.id} workflowId is required.');
  }
  _validateSubWorkflowInputMap(node, errors);
  if (node.next.length > 1) {
    errors.add('Sub Workflow node ${node.id} can have only one main branch.');
  }
}

// 校验 Sub Workflow 参数映射，只允许声明式读取 context.xxx。
// 这里不开放脚本、函数调用或任意表达式。
void _validateSubWorkflowInputMap(WorkflowNode node, List<String> errors) {
  final inputMap = node.parameters['inputMap'];
  if (inputMap == null) return;
  if (inputMap is! Map<String, Object?>) {
    errors.add('Sub Workflow node ${node.id} inputMap must be an object.');
    return;
  }
  for (final entry in inputMap.entries) {
    final key = entry.key.trim();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
      errors.add('Sub Workflow node ${node.id} inputMap key $key is invalid.');
    }
    final expression = entry.value;
    if (expression is! String || !isSafeContextExpression(expression)) {
      errors.add(
        'Sub Workflow node ${node.id} inputMap value for $key must read context.',
      );
    }
  }
}
