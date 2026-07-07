part of '../../studio_mac_workspace.dart';

// Workflow Mini Map 与端口组件，负责小地图渲染、端口命中和导航定位。
class _WorkflowCanvasPort extends StatelessWidget {
  const _WorkflowCanvasPort({
    super.key,
    required this.position,
    required this.tone,
    required this.tooltip,
    required this.onPressed,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  static const size = 22.0;

  final Offset position;
  final StudioStatusTone tone;
  final String tooltip;
  final VoidCallback? onPressed;
  final ValueChanged<Offset>? onDragStart;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  // 渲染圆形端口按钮，并把点击或拖拽事件交给画布状态层。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      width: size,
      height: size,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          onPanStart: onDragStart == null
              ? null
              : (details) => onDragStart!(details.globalPosition),
          onPanUpdate: onDragUpdate == null
              ? null
              : (details) => onDragUpdate!(details.globalPosition),
          onPanEnd: onDragEnd == null ? null : (_) => onDragEnd!(),
          onPanCancel: onDragEnd,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: onPressed == null
                  ? StudioColors.panel
                  : color.withValues(alpha: 0.20),
              border: Border.all(
                color: onPressed == null
                    ? StudioColors.border
                    : color.withValues(alpha: 0.72),
              ),
              shape: BoxShape.circle,
              boxShadow: [
                if (onPressed != null)
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 12,
                  ),
              ],
            ),
            child: Center(
              child: Icon(
                Icons.circle,
                size: 7,
                color: onPressed == null ? StudioColors.muted : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowMiniMap extends StatelessWidget {
  const _WorkflowMiniMap({
    super.key,
    required this.workflow,
    required this.positions,
    required this.canvasSize,
    required this.viewportRect,
    required this.executionFocus,
    required this.selectedNodeId,
    required this.selectedNodeIds,
    required this.onNavigate,
  });

  final WorkflowDefinition workflow;
  final Map<String, Offset> positions;
  final Size canvasSize;
  final Rect viewportRect;
  final RuntimeExecutionFocus executionFocus;
  final String? selectedNodeId;
  final Set<String> selectedNodeIds;
  final ValueChanged<Offset> onNavigate;

  // 渲染小地图外壳和交互层，点击或拖拽会定位主画布。
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '流程小图',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StudioColors.panel.withValues(alpha: 0.88),
          border: Border.all(color: StudioColors.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SizedBox(
          width: 184,
          height: 124,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '地图',
                  style: TextStyle(
                    color: StudioColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final paintSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      return GestureDetector(
                        key: const ValueKey('workflow-mini-map-canvas'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _navigateFromMiniMapPosition(
                          details.localPosition,
                          paintSize,
                        ),
                        onPanStart: (details) => _navigateFromMiniMapPosition(
                          details.localPosition,
                          paintSize,
                        ),
                        onPanUpdate: (details) => _navigateFromMiniMapPosition(
                          details.localPosition,
                          paintSize,
                        ),
                        child: CustomPaint(
                          painter: _WorkflowMiniMapPainter(
                            workflow: workflow,
                            positions: positions,
                            canvasSize: canvasSize,
                            viewportRect: viewportRect,
                            executionFocus: executionFocus,
                            selectedNodeId: selectedNodeId,
                            selectedNodeIds: selectedNodeIds,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 根据小地图局部坐标触发画布导航。
  void _navigateFromMiniMapPosition(Offset localPosition, Size paintSize) {
    final canvasPoint = _canvasPointForMiniMapPosition(
      localPosition,
      paintSize,
    );
    if (canvasPoint != null) onNavigate(canvasPoint);
  }

  // 将小地图坐标换算成真实画布坐标，超出绘制区域时返回空。
  Offset? _canvasPointForMiniMapPosition(Offset localPosition, Size paintSize) {
    if (canvasSize.width <= 0 ||
        canvasSize.height <= 0 ||
        paintSize.width <= 0 ||
        paintSize.height <= 0) {
      return null;
    }
    final scale = math.min(
      paintSize.width / canvasSize.width,
      paintSize.height / canvasSize.height,
    );
    if (scale <= 0) return null;
    final mapSize = Size(canvasSize.width * scale, canvasSize.height * scale);
    final origin = Offset(
      (paintSize.width - mapSize.width) / 2,
      (paintSize.height - mapSize.height) / 2,
    );
    final mapRect = origin & mapSize;
    if (!mapRect.contains(localPosition)) return null;
    return Offset(
      ((localPosition.dx - origin.dx) / scale)
          .clamp(0, canvasSize.width)
          .toDouble(),
      ((localPosition.dy - origin.dy) / scale)
          .clamp(0, canvasSize.height)
          .toDouble(),
    );
  }
}
