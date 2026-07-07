part of '../../studio_mac_workspace.dart';

// Workflow 图查询 helper，负责节点查找、导航筛选和边存在判断。

// 根据选中 ID 查找节点，未选中时返回空。
WorkflowNode? _selectedNode(WorkflowDefinition workflow, String? nodeId) {
  if (nodeId == null) return null;
  for (final node in workflow.nodes) {
    if (node.id == nodeId) return node;
  }
  return null;
}

// 按查询词筛选导航节点，供画布导航器使用。
Iterable<WorkflowNode> _workflowNavigatorResults(
  WorkflowDefinition workflow,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return workflow.nodes;
  return workflow.nodes.where((node) {
    final haystack = '${node.id} ${node.label} ${node.type.name}'.toLowerCase();
    return haystack.contains(normalized);
  });
}

// 判断节点是否允许被复制，入口和终点永远受保护。
bool _workflowNodesCanDuplicate(
  WorkflowNode node,
  WorkflowDefinition workflow,
) {
  return node.type != WorkflowNodeType.start &&
      node.type != WorkflowNodeType.end &&
      node.id != workflow.entryNodesId;
}

// 判断流程中是否存在指定节点。
bool _workflowContainsNodes(WorkflowDefinition workflow, String nodeId) {
  return workflow.nodes.any((node) => node.id == nodeId);
}

// 根据节点 ID 取展示标签，用于边和节点摘要。
String? _nodeLabelById(WorkflowDefinition workflow, String? nodeId) {
  return _selectedNode(workflow, nodeId)?.label;
}

// 遍历节点的全部目标边，包含普通后续和 Catch 错误分支。
Iterable<_WorkflowGraphEdge> _workflowGraphEdges(
  WorkflowDefinition workflow,
) sync* {
  for (final node in workflow.nodes) {
    for (final nextId in node.next) {
      yield _WorkflowGraphEdge(
        fromNodeId: node.id,
        toNodeId: nextId,
        kind: _WorkflowSelectedEdgeKind.next,
      );
    }
    final onErrorId = _catchOnErrorTarget(node);
    if (onErrorId == null) continue;
    yield _WorkflowGraphEdge(
      fromNodeId: node.id,
      toNodeId: onErrorId,
      kind: _WorkflowSelectedEdgeKind.onError,
    );
  }
}

// 返回节点所有可达目标 ID，供布局和导航算法统一使用。
Iterable<String> _workflowOutgoingTargetIds(WorkflowNode node) sync* {
  yield* node.next;
  final onErrorId = _catchOnErrorTarget(node);
  if (onErrorId != null) yield onErrorId;
}

// 判断画布选中的具体边是否仍存在于 DSL 中。
bool _workflowHasSelectedEdge(
  WorkflowDefinition workflow,
  _WorkflowSelectedEdge edge,
) {
  final source = _selectedNode(workflow, edge.fromNodeId);
  if (source == null) return false;
  return switch (edge.kind) {
    _WorkflowSelectedEdgeKind.next => source.next.contains(edge.toNodeId),
    _WorkflowSelectedEdgeKind.onError =>
      _catchOnErrorTarget(source) == edge.toNodeId,
  };
}

// Workflow 图连线模型，隐藏 DSL 里 next 和 onError 的存储差异。
final class _WorkflowGraphEdge {
  const _WorkflowGraphEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.kind,
  });

  final String fromNodeId;
  final String toNodeId;
  final _WorkflowSelectedEdgeKind kind;
}
