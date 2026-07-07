part of '../../studio_mac_workspace.dart';

// Inspector 连线候选扩展，集中维护新增连接的可选目标。
extension _NodeInspectorEditorConnectionCandidatesState
    on _NodeInspectorEditorState {
  // 同步连接目标下拉框，避免候选节点变化后留下无效选择。
  void _syncEdgeTarget() {
    final candidates = _edgeTargetCandidates();
    if (_edgeTargetId == null ||
        !candidates.any((node) => node.id == _edgeTargetId)) {
      _edgeTargetId = candidates.isEmpty ? null : candidates.first.id;
    }
  }

  // 生成可新增连接的候选节点，排除自身和已连接节点。
  List<WorkflowNode> _edgeTargetCandidates() {
    return widget.workflow.nodes
        .where(
          (node) => _workflowCanAddEdge(
            widget.workflow,
            fromNodeId: widget.node.id,
            toNodeId: node.id,
          ),
        )
        .toList(growable: false);
  }
}
