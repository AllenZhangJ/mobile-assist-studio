part of '../studio_runtime.dart';

// Runtime 设备预览截图命令，负责 connected + idle 边界和截图状态写入。
extension StudioRuntimeDevicePreviewCaptureCommands on StudioRuntimeController {
  // 手动采集当前设备截图。
  Future<String?> captureScreenshot({String reason = 'manual'}) async {
    if (_snapshot.connectionStatus != ConnectionStatus.connected) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '请先连接设备再截图。')));
      return null;
    }
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能手动截图。')));
      return null;
    }
    final session = _sessionManager.session;
    if (session == null) {
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.error,
          events: _appendEvent('error', '设备已连但会话缺失。'),
        ),
      );
      return null;
    }
    try {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '正在截图：$reason。')));
      final screenshot = await _deviceActions.screenshot(session.id);
      _emit(
        _snapshot.copyWith(
          latestScreenshotBase64: screenshot,
          latestScreenshotAt: DateTime.now(),
          events: _appendEvent('info', '截图完成。'),
        ),
      );
      return screenshot;
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '截图失败：$error')));
      return null;
    }
  }
}
