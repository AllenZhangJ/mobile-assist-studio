part of '../../studio_mac_workspace.dart';

// 设备预览命令动作，负责主页键、输入和手机双指缩放。
extension _DevicePreviewDeviceCommands on _DevicePreviewState {
  // 发送受控主页键，动作期间锁定其它预览输入。
  Future<void> _sendHomeButton() async {
    if (_interaction.homeButtonSending) return;
    _setInteraction(_interaction.beginHomeButton());
    await widget.controller.pressHomeButton();
    if (!mounted) return;
    _setInteraction(_interaction.finishHomeButton());
  }

  // 向当前手机焦点发送文本，Runtime 只记录长度不保存明文。
  Future<void> _sendFocusedInput() async {
    final text = _inputController.text;
    if (text.trim().isEmpty || _interaction.inputSending) return;
    _setInteraction(_interaction.copyWith(inputSending: true));
    final sent = await widget.controller.inputFocusedText(text: text);
    if (!mounted) return;
    if (sent) _inputController.clear();
    _setInteraction(_interaction.copyWith(inputSending: false));
  }

  // 发送手机放大手势，和本地显示缩放保持分离。
  Future<void> _sendDevicePinchOut() async {
    await _sendDevicePinch(expand: true);
  }

  // 发送手机缩小手势，和本地显示缩放保持分离。
  Future<void> _sendDevicePinchIn() async {
    await _sendDevicePinch(expand: false);
  }

  // 发送受控双指缩放，动作期间锁定其它预览输入。
  Future<void> _sendDevicePinch({required bool expand}) async {
    if (!_interaction.canGesture(
      widget.snapshot,
      hasScreenshot: widget.snapshot.latestScreenshotBase64 != null,
    )) {
      return;
    }
    _focusPreviewKeyboard();
    _setInteraction(_interaction.beginPinch());
    await widget.controller.pinchViewport(expand: expand);
    if (!mounted) return;
    _setInteraction(_interaction.finishPinch());
  }
}
