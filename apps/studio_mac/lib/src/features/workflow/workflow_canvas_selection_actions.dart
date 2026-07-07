part of '../../studio_mac_workspace.dart';

// Workflow 画布选择动作，集中处理框选、边命中和自动整理入口。
extension _WorkflowCanvasSelectionActions on _WorkflowVisualListState {
  // 处理节点点击选择；按住 Shift/Cmd/Ctrl 时切换多选集合。
  // 该动作只改变编辑器选区，不写入 Project DSL。
  void _selectNodeFromCanvas(WorkflowNode node) {
    if (!_multiSelectModifierPressed()) {
      widget.onSelectNode(node);
      return;
    }

    final selected = <String>{
      ...widget.selectedNodeIds,
      if (widget.selectedNodeId case final selectedNodeId?) selectedNodeId,
    };
    if (!selected.add(node.id)) {
      selected.remove(node.id);
    }
    widget.onSelectNodes(selected);
  }

  // 判断当前是否处于多选修饰键状态，兼容 macOS 和常见外接键盘。
  bool _multiSelectModifierPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
  }

  // 切换框选模式，并清理连线和选区草稿。
  void _toggleBoxSelectMode() {
    _updateWorkflowCanvasState(() {
      _boxSelectMode = !_boxSelectMode;
      _selectionStart = null;
      _selectionRect = null;
      _connectingFromNodesId = null;
      _connectionPreviewStart = null;
      _connectionPreviewEnd = null;
    });
    widget.onSelectEdge(null);
  }

  // 清理画布本地临时态，然后触发上层自动整理命令。
  void _autoLayoutCanvas() {
    if (widget.locked) return;
    _updateWorkflowCanvasState(() {
      _dragPositions.clear();
      _connectingFromNodesId = null;
      _connectionPreviewStart = null;
      _connectionPreviewEnd = null;
      _selectionStart = null;
      _selectionRect = null;
      _boxSelectMode = false;
    });
    widget.onSelectEdge(null);
    widget.onAutoLayout();
  }

  // 在画布空白层点击时优先尝试命中连线。
  // 没有命中连线时清空节点和边选区，符合桌面画布的常见预期。
  void _selectEdgeAt(Offset globalPosition, _WorkflowCanvasLayout layout) {
    if (_boxSelectMode || _connectingFromNodesId != null) return;
    final canvasPosition = _canvasOffsetFromGlobal(globalPosition);
    if (canvasPosition == null) return;
    final hit = _edgeHitTest(canvasPosition, layout);
    if (hit == null) {
      widget.onSelectNodes(const <String>{});
      return;
    }
    widget.onSelectEdge(hit);
  }

  // 删除当前选中的边，真正的 DSL 写入由页面层兜底。
  void _deleteSelectedEdge() {
    final selected = widget.selectedEdge;
    if (selected == null || widget.locked) return;
    widget.onSelectEdge(null);
    widget.onRemoveEdge(selected);
  }

  // 遍历节点连线，找到离指针最近的可选边。
  _WorkflowSelectedEdge? _edgeHitTest(
    Offset canvasPosition,
    _WorkflowCanvasLayout layout,
  ) {
    const hitRadius = 18.0;
    _WorkflowSelectedEdge? nearest;
    var nearestDistance = double.infinity;
    for (final edge in _workflowGraphEdges(widget.workflow)) {
      final from = layout.positions[edge.fromNodeId];
      final to = layout.positions[edge.toNodeId];
      if (from == null || to == null) continue;
      final start = _WorkflowCanvasLayout.edgeStartFor(from);
      final end = _WorkflowCanvasLayout.edgeEndFor(to);
      final distance = _distanceToCubicEdge(canvasPosition, start, end);
      if (distance <= hitRadius && distance < nearestDistance) {
        nearestDistance = distance;
        nearest = _WorkflowSelectedEdge(
          fromNodeId: edge.fromNodeId,
          toNodeId: edge.toNodeId,
          kind: edge.kind,
          anchor: Offset(
            start.dx + (end.dx - start.dx) / 2,
            start.dy + (end.dy - start.dy) / 2,
          ),
        );
      }
    }
    return nearest;
  }

  // 近似计算点到贝塞尔连线的距离，用于点击命中。
  double _distanceToCubicEdge(Offset point, Offset start, Offset end) {
    final midY = start.dy + (end.dy - start.dy) / 2;
    var best = double.infinity;
    var previous = start;
    for (var i = 1; i <= 24; i += 1) {
      final t = i / 24;
      final sample = _cubicPoint(
        t,
        start,
        Offset(start.dx, midY),
        Offset(end.dx, midY),
        end,
      );
      final distance = _distanceToSegment(point, previous, sample);
      if (distance < best) best = distance;
      previous = sample;
    }
    return best;
  }

  // 根据三次贝塞尔参数取采样点，服务边命中距离计算。
  Offset _cubicPoint(double t, Offset p0, Offset p1, Offset p2, Offset p3) {
    final inv = 1 - t;
    return p0 * (inv * inv * inv) +
        p1 * (3 * inv * inv * t) +
        p2 * (3 * inv * t * t) +
        p3 * (t * t * t);
  }

  // 计算点到线段的最短距离，作为贝塞尔采样段的基础算法。
  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - start).distance;
    final t =
        (((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
                lengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();
    final projection = start + segment * t;
    return (point - projection).distance;
  }

  // 记录框选起点，并创建初始选择矩形。
  void _startBoxSelection(Offset position) {
    if (!_boxSelectMode || widget.locked) return;
    _updateWorkflowCanvasState(() {
      _selectionStart = position;
      _selectionRect = Rect.fromPoints(position, position);
    });
  }

  // 拖动框选时实时更新矩形和当前选中节点集合。
  void _updateBoxSelection(Offset position, _WorkflowCanvasLayout layout) {
    final start = _selectionStart;
    if (!_boxSelectMode || widget.locked || start == null) return;
    final selection = Rect.fromPoints(start, position).inflate(2);
    _updateWorkflowCanvasState(() {
      _selectionRect = selection;
    });
    final selected = _selectedNodeIdsForRect(selection, layout);
    widget.onSelectNodes(selected);
  }

  // 完成框选并提交最终选中节点集合。
  void _finishBoxSelection(Offset position, _WorkflowCanvasLayout layout) {
    final start = _selectionStart;
    if (!_boxSelectMode || widget.locked || start == null) return;
    final selection = Rect.fromPoints(start, position).inflate(2);
    final selected = _selectedNodeIdsForRect(selection, layout);
    _updateWorkflowCanvasState(() {
      _selectionStart = null;
      _selectionRect = null;
    });
    widget.onSelectNodes(selected);
  }

  // 按视口矩形筛选节点，框选结果只改变 UI 选择态。
  Set<String> _selectedNodeIdsForRect(
    Rect selection,
    _WorkflowCanvasLayout layout,
  ) {
    final selected = <String>{};
    for (final node in widget.workflow.nodes) {
      final nodePosition = layout.positions[node.id];
      if (nodePosition == null) continue;
      final canvasNodesRect = Rect.fromLTWH(
        nodePosition.dx,
        nodePosition.dy,
        _WorkflowCanvasLayout.nodeWidth,
        _WorkflowCanvasLayout.nodeHeight,
      );
      final nodeRect = _viewportRectForCanvasRect(canvasNodesRect);
      if (selection.overlaps(nodeRect)) selected.add(node.id);
    }
    return selected;
  }
}
