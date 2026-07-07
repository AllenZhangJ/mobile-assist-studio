part of '../../studio_mac_workspace.dart';

// Workflow 画布布局模型，集中管理节点尺寸、端口和自动排布。
final class _WorkflowCanvasLayout {
  const _WorkflowCanvasLayout({required this.positions, required this.size});

  static const nodeWidth = 340.0;
  static const nodeHeight = 84.0;
  static const horizontalGap = 104.0;
  static const verticalGap = 44.0;
  static const padding = 28.0;

  final Map<String, Offset> positions;
  final Size size;

  // 返回节点输入端口坐标，供端口点击和拖拽命中使用。
  static Offset inputPortFor(Offset nodePosition) {
    return Offset(nodePosition.dx, nodePosition.dy + nodeHeight / 2);
  }

  // 返回节点输出端口坐标，供连线起点和命中判断使用。
  static Offset outputPortFor(Offset nodePosition) {
    return Offset(
      nodePosition.dx + nodeWidth,
      nodePosition.dy + nodeHeight / 2,
    );
  }

  // 返回连线绘制起点，当前使用节点底部中心。
  static Offset edgeStartFor(Offset nodePosition) {
    return Offset(
      nodePosition.dx + nodeWidth / 2,
      nodePosition.dy + nodeHeight,
    );
  }

  // 返回连线绘制终点，当前使用节点顶部中心。
  static Offset edgeEndFor(Offset nodePosition) {
    return Offset(nodePosition.dx + nodeWidth / 2, nodePosition.dy);
  }

  // 从 Project DSL 生成画布布局，优先尊重用户保存的 visual 位置。
  static _WorkflowCanvasLayout fromWorkflow(
    WorkflowDefinition workflow, {
    Map<String, Offset> overrides = const <String, Offset>{},
  }) {
    final depths = _nodeDepths(workflow);
    final rowsByDepth = <int, int>{};
    final positions = <String, Offset>{};

    for (final node in workflow.nodes) {
      final override = overrides[node.id];
      final visualPosition = _visualPosition(node);
      if (override != null || visualPosition != null) {
        positions[node.id] = override ?? visualPosition!;
        continue;
      }
      final depth = depths[node.id] ?? 0;
      final row = rowsByDepth[depth] ?? 0;
      rowsByDepth[depth] = row + 1;
      positions[node.id] = Offset(
        padding + row * (nodeWidth + horizontalGap),
        padding + depth * (nodeHeight + verticalGap),
      );
    }

    return _WorkflowCanvasLayout(
      positions: positions,
      size: _layoutSizeForPositions(positions),
    );
  }

  // 读取节点自带的视觉位置，缺失时交给自动布局。
  static Offset? _visualPosition(WorkflowNode node) {
    final visual = node.visual;
    if (visual == null || !visual.hasPosition) return null;
    return Offset(visual.x!, visual.y!);
  }

  // 根据所有节点位置推导画布尺寸，确保节点不会贴边。
  static Size _layoutSizeForPositions(Map<String, Offset> positions) {
    var maxX = padding + nodeWidth;
    var maxY = padding + nodeHeight;
    for (final position in positions.values) {
      maxX = math.max(maxX, position.dx + nodeWidth + padding);
      maxY = math.max(maxY, position.dy + nodeHeight + padding);
    }
    return Size(maxX, maxY);
  }

  // 通过可达边计算节点深度，普通边和错误分支都会参与排布。
  static Map<String, int> _nodeDepths(WorkflowDefinition workflow) {
    final byId = {for (final node in workflow.nodes) node.id: node};
    final depths = <String, int>{workflow.entryNodesId: 0};
    final queue = <String>[workflow.entryNodesId];
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final currentDepth = depths[currentId] ?? 0;
      final current = byId[currentId];
      if (current == null) continue;
      for (final nextId in _workflowOutgoingTargetIds(current)) {
        if (!depths.containsKey(nextId)) {
          depths[nextId] = currentDepth + 1;
          queue.add(nextId);
        }
      }
    }

    for (final node in workflow.nodes) {
      depths.putIfAbsent(node.id, () => depths.length);
    }
    return depths;
  }
}
