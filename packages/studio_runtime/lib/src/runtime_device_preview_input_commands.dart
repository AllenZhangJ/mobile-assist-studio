part of '../studio_runtime.dart';

// Runtime 设备预览输入命令，负责当前焦点文本和受控主页键。
extension StudioRuntimeDevicePreviewInputCommands on StudioRuntimeController {
  // 向当前焦点输入文字，用于 Device 预览的手动输入。
  // 不记录明文内容，只在事件里提示输入长度和结果。
  Future<bool> inputFocusedText({
    required String text,
    String label = '预览输入',
  }) async {
    final normalized = text.trim();
    final session = _requireIdleConnectedSession('输入');
    if (session == null) return false;
    if (normalized.isEmpty) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '请输入内容。')));
      return false;
    }

    try {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '发送输入。')));
      await _deviceActions.inputText(
        session.id,
        RuntimeInput(text: normalized, label: label),
      );
      _emit(
        _snapshot.copyWith(
          events: _appendEvent('info', '输入完成：${normalized.length} 字。'),
        ),
      );
      return true;
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '预览输入失败：$error')));
      return false;
    }
  }

  // 发送受控硬件 Home 键，用于从当前 App 回到主屏。
  // 该入口仍遵守 connected + idle 边界，不开放任意设备按钮或脚本。
  Future<bool> pressHomeButton() async {
    final session = _requireIdleConnectedSession('回主页');
    if (session == null) return false;

    try {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '发送主页键。')));
      await _deviceActions.pressButton(session.id, RuntimeDeviceButton.home);
      _emit(_snapshot.copyWith(events: _appendEvent('info', '已回主页。')));
      return true;
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '主页键失败：$error')));
      return false;
    }
  }
}
