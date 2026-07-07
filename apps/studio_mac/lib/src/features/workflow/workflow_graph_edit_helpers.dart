part of '../../studio_mac_workspace.dart';

// Workflow 节点编辑 helper，负责节点插入和删除。

// 在指定节点之后插入节点，并为循环节点补最小 body 骨架。
WorkflowDefinition _workflowInsertingNodesAfter(
  WorkflowDefinition workflow, {
  required String anchorNodeId,
  required WorkflowNode insertedNodes,
}) {
  final nodes = <WorkflowNode>[];
  for (final node in workflow.nodes) {
    if (node.id == anchorNodeId) {
      if (insertedNodes.type == WorkflowNodeType.loop &&
          node.next.length <= 1) {
        final bodyNodes = _workflowLoopBodyNodesForInsert(
          workflow,
          insertedNodes.id,
        );
        nodes.add(node.copyWith(next: [insertedNodes.id]));
        nodes.add(
          insertedNodes.copyWith(next: [bodyNodes.id, ...node.next.take(1)]),
        );
        nodes.add(bodyNodes);
        continue;
      }
      nodes.add(node.copyWith(next: [insertedNodes.id]));
      nodes.add(insertedNodes.copyWith(next: node.next));
    } else {
      nodes.add(node);
    }
  }
  return _workflowWithNodes(workflow, nodes);
}

// 删除节点并把前驱连到被删节点的后继。
WorkflowDefinition _workflowDeletingNodes(
  WorkflowDefinition workflow,
  String nodeId,
) {
  final deletedNodes = _selectedNode(workflow, nodeId);
  if (deletedNodes == null) return workflow;
  final nodes = workflow.nodes
      .where((node) => node.id != nodeId)
      .map((node) {
        final next = <String>[];
        for (final nextId in node.next) {
          if (nextId == nodeId) {
            next.addAll(_replacementNextAfterDeleting(node, deletedNodes));
          } else {
            next.add(nextId);
          }
        }
        return WorkflowNode(
          id: node.id,
          type: node.type,
          label: node.label,
          next: next.toSet().toList(growable: false),
          parameters: _parametersAfterDeletingTarget(node, deletedNodes),
          visual: node.visual,
        );
      })
      .toList(growable: false);
  return _workflowWithNodes(workflow, nodes);
}

// 删除节点后修正参数引用，当前主要处理 Catch 错误分支。
Map<String, Object?> _parametersAfterDeletingTarget(
  WorkflowNode node,
  WorkflowNode deletedNodes,
) {
  if (_catchOnErrorTarget(node) != deletedNodes.id) return node.parameters;
  final replacement = _replacementNextAfterDeleting(
    node,
    deletedNodes,
  ).firstOrNull;
  if (replacement == null) {
    final parameters = Map<String, Object?>.of(node.parameters)
      ..remove('onError');
    return Map<String, Object?>.unmodifiable(parameters);
  }
  return Map<String, Object?>.unmodifiable({
    ...node.parameters,
    'onError': replacement,
  });
}

// 返回删除节点后的替代后继，并按前驱节点主线容量裁剪。
// 这样删除 Loop 等多出口节点时不会让 Start / Tap / Wait 生成非法多分支。
List<String> _replacementNextAfterDeleting(
  WorkflowNode predecessor,
  WorkflowNode deletedNodes,
) {
  final replacements = deletedNodes.next
      .where((nextId) => nextId != predecessor.id)
      .toSet()
      .toList(growable: false);
  final limit = _mainBranchLimitAfterDeleting(predecessor);
  if (limit == null || replacements.length <= limit) return replacements;
  return replacements.take(limit).toList(growable: false);
}

// 返回前驱节点删除重连时最多可承载的普通主线数量。
// 空值表示该节点按当前 DSL 规则可保留所有替代后继。
int? _mainBranchLimitAfterDeleting(WorkflowNode predecessor) {
  return switch (predecessor.type) {
    WorkflowNodeType.condition || WorkflowNodeType.loop => 2,
    WorkflowNodeType.visualBranch ||
    WorkflowNodeType.waitForTarget ||
    WorkflowNodeType.start ||
    WorkflowNodeType.tap ||
    WorkflowNodeType.wait ||
    WorkflowNodeType.swipe ||
    WorkflowNodeType.input ||
    WorkflowNodeType.snapshot ||
    WorkflowNodeType.catchNodes ||
    WorkflowNodeType.subWorkflow => 1,
    WorkflowNodeType.end => 0,
  };
}

// 生成 Loop 插入时的默认 body 节点，保证 Loop 有可执行的最小闭环。
WorkflowNode _workflowLoopBodyNodesForInsert(
  WorkflowDefinition workflow,
  String insertedNodeId,
) {
  final reservedNodesIds = workflow.nodes.map((node) => node.id).toSet()
    ..add(insertedNodeId);
  return WorkflowNode(
    id: _uniqueNodesIdWithReserved(reservedNodesIds, 'loop_body_wait'),
    type: WorkflowNodeType.wait,
    label: '循环等待',
    next: [insertedNodeId],
    parameters: const <String, Object?>{'ms': 500},
  );
}

// 复用 WorkflowDefinition 的基础信息，只替换节点列表。
WorkflowDefinition _workflowWithNodes(
  WorkflowDefinition workflow,
  Iterable<WorkflowNode> nodes,
) {
  return WorkflowDefinition(
    id: workflow.id,
    name: workflow.name,
    entryNodesId: workflow.entryNodesId,
    nodes: nodes.toList(growable: false),
  );
}
