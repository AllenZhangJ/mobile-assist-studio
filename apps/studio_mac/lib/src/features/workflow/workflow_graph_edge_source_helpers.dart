part of '../../studio_mac_workspace.dart';

// Workflow 边起点 helper，负责把已有边从旧起点移动到新起点。

// 替换一条选中边的起点，语义上是移动边而不是复制边。
WorkflowDefinition _workflowReplacingEdgeSource(
  WorkflowDefinition workflow, {
  required String oldFromNodeId,
  required String newFromNodeId,
  required String toNodeId,
  _WorkflowSelectedEdgeKind kind = _WorkflowSelectedEdgeKind.next,
}) {
  if (oldFromNodeId == newFromNodeId || newFromNodeId == toNodeId) {
    return workflow;
  }
  final newSource = _selectedNode(workflow, newFromNodeId);
  if (kind == _WorkflowSelectedEdgeKind.next &&
      (newSource == null || newSource.type == WorkflowNodeType.end)) {
    return workflow;
  }
  if (kind == _WorkflowSelectedEdgeKind.onError &&
      (newSource == null ||
          newSource.type != WorkflowNodeType.catchNodes ||
          _catchOnErrorTarget(newSource) != null)) {
    return workflow;
  }
  return _workflowWithNodes(
    workflow,
    workflow.nodes.map((node) {
      if (kind == _WorkflowSelectedEdgeKind.onError) {
        return _nodeAfterReplacingOnErrorSource(
          node,
          oldFromNodeId: oldFromNodeId,
          newFromNodeId: newFromNodeId,
          toNodeId: toNodeId,
        );
      }
      return _nodeAfterReplacingNextSource(
        node,
        oldFromNodeId: oldFromNodeId,
        newFromNodeId: newFromNodeId,
        toNodeId: toNodeId,
      );
    }),
  );
}

// 移动普通 next 边的起点，旧起点删除目标，新起点补目标。
WorkflowNode _nodeAfterReplacingNextSource(
  WorkflowNode node, {
  required String oldFromNodeId,
  required String newFromNodeId,
  required String toNodeId,
}) {
  if (node.id == oldFromNodeId) {
    return node.copyWith(
      next: node.next
          .where((nextId) => nextId != toNodeId)
          .toList(growable: false),
    );
  }
  if (node.id == newFromNodeId && !node.next.contains(toNodeId)) {
    return node.copyWith(
      next: {...node.next, toNodeId}.toList(growable: false),
    );
  }
  return node;
}

// 移动 Catch 错误边的起点，旧 Catch 清空错误分支，新 Catch 写入目标。
WorkflowNode _nodeAfterReplacingOnErrorSource(
  WorkflowNode node, {
  required String oldFromNodeId,
  required String newFromNodeId,
  required String toNodeId,
}) {
  if (node.id == oldFromNodeId && _catchOnErrorTarget(node) == toNodeId) {
    return _nodeWithoutOnError(node);
  }
  if (node.id == newFromNodeId &&
      node.type == WorkflowNodeType.catchNodes &&
      _catchOnErrorTarget(node) == null) {
    return _nodeWithOnError(node, toNodeId);
  }
  return node;
}
