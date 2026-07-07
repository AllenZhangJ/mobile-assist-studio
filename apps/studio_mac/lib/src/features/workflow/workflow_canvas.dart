part of '../../studio_mac_workspace.dart';

// Workflow 画布主体，负责节点列表布局、拖拽选择、缩放和平移状态。
class _WorkflowVisualList extends StatefulWidget {
  const _WorkflowVisualList({
    required this.workflow,
    required this.diagnosticsByNodeId,
    required this.executionFocus,
    required this.selectedNodeId,
    required this.selectedNodeIds,
    required this.selectedEdge,
    required this.locked,
    required this.lockReason,
    required this.viewportCommand,
    required this.onSelectNode,
    required this.onSelectNodes,
    required this.onSelectEdge,
    required this.onInsertNodesOnEdge,
    required this.onRetargetSelectedEdgeSource,
    required this.onRetargetSelectedEdge,
    required this.onMoveNode,
    required this.onMoveNodes,
    required this.onConnectNodes,
    required this.onRemoveEdge,
    required this.onAutoLayout,
  });

  final WorkflowDefinition workflow;
  final Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId;
  final RuntimeExecutionFocus executionFocus;
  final String? selectedNodeId;
  final Set<String> selectedNodeIds;
  final _WorkflowSelectedEdge? selectedEdge;
  final bool locked;
  final String? lockReason;
  final ValueNotifier<_WorkflowCanvasViewportCommand?> viewportCommand;
  final ValueChanged<WorkflowNode> onSelectNode;
  final ValueChanged<Set<String>> onSelectNodes;
  final ValueChanged<_WorkflowSelectedEdge?> onSelectEdge;
  final ValueChanged<WorkflowNodeType> onInsertNodesOnEdge;
  final ValueChanged<String> onRetargetSelectedEdgeSource;
  final ValueChanged<String> onRetargetSelectedEdge;
  final void Function(WorkflowNode node, Offset position) onMoveNode;
  final ValueChanged<Map<String, Offset>> onMoveNodes;
  final void Function(String fromNodeId, String toNodeId) onConnectNodes;
  final ValueChanged<_WorkflowSelectedEdge> onRemoveEdge;
  final VoidCallback onAutoLayout;

  @override
  State<_WorkflowVisualList> createState() => _WorkflowVisualListState();
}

// Workflow 画布状态，生命周期留在主文件，具体动作拆到同目录分片。
class _WorkflowVisualListState extends State<_WorkflowVisualList> {
  final GlobalKey _canvasStackKey = GlobalKey();
  final TransformationController _transformationController =
      TransformationController();
  late final TextEditingController _nodeSearchController;
  final Map<String, Offset> _dragPositions = <String, Offset>{};
  String? _connectingFromNodesId;
  Offset? _connectionPreviewStart;
  Offset? _connectionPreviewEnd;
  bool _boxSelectMode = false;
  Offset? _selectionStart;
  Rect? _selectionRect;
  bool _nodeNavigatorExpanded = false;
  String _nodeSearchQuery = '';
  double _scale = 1;
  Size _latestViewportSize = Size.zero;
  Size _latestCanvasSize = Size.zero;

  // 初始化画布控制器，并同步手势缩放后的比例。
  @override
  void initState() {
    super.initState();
    _nodeSearchController = TextEditingController();
    _transformationController.addListener(_syncScaleFromTransform);
    widget.viewportCommand.addListener(_handleViewportCommand);
  }

  // 更新视口命令监听，避免 Widget 重建后继续监听旧通道。
  @override
  void didUpdateWidget(covariant _WorkflowVisualList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportCommand != widget.viewportCommand) {
      oldWidget.viewportCommand.removeListener(_handleViewportCommand);
      widget.viewportCommand.addListener(_handleViewportCommand);
    }
  }

  // 释放画布搜索、缩放和平移控制器，避免页面切换后残留监听。
  @override
  void dispose() {
    widget.viewportCommand.removeListener(_handleViewportCommand);
    _transformationController.removeListener(_syncScaleFromTransform);
    _transformationController.dispose();
    _nodeSearchController.dispose();
    super.dispose();
  }

  // 为画布动作分片提供受控状态更新入口，避免扩展直接调用 protected setState。
  void _updateWorkflowCanvasState(VoidCallback update) => setState(update);

  // 渲染完整画布视图，并把交互入口转交给已拆分的动作分片。
  @override
  Widget build(BuildContext context) {
    final layout = _WorkflowCanvasLayout.fromWorkflow(
      widget.workflow,
      overrides: _dragPositions,
    );
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportSize = Size(
            constraints.maxWidth,
            constraints.maxHeight,
          );
          _latestViewportSize = viewportSize;
          _latestCanvasSize = layout.size;
          return Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: widget.locked
                    ? null
                    : (details) =>
                          _selectEdgeAt(details.globalPosition, layout),
                child: InteractiveViewer(
                  key: const ValueKey('workflow-visual-canvas'),
                  transformationController: _transformationController,
                  boundaryMargin: const EdgeInsets.all(260),
                  minScale: 0.5,
                  maxScale: 1.6,
                  panEnabled: !_boxSelectMode,
                  scaleEnabled: !_boxSelectMode,
                  constrained: false,
                  child: SizedBox(
                    key: const ValueKey('workflow-visual-list'),
                    width: layout.size.width,
                    height: layout.size.height,
                    child: Stack(
                      key: _canvasStackKey,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _WorkflowCanvasPainter(
                              workflow: widget.workflow,
                              positions: layout.positions,
                              executionFocus: widget.executionFocus,
                              selectedEdge: widget.selectedEdge,
                              connectionPreviewStart: _connectionPreviewStart,
                              connectionPreviewEnd: _connectionPreviewEnd,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: GestureDetector(
                            key: const ValueKey('workflow-edge-hit-layer'),
                            behavior: HitTestBehavior.translucent,
                            onTapDown: widget.locked
                                ? null
                                : (details) => _selectEdgeAt(
                                    details.globalPosition,
                                    layout,
                                  ),
                          ),
                        ),
                        if (_connectingFromNodesId case final sourceNodesId?)
                          Positioned(
                            left: 14,
                            top: 14,
                            child: _WorkflowConnectionBanner(
                              workflow: widget.workflow,
                              sourceNodesId: sourceNodesId,
                              onCancel: _cancelConnection,
                            ),
                          ),
                        ..._buildWorkflowCanvasNodeLayers(layout),
                        if (widget.selectedEdge case final selectedEdge?)
                          Positioned(
                            left: (selectedEdge.anchor.dx - 150).clamp(
                              8.0,
                              math.max(8.0, layout.size.width - 360),
                            ),
                            top: (selectedEdge.anchor.dy - 44).clamp(
                              8.0,
                              math.max(8.0, layout.size.height - 72),
                            ),
                            child: _WorkflowSelectedEdgeToolbar(
                              workflow: widget.workflow,
                              edge: selectedEdge,
                              locked: widget.locked,
                              onInsertNodes: widget.onInsertNodesOnEdge,
                              onRetargetSource:
                                  widget.onRetargetSelectedEdgeSource,
                              onRetarget: widget.onRetargetSelectedEdge,
                              onDelete: _deleteSelectedEdge,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ..._buildWorkflowCanvasChrome(layout, viewportSize),
            ],
          );
        },
      ),
    );
  }
}
