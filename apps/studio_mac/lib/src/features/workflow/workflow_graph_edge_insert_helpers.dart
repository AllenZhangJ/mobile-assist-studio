part of '../../studio_mac_workspace.dart';

// Workflow 边上插入 helper，负责把原边改接到新节点并保留原目标。

// 在指定边中插入节点，并保持原边目标作为后继。
WorkflowDefinition _workflowInsertingNodesOnEdge(
  WorkflowDefinition workflow, {
  required String fromNodeId,
  required String toNodeId,
  required WorkflowNode insertedNodes,
  _WorkflowSelectedEdgeKind kind = _WorkflowSelectedEdgeKind.next,
}) {
  final nodes = <WorkflowNode>[];
  for (final node in workflow.nodes) {
    final match = _workflowMatchedEditableEdge(
      node,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
      kind: kind,
    );
    if (!match.matched) {
      nodes.add(node);
      continue;
    }
    final rewritten = _nodesAfterInsertingOnMatchedEdge(
      workflow,
      source: node,
      toNodeId: toNodeId,
      insertedNodes: insertedNodes,
      match: match,
    );
    nodes.addAll(rewritten);
  }
  return _workflowWithNodes(workflow, nodes);
}

// 判断当前节点是否命中可编辑边，同时记录命中的是普通边还是错误边。
({bool matched, bool onError}) _workflowMatchedEditableEdge(
  WorkflowNode node, {
  required String fromNodeId,
  required String toNodeId,
  required _WorkflowSelectedEdgeKind kind,
}) {
  if (node.id != fromNodeId) return (matched: false, onError: false);
  return switch (kind) {
    _WorkflowSelectedEdgeKind.next => (
      matched: node.next.contains(toNodeId),
      onError: false,
    ),
    _WorkflowSelectedEdgeKind.onError => (
      matched: _catchOnErrorTarget(node) == toNodeId,
      onError: true,
    ),
  };
}

// 生成边上插入后的节点片段，Loop 会补默认 body 骨架。
List<WorkflowNode> _nodesAfterInsertingOnMatchedEdge(
  WorkflowDefinition workflow, {
  required WorkflowNode source,
  required String toNodeId,
  required WorkflowNode insertedNodes,
  required ({bool matched, bool onError}) match,
}) {
  if (insertedNodes.type == WorkflowNodeType.loop) {
    final bodyNodes = _workflowLoopBodyNodesForInsert(
      workflow,
      insertedNodes.id,
    );
    return [
      _nodeWithRewiredEdge(source, toNodeId, insertedNodes.id, match),
      insertedNodes.copyWith(next: [bodyNodes.id, toNodeId]),
      bodyNodes,
    ];
  }
  return [
    _nodeWithRewiredEdge(source, toNodeId, insertedNodes.id, match),
    insertedNodes.copyWith(next: [toNodeId]),
  ];
}

// 把命中的边改接到插入节点，隐藏 next 与 onError 的存储差别。
WorkflowNode _nodeWithRewiredEdge(
  WorkflowNode node,
  String oldToNodeId,
  String newToNodeId,
  ({bool matched, bool onError}) match,
) {
  if (match.onError) return _nodeWithOnError(node, newToNodeId);
  return node.copyWith(
    next: _replacedNextTargets(
      node.next,
      oldToNodeId: oldToNodeId,
      newToNodeId: newToNodeId,
    ),
  );
}
