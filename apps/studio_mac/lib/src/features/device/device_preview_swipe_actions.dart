part of '../../studio_mac_workspace.dart';

// 设备预览滑动动作，负责滚轮、拖动和 Runtime swipe 发送。
extension _DevicePreviewSwipeActions on _DevicePreviewState {
  // 鼠标滚轮转成竖向 swipe，不改变预览缩放和 DSL。
  void _handlePreviewScroll(PointerSignalEvent event, Size containerSize) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy.abs() < 1) {
      return;
    }
    _focusPreviewKeyboard();
    final pointerRatio =
        _ratioForPreviewPosition(
          localPosition: event.localPosition,
          containerSize: containerSize,
          clampToContent: true,
        ) ??
        const Offset(0.5, 0.5);
    final xRatio = pointerRatio.dx.clamp(0.15, 0.85).toDouble();
    final direction = event.scrollDelta.dy > 0 ? 1.0 : -1.0;
    final from = Offset(xRatio, direction > 0 ? 0.68 : 0.32);
    final to = Offset(xRatio, direction > 0 ? 0.32 : 0.68);
    unawaited(
      _sendPreviewSwipe(from: from, to: to, label: '预览滚动', durationMs: 260),
    );
  }

  // 拖动开始时记录起点，只有点在截图内容内才进入拖动状态。
  void _handlePreviewPanStart(DragStartDetails details, Size containerSize) {
    _focusPreviewKeyboard();
    final ratio = _ratioForPreviewPosition(
      localPosition: details.localPosition,
      containerSize: containerSize,
      clampToContent: false,
    );
    if (ratio == null) return;
    _setInteraction(_interaction.beginDrag(ratio));
  }

  // 拖动过程中更新终点，超出截图时会夹紧到内容边界。
  void _handlePreviewPanUpdate(DragUpdateDetails details, Size containerSize) {
    if (_interaction.dragStartRatio == null) return;
    final ratio = _ratioForPreviewPosition(
      localPosition: details.localPosition,
      containerSize: containerSize,
      clampToContent: true,
    );
    if (ratio == null) return;
    _setInteraction(_interaction.updateDrag(ratio));
  }

  // 拖动结束后发送 swipe，距离太短时视为无效手势。
  void _handlePreviewPanEnd(DragEndDetails details) {
    final from = _interaction.dragStartRatio;
    final to = _interaction.dragEndRatio;
    if (from == null || to == null) {
      _setInteraction(_interaction.finishDrag());
      return;
    }
    _setInteraction(_interaction.finishDrag());
    if ((to - from).distance < 0.04) return;
    unawaited(_sendPreviewSwipe(from: from, to: to));
  }

  // 发送归一化 swipe，并同步显示最近一次滑动轨迹。
  Future<void> _sendPreviewSwipe({
    required Offset from,
    required Offset to,
    String label = '预览滑动',
    int durationMs = 450,
  }) async {
    _setInteraction(_interaction.beginSwipe(from: from, to: to));
    await widget.controller.swipeViewportFractions(
      fromXRatio: from.dx,
      fromYRatio: from.dy,
      toXRatio: to.dx,
      toYRatio: to.dy,
      label: label,
      durationMs: durationMs,
    );
    if (!mounted) return;
    _setInteraction(_interaction.finishSwipe());
  }
}
