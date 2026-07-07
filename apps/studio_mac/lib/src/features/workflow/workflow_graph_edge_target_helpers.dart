part of '../../studio_mac_workspace.dart';

// Workflow 边目标 helper，负责新增、删除和改目标。

// 添加一条有向边，重复边会被忽略。
WorkflowDefinition _workflowAddingEdge(
  WorkflowDefinition workflow, {
  required String fromNodeId,
  required String toNodeId,
}) {
  return _workflowWithNodes(
    workflow,
    workflow.nodes.map((node) {
      if (node.id != fromNodeId || node.next.contains(toNodeId)) return node;
      return node.copyWith(
        next: {...node.next, toNodeId}.toList(growable: false),
      );
    }),
  );
}

// 删除一条有向边，其他节点不受影响。
WorkflowDefinition _workflowRemovingEdge(
  WorkflowDefinition workflow, {
  required String fromNodeId,
  required String toNodeId,
  _WorkflowSelectedEdgeKind kind = _WorkflowSelectedEdgeKind.next,
}) {
  return _workflowWithNodes(
    workflow,
    workflow.nodes.map((node) {
      if (node.id != fromNodeId) return node;
      if (kind == _WorkflowSelectedEdgeKind.onError) {
        if (_catchOnErrorTarget(node) != toNodeId) return node;
        return _nodeWithoutOnError(node);
      }
      return node.copyWith(
        next: node.next
            .where((nextId) => nextId != toNodeId)
            .toList(growable: false),
      );
    }),
  );
}

// 替换一条选中边的目标，保存时保留边的原始语义。
WorkflowDefinition _workflowReplacingEdgeTarget(
  WorkflowDefinition workflow, {
  required String fromNodeId,
  required String oldToNodeId,
  required String newToNodeId,
  _WorkflowSelectedEdgeKind kind = _WorkflowSelectedEdgeKind.next,
}) {
  if (oldToNodeId == newToNodeId || fromNodeId == newToNodeId) {
    return workflow;
  }
  return _workflowWithNodes(
    workflow,
    workflow.nodes.map((node) {
      if (node.id != fromNodeId) return node;
      if (kind == _WorkflowSelectedEdgeKind.onError) {
        if (_catchOnErrorTarget(node) != oldToNodeId) return node;
        return _nodeWithOnError(node, newToNodeId);
      }
      if (!node.next.contains(oldToNodeId)) return node;
      return node.copyWith(
        next: _replacedNextTargets(
          node.next,
          oldToNodeId: oldToNodeId,
          newToNodeId: newToNodeId,
        ),
      );
    }),
  );
}
