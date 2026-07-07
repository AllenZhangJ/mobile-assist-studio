part of '../../studio_mac_workspace.dart';

// Workflow 画布绘制器，负责节点连线、连接预览和网格背景绘制。
class _WorkflowCanvasPainter extends CustomPainter {
  const _WorkflowCanvasPainter({
    required this.workflow,
    required this.positions,
    required this.executionFocus,
    required this.selectedEdge,
    required this.connectionPreviewStart,
    required this.connectionPreviewEnd,
  });

  final WorkflowDefinition workflow;
  final Map<String, Offset> positions;
  final RuntimeExecutionFocus executionFocus;
  final _WorkflowSelectedEdge? selectedEdge;
  final Offset? connectionPreviewStart;
  final Offset? connectionPreviewEnd;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas, size);
    _paintEdges(canvas);
    _paintConnectionPreview(canvas);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StudioColors.border.withValues(alpha: 0.28)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintEdges(Canvas canvas) {
    for (final edge in _workflowGraphEdges(workflow)) {
      final from = positions[edge.fromNodeId];
      if (from == null) continue;
      _paintEdge(
        canvas,
        fromNodeId: edge.fromNodeId,
        toNodeId: edge.toNodeId,
        kind: edge.kind,
      );
    }
  }

  // 绘制单条画布边，普通边和 Catch 错误边共享同一视觉算法。
  void _paintEdge(
    Canvas canvas, {
    required String fromNodeId,
    required String toNodeId,
    required _WorkflowSelectedEdgeKind kind,
  }) {
    final from = positions[fromNodeId];
    final to = positions[toNodeId];
    if (from == null || to == null) return;
    final start = _WorkflowCanvasLayout.edgeStartFor(from);
    final end = _WorkflowCanvasLayout.edgeEndFor(to);
    final completedEdge =
        kind == _WorkflowSelectedEdgeKind.next &&
        executionFocus.completedNodeIds.contains(fromNodeId) &&
        (executionFocus.completedNodeIds.contains(toNodeId) ||
            executionFocus.activeNodeId == toNodeId ||
            executionFocus.failedNodeId == toNodeId);
    final selected =
        selectedEdge?.fromNodeId == fromNodeId &&
        selectedEdge?.toNodeId == toNodeId &&
        selectedEdge?.kind == kind;
    final edgeColor = selected
        ? StudioColors.amber
        : completedEdge
        ? StudioColors.green
        : kind == _WorkflowSelectedEdgeKind.onError
        ? StudioColors.red
        : StudioColors.cyan;
    final paint = Paint()
      ..color = edgeColor.withValues(
        alpha: selected
            ? 0.88
            : completedEdge
            ? 0.72
            : kind == _WorkflowSelectedEdgeKind.onError
            ? 0.54
            : 0.44,
      )
      ..strokeWidth = selected
          ? 3.2
          : completedEdge
          ? 2.6
          : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arrowPaint = Paint()
      ..color = edgeColor.withValues(alpha: completedEdge ? 0.82 : 0.58)
      ..style = PaintingStyle.fill;
    final midY = start.dy + (end.dy - start.dy) / 2;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
    if (selected) {
      canvas.drawPath(
        path,
        Paint()
          ..color = StudioColors.amber.withValues(alpha: 0.14)
          ..strokeWidth = 9
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(path, paint);
    canvas.drawPath(
      Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - 5, end.dy - 8)
        ..lineTo(end.dx + 5, end.dy - 8)
        ..close(),
      arrowPaint,
    );
  }

  void _paintConnectionPreview(Canvas canvas) {
    final start = connectionPreviewStart;
    final end = connectionPreviewEnd;
    if (start == null || end == null) return;
    final midX = start.dx + (end.dx - start.dx) / 2;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = StudioColors.cyan.withValues(alpha: 0.16)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = StudioColors.cyan.withValues(alpha: 0.78)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _WorkflowCanvasPainter oldDelegate) {
    return oldDelegate.workflow != workflow ||
        oldDelegate.positions != positions ||
        oldDelegate.executionFocus != executionFocus ||
        oldDelegate.selectedEdge != selectedEdge ||
        oldDelegate.connectionPreviewStart != connectionPreviewStart ||
        oldDelegate.connectionPreviewEnd != connectionPreviewEnd;
  }
}
