part of '../../studio_mac_workspace.dart';

// Workflow 节点布局动作，只写 visual.position，不改变运行语义。
extension _WorkflowPageNodeLayoutActions on _WorkflowPageState {
  // 保存单个节点的可视位置，只影响 DSL 的 visual 字段。
  Future<void> _moveWorkflowNode(WorkflowNode node, Offset position) async {
    if (_workflowGraphEditLocked) return;
    final updatedNodes = node.copyWith(
      visual: WorkflowNodeVisual(x: position.dx, y: position.dy),
    );
    final updatedWorkflow = _workflowReplacingNodes(
      widget.snapshot.workflow,
      updatedNodes,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted || updated) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('位置未保存，请看控制台。')));
  }

  // 保存多选节点的批量位置，拖拽结束后一次性写入 DSL。
  Future<void> _moveWorkflowNodes(Map<String, Offset> positionsByNodeId) async {
    if (_workflowGraphEditLocked || positionsByNodeId.isEmpty) return;
    final updatedWorkflow = _workflowReplacingNodesPositions(
      widget.snapshot.workflow,
      positionsByNodeId,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted || updated) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('位置未保存，请看控制台。')));
  }

  // 清理节点可视坐标，让画布回到自动布局结果。
  Future<void> _autoLayoutWorkflowCanvas() async {
    if (_workflowGraphEditLocked) return;
    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final updatedWorkflow = _workflowClearingVisualPositions(
      widget.snapshot.workflow,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() => _savingGraphEdit = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '布局已重置。' : '整理未保存，请看控制台。')),
    );
  }
}
