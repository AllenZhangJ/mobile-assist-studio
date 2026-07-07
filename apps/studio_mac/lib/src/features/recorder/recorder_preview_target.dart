part of '../../studio_mac_workspace.dart';

// 录制预览点选区域，负责把点击和拖动换算为比例坐标。
class _RecorderPreviewTapTarget extends StatefulWidget {
  const _RecorderPreviewTapTarget({
    required this.contentRect,
    required this.screenshot,
    required this.canPick,
    required this.onPickTap,
    required this.onPickSwipe,
  });

  final Rect contentRect;
  final Uint8List? screenshot;
  final bool canPick;
  final ValueChanged<Offset>? onPickTap;
  final void Function(Offset fromRatio, Offset toRatio)? onPickSwipe;

  // 创建预览目标状态，只保存拖动中的临时轨迹。
  @override
  State<_RecorderPreviewTapTarget> createState() =>
      _RecorderPreviewTapTargetState();
}

// 录制预览交互状态，负责本地拖动轨迹和回调分派。
class _RecorderPreviewTapTargetState extends State<_RecorderPreviewTapTarget> {
  Offset? _dragStartRatio;
  Offset? _dragEndRatio;

  // 渲染手机截图或空态，并在可录制时捕获比例坐标。
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('recorder-preview-pick-target'),
      behavior: HitTestBehavior.opaque,
      onTapUp: widget.canPick ? _handleTapUp : null,
      onPanStart: widget.canPick ? _handlePanStart : null,
      onPanUpdate: widget.canPick ? _handlePanUpdate : null,
      onPanEnd: widget.canPick ? _handlePanEnd : null,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF05080C),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: StudioColors.cyan.withValues(alpha: 0.32),
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.screenshot == null
                ? const _RecorderPreviewEmpty()
                : Positioned.fromRect(
                    rect: widget.contentRect,
                    child: Image.memory(
                      widget.screenshot!,
                      fit: BoxFit.fill,
                      gaplessPlayback: true,
                    ),
                  ),
            if (_dragStartRatio != null && _dragEndRatio != null)
              _PreviewSwipeLine(
                fromRatio: _dragStartRatio!,
                toRatio: _dragEndRatio!,
                contentRect: widget.contentRect,
                sending: false,
              ),
          ],
        ),
      ),
    );
  }

  // 只在点选落入预览区域时回传比例坐标，避免写入无效动作。
  void _handleTapUp(TapUpDetails details) {
    final ratio = _ratioForPosition(
      details.localPosition,
      clampToContent: false,
    );
    if (ratio == null || widget.onPickTap == null) return;
    widget.onPickTap!(ratio);
  }

  // 开始记录拖动起点，只有落在预览内才进入滑动捕获。
  void _handlePanStart(DragStartDetails details) {
    final ratio = _ratioForPosition(
      details.localPosition,
      clampToContent: false,
    );
    if (ratio == null) return;
    setState(() {
      _dragStartRatio = ratio;
      _dragEndRatio = ratio;
    });
  }

  // 更新拖动终点，拖出预览时夹紧到边界。
  void _handlePanUpdate(DragUpdateDetails details) {
    if (_dragStartRatio == null) return;
    final ratio = _ratioForPosition(
      details.localPosition,
      clampToContent: true,
    );
    if (ratio == null) return;
    setState(() => _dragEndRatio = ratio);
  }

  // 完成滑动捕获，距离太短时丢弃并不生成动作。
  void _handlePanEnd(DragEndDetails details) {
    final from = _dragStartRatio;
    final to = _dragEndRatio;
    setState(() {
      _dragStartRatio = null;
      _dragEndRatio = null;
    });
    if (from == null || to == null || widget.onPickSwipe == null) return;
    if ((to - from).distance < 0.04) return;
    widget.onPickSwipe!(from, to);
  }

  // 将预览局部位置转换为比例坐标，必要时允许夹紧。
  Offset? _ratioForPosition(
    Offset localPosition, {
    required bool clampToContent,
  }) {
    final contentRect = widget.contentRect;
    if (!contentRect.contains(localPosition) && !clampToContent) return null;
    final dx = ((localPosition.dx - contentRect.left) / contentRect.width)
        .clamp(0.0, 1.0)
        .toDouble();
    final dy = ((localPosition.dy - contentRect.top) / contentRect.height)
        .clamp(0.0, 1.0)
        .toDouble();
    return Offset(dx, dy);
  }
}
