part of '../../studio_mac_workspace.dart';

// Workflow 画布外层 chrome 分片，承载选择框、导航、小地图和控制条叠层。

extension _WorkflowCanvasChrome on _WorkflowVisualListState {
  /// 构建画布外层叠层。
  /// 这里只组合 UI chrome，不处理节点渲染、连线命中或 DSL 写入。
  List<Widget> _buildWorkflowCanvasChrome(
    _WorkflowCanvasLayout layout,
    Size viewportSize,
  ) {
    return [
      if (_selectionRect case final selectionRect?)
        _WorkflowCanvasSelectionRect(selectionRect: selectionRect),
      if (_boxSelectMode) _buildSelectionOverlay(layout),
      _buildLockBanner(),
      _buildCanvasOverview(viewportSize),
      _buildNodeNavigator(layout, viewportSize),
      _buildMiniMap(layout, viewportSize),
      _buildCanvasControls(viewportSize, layout),
    ];
  }

  /// 构建框选事件覆盖层。
  /// 覆盖层只在框选模式启用，避免影响普通拖拽和平移。
  Widget _buildSelectionOverlay(_WorkflowCanvasLayout layout) {
    return Positioned.fill(
      child: Listener(
        key: const ValueKey('workflow-selection-overlay'),
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => _startBoxSelection(event.localPosition),
        onPointerMove: (event) =>
            _updateBoxSelection(event.localPosition, layout),
        onPointerUp: (event) =>
            _finishBoxSelection(event.localPosition, layout),
        child: const SizedBox.expand(),
      ),
    );
  }

  /// 构建画布锁定提示。
  /// 锁定态来自页面状态，提示本身不触发任何编辑动作。
  Widget _buildLockBanner() {
    return Positioned(
      left: 12,
      top: 12,
      child: _WorkflowCanvasLockBanner(
        locked: widget.locked,
        reason: widget.lockReason,
      ),
    );
  }

  /// 构建画布只读概览条。
  /// 概览条只展示 DSL 派生摘要，不拦截点击，也不写入流程。
  Widget _buildCanvasOverview(Size viewportSize) {
    final leftInset = viewportSize.width >= 720 ? 72.0 : 12.0;
    final rightInset = viewportSize.width >= 720 ? 212.0 : 12.0;
    return Positioned(
      left: leftInset,
      right: rightInset,
      bottom: 12,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: _WorkflowCanvasOverview(
          model: _WorkflowCanvasOverviewModel.fromWorkflow(
            workflow: widget.workflow,
            diagnosticsByNodeId: widget.diagnosticsByNodeId,
            selectedNodeId: widget.selectedNodeId,
            selectedNodeIds: widget.selectedNodeIds,
            selectedEdge: widget.selectedEdge,
          ),
        ),
      ),
    );
  }

  /// 构建节点导航器。
  /// 搜索态保留在画布 State，导航动作只调整视口和选中焦点。
  Widget _buildNodeNavigator(_WorkflowCanvasLayout layout, Size viewportSize) {
    return Positioned(
      left: 12,
      bottom: 12,
      child: _WorkflowNodeNavigator(
        workflow: widget.workflow,
        diagnosticsByNodeId: widget.diagnosticsByNodeId,
        executionFocus: widget.executionFocus,
        selectedNodeId: widget.selectedNodeId,
        selectedNodeIds: widget.selectedNodeIds,
        expanded: _nodeNavigatorExpanded,
        searchController: _nodeSearchController,
        searchQuery: _nodeSearchQuery,
        onToggleExpanded: () => _updateWorkflowCanvasState(
          () => _nodeNavigatorExpanded = !_nodeNavigatorExpanded,
        ),
        onSearchChanged: (value) =>
            _updateWorkflowCanvasState(() => _nodeSearchQuery = value),
        onClearSearch: () {
          _nodeSearchController.clear();
          _updateWorkflowCanvasState(() => _nodeSearchQuery = '');
        },
        onFocusNode: (nodeId) => _focusNodesOnCanvas(
          nodeId,
          layout: layout,
          viewportSize: viewportSize,
        ),
      ),
    );
  }

  /// 构建小地图。
  /// 小地图导航只改变视口，不写入 Project DSL。
  Widget _buildMiniMap(_WorkflowCanvasLayout layout, Size viewportSize) {
    return Positioned(
      right: 12,
      bottom: 12,
      child: _WorkflowMiniMap(
        key: const ValueKey('workflow-mini-map'),
        workflow: widget.workflow,
        positions: layout.positions,
        canvasSize: layout.size,
        viewportRect: _visibleCanvasRect(viewportSize),
        executionFocus: widget.executionFocus,
        selectedNodeId: widget.selectedNodeId,
        selectedNodeIds: widget.selectedNodeIds,
        onNavigate: (canvasPoint) => _centerCanvasOn(
          canvasPoint,
          viewportSize: viewportSize,
          canvasSize: layout.size,
        ),
      ),
    );
  }

  /// 构建右上角画布控制条。
  /// 控制条只转发缩放、适配、框选和自动整理入口。
  Widget _buildCanvasControls(Size viewportSize, _WorkflowCanvasLayout layout) {
    return Positioned(
      right: 12,
      top: 12,
      child: _WorkflowCanvasControls(
        scale: _scale,
        onZoomOut: () => _setScale(_scale - 0.1),
        onZoomIn: () => _setScale(_scale + 0.1),
        onReset: _resetView,
        onFit: () => _fitView(viewportSize, layout.size),
        selectionMode: _boxSelectMode,
        onToggleSelection: widget.locked ? null : _toggleBoxSelectMode,
        onAutoLayout: widget.locked ? null : _autoLayoutCanvas,
      ),
    );
  }
}

// Workflow 画布框选矩形，负责展示当前框选范围。
class _WorkflowCanvasSelectionRect extends StatelessWidget {
  const _WorkflowCanvasSelectionRect({required this.selectionRect});

  final Rect selectionRect;

  /// 渲染框选矩形。
  /// 该组件忽略指针事件，避免遮挡底层框选监听。
  @override
  Widget build(BuildContext context) {
    return Positioned.fromRect(
      rect: selectionRect,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: StudioColors.cyan.withValues(alpha: 0.10),
            border: Border.all(
              color: StudioColors.cyan.withValues(alpha: 0.68),
            ),
          ),
        ),
      ),
    );
  }
}
