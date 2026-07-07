part of '../../studio_mac_workspace.dart';

// Workflow 画布拖拽动作，集中处理节点移动的临时位置和提交。
extension _WorkflowCanvasDragActions on _WorkflowVisualListState {
  // 更新正在拖拽的节点位置，多选时会同步移动整个选区。
  void _moveDragPosition(
    WorkflowNode node,
    Offset delta,
    Map<String, Offset> layoutPositions,
  ) {
    if (widget.locked) return;
    final movingNodesIds =
        widget.selectedNodeIds.length > 1 &&
            widget.selectedNodeIds.contains(node.id)
        ? widget.selectedNodeIds
        : <String>{node.id};
    _updateWorkflowCanvasState(() {
      for (final nodeId in movingNodesIds) {
        final fallback = layoutPositions[nodeId];
        if (fallback == null) continue;
        final current = _dragPositions[nodeId] ?? fallback;
        final next = Offset(
          (current.dx + delta.dx / _scale).clamp(
            _WorkflowCanvasLayout.padding,
            double.infinity,
          ),
          (current.dy + delta.dy / _scale).clamp(
            _WorkflowCanvasLayout.padding,
            double.infinity,
          ),
        );
        _dragPositions[nodeId] = next;
      }
    });
  }

  // 提交拖拽结果给页面层，由页面层通过 Runtime 保存 Project DSL。
  void _commitDragPosition(
    WorkflowNode node,
    Map<String, Offset> layoutPositions,
  ) {
    final movingNodesIds =
        widget.selectedNodeIds.length > 1 &&
            widget.selectedNodeIds.contains(node.id)
        ? widget.selectedNodeIds
        : <String>{node.id};
    final positionsByNodeId = <String, Offset>{};
    for (final nodeId in movingNodesIds) {
      final position = _dragPositions.remove(nodeId) ?? layoutPositions[nodeId];
      if (position != null) positionsByNodeId[nodeId] = position;
    }
    _updateWorkflowCanvasState(() {});
    if (positionsByNodeId.length > 1) {
      widget.onMoveNodes(positionsByNodeId);
    } else if (positionsByNodeId[node.id] case final position?) {
      widget.onMoveNode(node, position);
    }
  }
}
