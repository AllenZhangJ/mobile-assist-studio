part of '../../studio_mac_workspace.dart';

// 生成可重接的目标节点，排除源节点和当前目标，避免自环和无意义保存。
Iterable<WorkflowNode> _edgeRetargetCandidates(
  WorkflowDefinition workflow,
  _WorkflowSelectedEdge edge,
) {
  return workflow.nodes.where((node) {
    if (node.id == edge.fromNodeId || node.id == edge.toNodeId) return false;
    return _workflowCanReplaceEdgeTarget(
      workflow,
      fromNodeId: edge.fromNodeId,
      oldToNodeId: edge.toNodeId,
      newToNodeId: node.id,
      kind: edge.kind,
    );
  });
}

// 生成可重接的起点节点，普通边排除 End，错误边只允许空闲 Catch。
Iterable<WorkflowNode> _edgeSourceCandidates(
  WorkflowDefinition workflow,
  _WorkflowSelectedEdge edge,
) {
  return workflow.nodes.where((node) {
    if (node.id == edge.fromNodeId || node.id == edge.toNodeId) return false;
    final basicAllowed = switch (edge.kind) {
      _WorkflowSelectedEdgeKind.next => node.type != WorkflowNodeType.end,
      _WorkflowSelectedEdgeKind.onError =>
        node.type == WorkflowNodeType.catchNodes &&
            _catchOnErrorTarget(node) == null,
    };
    if (!basicAllowed) return false;
    return _workflowCanReplaceEdgeSource(
      workflow,
      oldFromNodeId: edge.fromNodeId,
      newFromNodeId: node.id,
      toNodeId: edge.toNodeId,
      kind: edge.kind,
    );
  });
}
