part of '../../studio_mac_workspace.dart';

// Workflow 画布连线动作，集中处理端口连接、拖拽连线和端口命中。
extension _WorkflowCanvasConnectionActions on _WorkflowVisualListState {
  // 从节点输出端口开始点选连线，End 节点不允许作为起点。
  void _startConnection(WorkflowNode node) {
    if (widget.locked || node.type == WorkflowNodeType.end) return;
    _updateWorkflowCanvasState(() {
      _connectingFromNodesId = node.id;
      _connectionPreviewStart = null;
      _connectionPreviewEnd = null;
    });
    widget.onSelectEdge(null);
  }

  // 完成点选连线，并把连接变更交给页面层保存。
  void _completeConnection(WorkflowNode target) {
    final sourceNodesId = _connectingFromNodesId;
    if (widget.locked ||
        sourceNodesId == null ||
        !_workflowCanAddEdge(
          widget.workflow,
          fromNodeId: sourceNodesId,
          toNodeId: target.id,
        )) {
      return;
    }
    _updateWorkflowCanvasState(() {
      _connectingFromNodesId = null;
      _connectionPreviewStart = null;
      _connectionPreviewEnd = null;
    });
    widget.onConnectNodes(sourceNodesId, target.id);
  }

  // 取消当前连线草稿，并清理预览线。
  void _cancelConnection() {
    if (_connectingFromNodesId != null) {
      _updateWorkflowCanvasState(() {
        _connectingFromNodesId = null;
        _connectionPreviewStart = null;
        _connectionPreviewEnd = null;
      });
    }
  }

  // 开始拖拽式连线，并记录预览线起点和当前落点。
  void _startDragConnection({
    required WorkflowNode source,
    required Offset outputPort,
    required Offset globalPosition,
  }) {
    if (widget.locked || source.type == WorkflowNodeType.end) return;
    final canvasPosition = _canvasOffsetFromGlobal(globalPosition);
    _updateWorkflowCanvasState(() {
      _connectingFromNodesId = source.id;
      _connectionPreviewStart = outputPort;
      _connectionPreviewEnd = canvasPosition ?? outputPort;
    });
    widget.onSelectEdge(null);
  }

  // 更新拖拽连线的当前落点，供画布 Painter 实时绘制预览。
  void _updateDragConnection(Offset globalPosition) {
    if (_connectingFromNodesId == null) return;
    final canvasPosition = _canvasOffsetFromGlobal(globalPosition);
    if (canvasPosition == null) return;
    _updateWorkflowCanvasState(() => _connectionPreviewEnd = canvasPosition);
  }

  // 结束拖拽连线，并在命中输入端口时提交连接。
  void _finishDragConnection(_WorkflowCanvasLayout layout) {
    final sourceNodesId = _connectingFromNodesId;
    final end = _connectionPreviewEnd;
    if (sourceNodesId == null || end == null) {
      _cancelConnection();
      return;
    }
    final targetNodesId = _nodeInputPortHitTest(
      end,
      layout,
      excludedNodesId: sourceNodesId,
    );
    _updateWorkflowCanvasState(() {
      _connectingFromNodesId = null;
      _connectionPreviewStart = null;
      _connectionPreviewEnd = null;
    });
    if (targetNodesId != null &&
        _workflowCanAddEdge(
          widget.workflow,
          fromNodeId: sourceNodesId,
          toNodeId: targetNodesId,
        )) {
      widget.onConnectNodes(sourceNodesId, targetNodesId);
    }
  }

  // 把全局指针坐标换算为画布坐标，供端口和边命中使用。
  Offset? _canvasOffsetFromGlobal(Offset globalPosition) {
    final renderObject = _canvasStackKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return null;
    return renderObject.globalToLocal(globalPosition);
  }

  // 查找离拖拽落点最近的输入端口，排除源节点自身。
  String? _nodeInputPortHitTest(
    Offset canvasPosition,
    _WorkflowCanvasLayout layout, {
    required String excludedNodesId,
  }) {
    const hitRadius = _WorkflowCanvasPort.size * 1.9;
    String? nearestNodesId;
    var nearestDistance = double.infinity;
    for (final node in widget.workflow.nodes) {
      if (node.id == excludedNodesId) continue;
      final nodePosition = layout.positions[node.id];
      if (nodePosition == null) continue;
      final inputPort = _WorkflowCanvasLayout.inputPortFor(nodePosition);
      final distance = (canvasPosition - inputPort).distance;
      if (distance <= hitRadius && distance < nearestDistance) {
        nearestNodesId = node.id;
        nearestDistance = distance;
      }
    }
    return nearestNodesId;
  }
}
