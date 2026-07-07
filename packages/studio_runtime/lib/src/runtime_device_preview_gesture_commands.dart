part of '../studio_runtime.dart';

// Runtime 设备预览手势命令，负责 swipe 和 pinch。
extension StudioRuntimeDevicePreviewGestureCommands on StudioRuntimeController {
  // 发送预览滑动。
  Future<bool> swipeViewportFractions({
    required double fromXRatio,
    required double fromYRatio,
    required double toXRatio,
    required double toYRatio,
    String label = '预览滑动',
    int durationMs = 450,
  }) async {
    final session = _requireIdleConnectedSession('滑动预览');
    if (session == null) return false;
    if (!_validatePreviewDuration(
      durationMs: durationMs,
      warningMessage: '滑动时长不能为负数。',
    )) {
      return false;
    }
    if (!_validateViewportSwipe(
      fromXRatio: fromXRatio,
      fromYRatio: fromYRatio,
      toXRatio: toXRatio,
      toYRatio: toYRatio,
    )) {
      return false;
    }

    try {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '发送滑动。')));
      final viewport = await _deviceActions.viewportSize(session.id);
      final from = _pointForViewportRatio(
        viewport,
        xRatio: fromXRatio,
        yRatio: fromYRatio,
      );
      final to = _pointForViewportRatio(
        viewport,
        xRatio: toXRatio,
        yRatio: toYRatio,
      );
      await _deviceActions.swipe(
        session.id,
        RuntimeSwipe(from: from, to: to, label: label, durationMs: durationMs),
      );
      return true;
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '预览滑动失败：$error')));
      return false;
    } finally {
      await _releasePreviewActions(session.id, actionName: '滑动');
    }
  }

  // 发送预览双指缩放。
  // expand 为 true 时模拟放大，false 时模拟缩小。
  Future<bool> pinchViewport({
    required bool expand,
    String? label,
    int durationMs = 420,
  }) async {
    final actionName = expand ? '放大' : '缩小';
    final session = _requireIdleConnectedSession('$actionName预览');
    if (session == null) return false;
    if (!_validatePreviewDuration(
      durationMs: durationMs,
      warningMessage: '缩放时长不能为负数。',
    )) {
      return false;
    }

    try {
      _emit(
        _snapshot.copyWith(events: _appendEvent('info', '发送$actionName手势。')),
      );
      final viewport = await _deviceActions.viewportSize(session.id);
      await _deviceActions.pinch(
        session.id,
        _pinchForPreviewViewport(
          viewport,
          expand: expand,
          label: label ?? '预览$actionName',
          durationMs: durationMs,
        ),
      );
      return true;
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(
          events: _appendEvent('error', '预览$actionName失败：$error'),
        ),
      );
      return false;
    } finally {
      await _releasePreviewActions(session.id, actionName: actionName);
    }
  }
}
