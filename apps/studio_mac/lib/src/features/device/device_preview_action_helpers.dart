part of '../../studio_mac_workspace.dart';

// 设备预览动作 helper，负责坐标换算、缩放写入和键盘焦点。
extension _DevicePreviewActionHelpers on _DevicePreviewState {
  // 将一次点击类手势换算为预览内归一化坐标。
  Offset? _ratioForPreviewTap(Offset localPosition, Size containerSize) {
    return _ratioForPreviewPosition(
      localPosition: localPosition,
      containerSize: containerSize,
      clampToContent: false,
    );
  }

  // 将预览局部坐标转换为 0 到 1 的屏幕比例坐标。
  Offset? _ratioForPreviewPosition({
    required Offset localPosition,
    required Size containerSize,
    required bool clampToContent,
  }) {
    return _devicePreviewRatioForPosition(
      localPosition: localPosition,
      containerSize: containerSize,
      screenshotSize: _interaction.screenshotSize,
      scale: _interaction.previewScale,
      clampToContent: clampToContent,
    );
  }

  // 更新预览缩放，限制在可控范围内避免截图跑出视图太远。
  void _setPreviewScale(double value) {
    final next = _interaction.withPreviewScale(value);
    if (next.previewScale == _interaction.previewScale) return;
    _setInteraction(next);
  }

  // 让预览区重新获得键盘焦点，避免点击后方向键不再作用于手机。
  void _focusPreviewKeyboard() {
    if (!_keyboardFocusNode.hasFocus) _keyboardFocusNode.requestFocus();
  }
}
