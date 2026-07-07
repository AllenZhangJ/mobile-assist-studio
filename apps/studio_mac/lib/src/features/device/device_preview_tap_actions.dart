part of '../../studio_mac_workspace.dart';

// 设备预览点击动作，负责单击、双击和长按的坐标换算与发送。
extension _DevicePreviewTapActions on _DevicePreviewState {
  // 处理单击预览，换算为归一化坐标后交给 Runtime 点击。
  Future<void> _handlePreviewTap(
    TapUpDetails details,
    Size containerSize,
  ) async {
    _focusPreviewKeyboard();
    final ratio = _ratioForPreviewTap(details.localPosition, containerSize);
    if (ratio == null) return;
    _setInteraction(_interaction.beginTap(ratio));
    await widget.controller.tapViewportFraction(
      xRatio: ratio.dx,
      yRatio: ratio.dy,
    );
    if (!mounted) return;
    _setInteraction(_interaction.finishTap());
  }

  // 处理双击预览，复用同一坐标换算规则发送 double tap。
  Future<void> _handlePreviewDoubleTap(
    TapDownDetails details,
    Size containerSize,
  ) async {
    _focusPreviewKeyboard();
    final ratio = _ratioForPreviewTap(details.localPosition, containerSize);
    if (ratio == null) return;
    _setInteraction(_interaction.beginDoubleTap(ratio));
    await widget.controller.doubleTapViewportFraction(
      xRatio: ratio.dx,
      yRatio: ratio.dy,
    );
    if (!mounted) return;
    _setInteraction(_interaction.finishDoubleTap());
  }

  // 处理长按预览，沿用点击坐标并发送 long press。
  Future<void> _handlePreviewLongPress(
    LongPressStartDetails details,
    Size containerSize,
  ) async {
    _focusPreviewKeyboard();
    final ratio = _ratioForPreviewTap(details.localPosition, containerSize);
    if (ratio == null) return;
    _setInteraction(_interaction.beginLongPress(ratio));
    await widget.controller.longPressViewportFraction(
      xRatio: ratio.dx,
      yRatio: ratio.dy,
    );
    if (!mounted) return;
    _setInteraction(_interaction.finishLongPress());
  }
}
