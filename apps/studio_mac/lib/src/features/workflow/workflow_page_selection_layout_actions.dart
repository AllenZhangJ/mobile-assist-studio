part of '../../studio_mac_workspace.dart';

// Workflow 画布选区布局动作，负责方向键微调、多选对齐和均分。
// 这里只生成 visual.position 更新，保存仍交给 Runtime updateWorkflow。

const _workflowCanvasNudgeStep = 12.0;
const _workflowCanvasLargeNudgeStep = 48.0;

enum _WorkflowCanvasAlignment { left, right, top, bottom }

enum _WorkflowCanvasDistribution { horizontal, vertical }

extension _WorkflowPageSelectionLayoutActions on _WorkflowPageState {
  // 用方向键移动当前节点选区，只写入 visual.position。
  // 该入口复用批量移动保存路径，避免快捷键绕过 DSL 校验。
  void _nudgeWorkflowCanvasSelection(Offset delta) {
    if (_selectedTab != _WorkflowTab.visual || _workflowGraphEditLocked) {
      return;
    }
    final workflow = widget.snapshot.workflow;
    final selectedNodeIds = _selectedNodeIds.isNotEmpty
        ? _selectedNodeIds
        : {if (_selectedNodeId case final selectedNodeId?) selectedNodeId};
    if (selectedNodeIds.isEmpty) return;

    final layout = _WorkflowCanvasLayout.fromWorkflow(workflow);
    final positionsByNodeId = <String, Offset>{};
    for (final node in workflow.nodes) {
      if (!selectedNodeIds.contains(node.id)) continue;
      final position = layout.positions[node.id];
      if (position == null) continue;
      positionsByNodeId[node.id] = position + delta;
    }
    if (positionsByNodeId.isEmpty) return;

    unawaited(_moveWorkflowNodes(positionsByNodeId));
  }

  // 将当前多选节点按指定方向对齐，只修改画布位置元数据。
  // 对齐复用批量位置保存路径，确保仍经过 Runtime 和 validator。
  void _alignWorkflowCanvasSelection(_WorkflowCanvasAlignment alignment) {
    if (_selectedTab != _WorkflowTab.visual || _workflowGraphEditLocked) {
      return;
    }
    final workflow = widget.snapshot.workflow;
    final selectedNodeIds = _selectedNodeIds;
    if (selectedNodeIds.length < 2) return;

    final selectedPositions = _selectedCanvasPositions(
      workflow,
      selectedNodeIds,
    );
    if (selectedPositions.length < 2) return;

    final positionsByNodeId = switch (alignment) {
      _WorkflowCanvasAlignment.left => _alignedLeftPositions(selectedPositions),
      _WorkflowCanvasAlignment.right => _alignedRightPositions(
        selectedPositions,
      ),
      _WorkflowCanvasAlignment.top => _alignedTopPositions(selectedPositions),
      _WorkflowCanvasAlignment.bottom => _alignedBottomPositions(
        selectedPositions,
      ),
    };
    unawaited(_moveWorkflowNodes(positionsByNodeId));
  }

  // 将当前多选节点按横向或纵向均分，只修改画布位置元数据。
  // 均分至少需要三个节点，并继续走批量位置保存路径。
  void _distributeWorkflowCanvasSelection(
    _WorkflowCanvasDistribution distribution,
  ) {
    if (_selectedTab != _WorkflowTab.visual || _workflowGraphEditLocked) {
      return;
    }
    final workflow = widget.snapshot.workflow;
    final selectedNodeIds = _selectedNodeIds;
    if (selectedNodeIds.length < 3) return;

    final selectedPositions = _selectedCanvasPositions(
      workflow,
      selectedNodeIds,
    );
    if (selectedPositions.length < 3) return;

    final positionsByNodeId = switch (distribution) {
      _WorkflowCanvasDistribution.horizontal => _distributedHorizontalPositions(
        selectedPositions,
      ),
      _WorkflowCanvasDistribution.vertical => _distributedVerticalPositions(
        selectedPositions,
      ),
    };
    unawaited(_moveWorkflowNodes(positionsByNodeId));
  }

  // 读取当前选区的画布位置，缺失位置的节点自动跳过。
  Map<String, Offset> _selectedCanvasPositions(
    WorkflowDefinition workflow,
    Set<String> selectedNodeIds,
  ) {
    final layout = _WorkflowCanvasLayout.fromWorkflow(workflow);
    final selectedPositions = <String, Offset>{};
    for (final nodeId in selectedNodeIds) {
      final position = layout.positions[nodeId];
      if (position != null) selectedPositions[nodeId] = position;
    }
    return selectedPositions;
  }

  // 生成左对齐后的节点位置，横坐标取当前选区最小值。
  Map<String, Offset> _alignedLeftPositions(Map<String, Offset> positions) {
    final left = positions.values
        .map((position) => position.dx)
        .reduce(math.min);
    return positions.map(
      (nodeId, position) => MapEntry(nodeId, Offset(left, position.dy)),
    );
  }

  // 生成右对齐后的节点位置，右边缘取当前选区最大值。
  Map<String, Offset> _alignedRightPositions(Map<String, Offset> positions) {
    final right = positions.values
        .map((position) => position.dx + _WorkflowCanvasLayout.nodeWidth)
        .reduce(math.max);
    return positions.map(
      (nodeId, position) => MapEntry(
        nodeId,
        Offset(right - _WorkflowCanvasLayout.nodeWidth, position.dy),
      ),
    );
  }

  // 生成顶对齐后的节点位置，纵坐标取当前选区最小值。
  Map<String, Offset> _alignedTopPositions(Map<String, Offset> positions) {
    final top = positions.values
        .map((position) => position.dy)
        .reduce(math.min);
    return positions.map(
      (nodeId, position) => MapEntry(nodeId, Offset(position.dx, top)),
    );
  }

  // 生成底对齐后的节点位置，底边缘取当前选区最大值。
  Map<String, Offset> _alignedBottomPositions(Map<String, Offset> positions) {
    final bottom = positions.values
        .map((position) => position.dy + _WorkflowCanvasLayout.nodeHeight)
        .reduce(math.max);
    return positions.map(
      (nodeId, position) => MapEntry(
        nodeId,
        Offset(position.dx, bottom - _WorkflowCanvasLayout.nodeHeight),
      ),
    );
  }

  // 生成横向均分后的节点位置，保持每个节点原有纵坐标。
  Map<String, Offset> _distributedHorizontalPositions(
    Map<String, Offset> positions,
  ) {
    final entries = positions.entries.toList()
      ..sort((a, b) => a.value.dx.compareTo(b.value.dx));
    final left = entries.first.value.dx;
    final right = entries.last.value.dx;
    final gap = (right - left) / (entries.length - 1);
    return {
      for (var index = 0; index < entries.length; index += 1)
        entries[index].key: Offset(left + gap * index, entries[index].value.dy),
    };
  }

  // 生成纵向均分后的节点位置，保持每个节点原有横坐标。
  Map<String, Offset> _distributedVerticalPositions(
    Map<String, Offset> positions,
  ) {
    final entries = positions.entries.toList()
      ..sort((a, b) => a.value.dy.compareTo(b.value.dy));
    final top = entries.first.value.dy;
    final bottom = entries.last.value.dy;
    final gap = (bottom - top) / (entries.length - 1);
    return {
      for (var index = 0; index < entries.length; index += 1)
        entries[index].key: Offset(entries[index].value.dx, top + gap * index),
    };
  }
}
