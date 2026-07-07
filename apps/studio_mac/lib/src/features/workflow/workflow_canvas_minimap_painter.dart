part of '../../studio_mac_workspace.dart';

// Workflow 小地图绘制器，负责缩略图边线、节点和视口框。
class _WorkflowMiniMapPainter extends CustomPainter {
  const _WorkflowMiniMapPainter({
    required this.workflow,
    required this.positions,
    required this.canvasSize,
    required this.viewportRect,
    required this.executionFocus,
    required this.selectedNodeId,
    required this.selectedNodeIds,
  });

  final WorkflowDefinition workflow;
  final Map<String, Offset> positions;
  final Size canvasSize;
  final Rect viewportRect;
  final RuntimeExecutionFocus executionFocus;
  final String? selectedNodeId;
  final Set<String> selectedNodeIds;

  // 绘制小地图背景、连线、节点状态和当前视口。
  @override
  void paint(Canvas canvas, Size size) {
    final canvasRect = Offset.zero & canvasSize;
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final transform = _WorkflowMiniMapTransform.forSize(
      canvasSize: canvasSize,
      paintSize: size,
    );
    final mapRect = transform.mapRect;

    _paintBackground(canvas, mapRect);
    _paintEdges(canvas, transform);
    _paintNodes(canvas, transform);
    _paintViewport(canvas, transform, canvasRect);
  }

  // 判断小地图输入是否变化，变化时重新绘制。
  @override
  bool shouldRepaint(covariant _WorkflowMiniMapPainter oldDelegate) {
    return oldDelegate.workflow != workflow ||
        oldDelegate.positions != positions ||
        oldDelegate.canvasSize != canvasSize ||
        oldDelegate.viewportRect != viewportRect ||
        oldDelegate.executionFocus != executionFocus ||
        oldDelegate.selectedNodeId != selectedNodeId ||
        oldDelegate.selectedNodeIds != selectedNodeIds;
  }

  // 绘制小地图的底色和边框。
  void _paintBackground(Canvas canvas, Rect mapRect) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(mapRect, const Radius.circular(6)),
      Paint()..color = StudioColors.background.withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(mapRect, const Radius.circular(6)),
      Paint()
        ..color = StudioColors.border.withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  // 绘制普通边和 Catch 错误边，颜色与主画布语义保持一致。
  void _paintEdges(Canvas canvas, _WorkflowMiniMapTransform transform) {
    for (final edge in _workflowGraphEdges(workflow)) {
      final from = positions[edge.fromNodeId];
      final to = positions[edge.toNodeId];
      if (from == null || to == null) continue;
      final edgePaint = Paint()
        ..color = _miniMapEdgeColor(edge.kind)
        ..strokeWidth = 1;
      canvas.drawLine(
        transform.mapPoint(_nodeCenter(from)),
        transform.mapPoint(_nodeCenter(to)),
        edgePaint,
      );
    }
  }

  // 绘制节点缩略块，并保留选中态和执行态提示。
  void _paintNodes(Canvas canvas, _WorkflowMiniMapTransform transform) {
    for (final node in workflow.nodes) {
      final position = positions[node.id];
      if (position == null) continue;
      final nodeRect = transform.mapCanvasRect(
        Rect.fromLTWH(
          position.dx,
          position.dy,
          _WorkflowCanvasLayout.nodeWidth,
          _WorkflowCanvasLayout.nodeHeight,
        ),
      );
      final selected =
          node.id == selectedNodeId || selectedNodeIds.contains(node.id);
      final executionState = _executionStateForNodes(node.id, executionFocus);
      final nodePaint = Paint()
        ..color = selected
            ? StudioColors.cyan.withValues(alpha: 0.78)
            : _colorForExecutionState(
                executionState,
                _toneForNodes(node.type),
              ).withValues(alpha: 0.52);
      canvas.drawRRect(
        RRect.fromRectAndRadius(nodeRect, const Radius.circular(2)),
        nodePaint,
      );
    }
  }

  // 绘制当前主画布可见区域，帮助用户理解所在位置。
  void _paintViewport(
    Canvas canvas,
    _WorkflowMiniMapTransform transform,
    Rect canvasRect,
  ) {
    if (!viewportRect.overlaps(canvasRect)) return;
    final visibleRect = transform.mapCanvasRect(
      viewportRect.intersect(canvasRect),
    );
    canvas.drawRect(
      visibleRect,
      Paint()..color = StudioColors.cyan.withValues(alpha: 0.12),
    );
    canvas.drawRect(
      visibleRect,
      Paint()
        ..color = StudioColors.cyan.withValues(alpha: 0.84)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  // 计算节点在画布中的中心点，供小地图连线使用。
  Offset _nodeCenter(Offset position) {
    return Offset(
      position.dx + _WorkflowCanvasLayout.nodeWidth / 2,
      position.dy + _WorkflowCanvasLayout.nodeHeight / 2,
    );
  }

  // 返回小地图连线颜色，错误边使用红色弱提示。
  Color _miniMapEdgeColor(_WorkflowSelectedEdgeKind kind) {
    return switch (kind) {
      _WorkflowSelectedEdgeKind.next => StudioColors.cyan.withValues(
        alpha: 0.28,
      ),
      _WorkflowSelectedEdgeKind.onError => StudioColors.red.withValues(
        alpha: 0.34,
      ),
    };
  }
}

// 小地图坐标变换器，集中处理画布坐标和缩略图坐标换算。
final class _WorkflowMiniMapTransform {
  const _WorkflowMiniMapTransform({
    required this.scale,
    required this.origin,
    required this.mapRect,
  });

  final double scale;
  final Offset origin;
  final Rect mapRect;

  // 根据画布尺寸和绘制区域计算缩放比例与居中偏移。
  factory _WorkflowMiniMapTransform.forSize({
    required Size canvasSize,
    required Size paintSize,
  }) {
    final scale = math.min(
      paintSize.width / canvasSize.width,
      paintSize.height / canvasSize.height,
    );
    final mapSize = Size(canvasSize.width * scale, canvasSize.height * scale);
    final origin = Offset(
      (paintSize.width - mapSize.width) / 2,
      (paintSize.height - mapSize.height) / 2,
    );
    return _WorkflowMiniMapTransform(
      scale: scale,
      origin: origin,
      mapRect: origin & mapSize,
    );
  }

  // 把画布点映射到小地图点。
  Offset mapPoint(Offset point) {
    return Offset(origin.dx + point.dx * scale, origin.dy + point.dy * scale);
  }

  // 把画布矩形映射到小地图矩形。
  Rect mapCanvasRect(Rect rect) {
    return Rect.fromPoints(mapPoint(rect.topLeft), mapPoint(rect.bottomRight));
  }
}
