part of '../workflow_dsl.dart';

// WorkflowValidateResult 表示 Project DSL 校验结果。
// 它只承载错误列表，UI 和 Runtime 都从同一结果派生状态。
final class WorkflowValidateResult {
  const WorkflowValidateResult._(this.errors);

  final List<String> errors;

  // 判断工作流是否可运行。
  bool get isValid => errors.isEmpty;

  static const valid = WorkflowValidateResult._(<String>[]);

  // 从错误集合创建校验结果，并清理空白错误。
  factory WorkflowValidateResult.fromErrors(Iterable<String> errors) {
    final normalized = errors
        .map((error) => error.trim())
        .where((error) => error.isNotEmpty)
        .toList(growable: false);
    if (normalized.isEmpty) return WorkflowValidateResult.valid;
    return WorkflowValidateResult._(List<String>.unmodifiable(normalized));
  }
}

// isSafeContextExpression 限制表达式只能读取 context.xxx。
// DSL 不开放任意 JS、Python 或 eval 执行。
bool isSafeContextExpression(String expression) {
  final trimmed = expression.trim();
  if (trimmed.isEmpty) return false;
  return RegExp(r'^context(?:\.[A-Za-z_][A-Za-z0-9_]*)+$').hasMatch(trimmed);
}

// WorkflowValidator 负责 Project DSL 的结构和节点参数校验。
// 保存、Source View、Visual View 和 Runtime 运行前都应复用同一规则。
final class WorkflowValidator {
  const WorkflowValidator();

  // 校验工作流定义，返回可供 UI 和 Runtime 复用的错误集合。
  WorkflowValidateResult validate(WorkflowDefinition workflow) {
    final errors = <String>[];
    if (workflow.id.trim().isEmpty) errors.add('Workflow id is required.');
    if (workflow.name.trim().isEmpty) errors.add('Workflow name is required.');
    if (workflow.nodes.isEmpty) {
      errors.add('Workflow must contain at least one node.');
    }

    final nodeIds = <String>{};
    final nodesById = <String, WorkflowNode>{};
    for (final node in workflow.nodes) {
      _validateNodeShape(node, nodeIds, errors);
      nodesById[node.id] = node;
      _validateNodeParameters(node, errors);
    }

    if (!nodeIds.contains(workflow.entryNodesId)) {
      errors.add('Entry node does not exist: ${workflow.entryNodesId}.');
    } else {
      _validateEntryNode(workflow, nodesById, errors);
    }

    for (final node in workflow.nodes) {
      _validateNodeReferences(node, nodeIds, errors);
    }

    if (errors.isNotEmpty) return WorkflowValidateResult._(errors);
    _validateReachability(workflow, errors);

    return errors.isEmpty
        ? WorkflowValidateResult.valid
        : WorkflowValidateResult._(errors);
  }

  // 校验节点 ID、重复 ID 和画布位置完整性。
  void _validateNodeShape(
    WorkflowNode node,
    Set<String> nodeIds,
    List<String> errors,
  ) {
    if (node.id.trim().isEmpty) errors.add('Nodes id is required.');
    if (!nodeIds.add(node.id)) errors.add('Duplicate node id: ${node.id}.');
    if (node.type == WorkflowNodeType.start && node.next.length > 1) {
      errors.add('Start node ${node.id} can have only one main branch.');
    }
    if (node.type == WorkflowNodeType.end && node.next.isNotEmpty) {
      errors.add('End node ${node.id} cannot have outgoing branches.');
    }
    final visual = node.visual;
    if (visual != null && visual.x != null && visual.y == null) {
      errors.add('Nodes ${node.id} visual position requires both x and y.');
    }
    if (visual != null && visual.y != null && visual.x == null) {
      errors.add('Nodes ${node.id} visual position requires both x and y.');
    }
  }

  // 校验入口节点类型，运行主循环只从 Start 语义开始。
  void _validateEntryNode(
    WorkflowDefinition workflow,
    Map<String, WorkflowNode> nodesById,
    List<String> errors,
  ) {
    final entryNode = nodesById[workflow.entryNodesId];
    if (entryNode == null) return;
    if (entryNode.type != WorkflowNodeType.start) {
      errors.add('Entry node ${workflow.entryNodesId} must be a Start node.');
    }
  }

  // 校验普通 next 引用和 Catch onError 引用。
  void _validateNodeReferences(
    WorkflowNode node,
    Set<String> nodeIds,
    List<String> errors,
  ) {
    for (final nextId in node.next) {
      if (nextId == node.id) {
        errors.add('Nodes ${node.id} cannot reference itself.');
        continue;
      }
      if (!nodeIds.contains(nextId)) {
        errors.add('Nodes ${node.id} references missing node $nextId.');
      }
    }
    if (node.type == WorkflowNodeType.catchNodes) {
      final onError = node.parameters['onError'];
      if (onError is String && onError.trim() == node.id) {
        errors.add('Catch node ${node.id} cannot reference itself onError.');
      } else if (onError != null &&
          (onError is! String ||
              onError.trim().isEmpty ||
              !nodeIds.contains(onError.trim()))) {
        errors.add('Catch node ${node.id} references missing onError node.');
      }
    }
  }

  // 校验所有节点能从入口节点抵达。
  void _validateReachability(WorkflowDefinition workflow, List<String> errors) {
    final reachable = <String>{};

    // 深度遍历普通 next 和 Catch 错误边。
    // 前面的引用校验已保证这里访问的节点存在。
    void visit(String nodeId) {
      if (!reachable.add(nodeId)) {
        return;
      }
      final node = workflow.nodes.firstWhere(
        (candidate) => candidate.id == nodeId,
      );
      for (final nextId in node.next) {
        visit(nextId);
      }
      if (node.type == WorkflowNodeType.catchNodes) {
        final onError = node.parameters['onError'];
        if (onError is String && onError.trim().isNotEmpty) {
          visit(onError.trim());
        }
      }
    }

    visit(workflow.entryNodesId);
    for (final node in workflow.nodes) {
      if (!reachable.contains(node.id)) {
        errors.add('Nodes ${node.id} is unreachable.');
      }
    }
  }
}
