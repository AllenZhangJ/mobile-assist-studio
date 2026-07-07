part of '../studio_runtime.dart';

// Runtime 设备预览 helper，集中维护预览动作共用的会话、坐标和释放规则。

extension StudioRuntimeDevicePreviewHelpers on StudioRuntimeController {
  /// 确保当前存在可用设备会话。
  /// 校验失败会写入用户可懂事件，避免每个预览动作重复判断状态。
  WebDriverSession? _requireIdleConnectedSession(String actionName) {
    if (_snapshot.connectionStatus != ConnectionStatus.connected) {
      _emit(
        _snapshot.copyWith(
          events: _appendEvent('warning', '请先连接设备再$actionName。'),
        ),
      );
      return null;
    }
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(
        _snapshot.copyWith(
          events: _appendEvent('warning', '运行中不能$actionName。'),
        ),
      );
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
    return session;
  }

  /// 校验预览归一化坐标。
  /// label 使用短中文动作名，用于生成友好的错误提示。
  bool _validateViewportPoint({
    required double xRatio,
    required double yRatio,
    required String label,
  }) {
    if (_validViewportRatio(xRatio) && _validViewportRatio(yRatio)) {
      return true;
    }
    _emit(
      _snapshot.copyWith(events: _appendEvent('warning', '$label位置需在画面内。')),
    );
    return false;
  }

  /// 校验预览滑动的起点和终点。
  /// 所有坐标都必须是 0 到 1 的视口比例。
  bool _validateViewportSwipe({
    required double fromXRatio,
    required double fromYRatio,
    required double toXRatio,
    required double toYRatio,
  }) {
    if (_validViewportRatio(fromXRatio) &&
        _validViewportRatio(fromYRatio) &&
        _validViewportRatio(toXRatio) &&
        _validViewportRatio(toYRatio)) {
      return true;
    }
    _emit(_snapshot.copyWith(events: _appendEvent('warning', '滑动位置需在画面内。')));
    return false;
  }

  /// 校验预览动作时长。
  /// 负数时长会被拒绝，避免生成无效 W3C action。
  bool _validatePreviewDuration({
    required int durationMs,
    required String warningMessage,
  }) {
    if (durationMs >= 0) return true;
    _emit(_snapshot.copyWith(events: _appendEvent('warning', warningMessage)));
    return false;
  }

  /// 根据当前 viewport 构建受控双指缩放动作。
  /// expand 为 true 表示放大，false 表示缩小。
  RuntimePinch _pinchForPreviewViewport(
    ViewportSize viewport, {
    required bool expand,
    required String label,
    required int durationMs,
  }) {
    final firstFromRatio = expand ? (x: 0.44, y: 0.5) : (x: 0.24, y: 0.5);
    final firstToRatio = expand ? (x: 0.24, y: 0.5) : (x: 0.44, y: 0.5);
    final secondFromRatio = expand ? (x: 0.56, y: 0.5) : (x: 0.76, y: 0.5);
    final secondToRatio = expand ? (x: 0.76, y: 0.5) : (x: 0.56, y: 0.5);
    return RuntimePinch(
      firstFrom: _pointForViewportRatio(
        viewport,
        xRatio: firstFromRatio.x,
        yRatio: firstFromRatio.y,
      ),
      firstTo: _pointForViewportRatio(
        viewport,
        xRatio: firstToRatio.x,
        yRatio: firstToRatio.y,
      ),
      secondFrom: _pointForViewportRatio(
        viewport,
        xRatio: secondFromRatio.x,
        yRatio: secondFromRatio.y,
      ),
      secondTo: _pointForViewportRatio(
        viewport,
        xRatio: secondToRatio.x,
        yRatio: secondToRatio.y,
      ),
      label: label,
      durationMs: durationMs,
    );
  }

  /// 尽力释放预览手势 actions。
  /// 释放失败只记录提醒，不覆盖原动作的成功或失败事件。
  Future<void> _releasePreviewActions(
    String sessionId, {
    required String actionName,
  }) async {
    try {
      await _deviceActions.releaseActions(sessionId);
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(
          events: _appendEvent('warning', '$actionName释放失败：$error'),
        ),
      );
    }
  }
}
