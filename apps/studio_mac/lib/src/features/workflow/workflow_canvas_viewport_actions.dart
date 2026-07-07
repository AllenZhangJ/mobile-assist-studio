part of '../../studio_mac_workspace.dart';

// 画布视口快捷命令。
// 命令只影响本地编辑器视口，不写入 Project DSL。
enum _WorkflowCanvasViewportCommand { zoomIn, zoomOut, reset, fit }

// Workflow 画布视口动作，集中处理缩放、平移、聚焦和可见区域换算。
extension _WorkflowCanvasViewportActions on _WorkflowVisualListState {
  // 响应页面级快捷键派发的视口命令。
  // 这里使用最近一次布局尺寸，避免页面层知道画布内部布局细节。
  void _handleViewportCommand() {
    final command = widget.viewportCommand.value;
    if (command == null) return;
    switch (command) {
      case _WorkflowCanvasViewportCommand.zoomIn:
        _zoomInShortcut();
      case _WorkflowCanvasViewportCommand.zoomOut:
        _zoomOutShortcut();
      case _WorkflowCanvasViewportCommand.reset:
        _resetView();
      case _WorkflowCanvasViewportCommand.fit:
        _fitView(_latestViewportSize, _latestCanvasSize);
    }
  }

  // 同步 InteractiveViewer 手势产生的缩放比例，保持控制条数字准确。
  void _syncScaleFromTransform() {
    final nextScale = _transformationController.value.getMaxScaleOnAxis();
    if (mounted) {
      _updateWorkflowCanvasState(() => _scale = nextScale);
    }
  }

  // 设置画布缩放比例，并限制在可用范围内。
  void _setScale(double scale) {
    final nextScale = scale.clamp(0.5, 1.6).toDouble();
    _transformationController.value = Matrix4.diagonal3Values(
      nextScale,
      nextScale,
      1,
    );
    _updateWorkflowCanvasState(() => _scale = nextScale);
  }

  // 重置画布到 100% 缩放，供用户快速回到默认视图。
  void _resetView() => _setScale(1);

  // 画布放大快捷键，只改变本地视口，不写入 Project DSL。
  void _zoomInShortcut() => _setScale(_scale + 0.1);

  // 画布缩小快捷键，只改变本地视口，不写入 Project DSL。
  void _zoomOutShortcut() => _setScale(_scale - 0.1);

  // 将画布缩放到可查看全局结构，并在不遮挡起点的前提下居中显示。
  void _fitView(Size viewport, Size canvasSize) {
    if (viewport.width <= 0 || viewport.height <= 0) {
      _resetView();
      return;
    }
    final scaleX = viewport.width / canvasSize.width;
    final scaleY = viewport.height / canvasSize.height;
    final nextScale = (scaleX < scaleY ? scaleX : scaleY)
        .clamp(0.5, 1.0)
        .toDouble();
    final scaledCanvas = Size(
      canvasSize.width * nextScale,
      canvasSize.height * nextScale,
    );

    final centered = Offset(
      _fitTranslation(viewport.width, scaledCanvas.width),
      _fitTranslation(viewport.height, scaledCanvas.height),
    );
    final clamped = _clampedCanvasTranslation(
      centered,
      viewportSize: viewport,
      scaledCanvasSize: scaledCanvas,
    );
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(clamped.dx, clamped.dy, 0, 1)
      ..scaleByDouble(nextScale, nextScale, 1, 1);
    _updateWorkflowCanvasState(() => _scale = nextScale);
  }

  // 计算适配视图的单轴偏移，画布超出时保留原点避免端口被顶出屏幕。
  double _fitTranslation(double viewportAxis, double canvasAxis) {
    if (canvasAxis <= viewportAxis) return (viewportAxis - canvasAxis) / 2;
    return 0;
  }

  // 把指定画布坐标移动到视口中心，用于节点导航和迷你图跳转。
  void _centerCanvasOn(
    Offset canvasPoint, {
    required Size viewportSize,
    required Size canvasSize,
  }) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;
    final scale = _transformationController.value
        .getMaxScaleOnAxis()
        .clamp(0.5, 1.6)
        .toDouble();
    final scaledCanvas = Size(
      canvasSize.width * scale,
      canvasSize.height * scale,
    );
    final translation = Offset(
      viewportSize.width / 2 - canvasPoint.dx * scale,
      viewportSize.height / 2 - canvasPoint.dy * scale,
    );
    final clamped = _clampedCanvasTranslation(
      translation,
      viewportSize: viewportSize,
      scaledCanvasSize: scaledCanvas,
    );
    _transformationController.value = Matrix4.identity()
      ..translateByDouble(clamped.dx, clamped.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    _updateWorkflowCanvasState(() => _scale = scale);
  }

  // 选中并定位到目标节点，供节点导航器使用。
  void _focusNodesOnCanvas(
    String nodeId, {
    required _WorkflowCanvasLayout layout,
    required Size viewportSize,
  }) {
    final node = _selectedNode(widget.workflow, nodeId);
    final position = layout.positions[nodeId];
    if (node == null || position == null) return;
    widget.onSelectNode(node);
    _centerCanvasOn(
      Offset(
        position.dx + _WorkflowCanvasLayout.nodeWidth / 2,
        position.dy + _WorkflowCanvasLayout.nodeHeight / 2,
      ),
      viewportSize: viewportSize,
      canvasSize: layout.size,
    );
  }

  // 限制画布平移范围，允许少量边界外留白但不让画布完全滑走。
  Offset _clampedCanvasTranslation(
    Offset translation, {
    required Size viewportSize,
    required Size scaledCanvasSize,
  }) {
    const boundary = 260.0;

    double clampAxis(double value, double viewport, double canvas) {
      final min = viewport - canvas - boundary;
      const max = boundary;
      if (min > max) return (viewport - canvas) / 2;
      return value.clamp(min, max).toDouble();
    }

    return Offset(
      clampAxis(translation.dx, viewportSize.width, scaledCanvasSize.width),
      clampAxis(translation.dy, viewportSize.height, scaledCanvasSize.height),
    );
  }

  // 把画布矩形换算为当前视口矩形，供框选命中使用。
  Rect _viewportRectForCanvasRect(Rect canvasRect) {
    return Rect.fromPoints(
      _viewportOffsetForCanvas(canvasRect.topLeft),
      _viewportOffsetForCanvas(canvasRect.bottomRight),
    );
  }

  // 把画布坐标换算到视口坐标，复用当前缩放和平移矩阵。
  Offset _viewportOffsetForCanvas(Offset canvasOffset) {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    return Offset(
      canvasOffset.dx * scale + matrix.storage[12],
      canvasOffset.dy * scale + matrix.storage[13],
    );
  }

  // 计算当前视口覆盖的画布区域，供 Mini Map 展示取景框。
  Rect _visibleCanvasRect(Size viewportSize) {
    final matrix = _transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    if (scale <= 0) return Rect.zero;
    return Rect.fromLTWH(
      -matrix.storage[12] / scale,
      -matrix.storage[13] / scale,
      viewportSize.width / scale,
      viewportSize.height / scale,
    );
  }
}
