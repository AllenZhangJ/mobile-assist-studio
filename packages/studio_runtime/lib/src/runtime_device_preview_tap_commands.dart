part of '../studio_runtime.dart';

// Runtime 设备预览点击命令，负责 tap、double tap 和 long press。
extension StudioRuntimeDevicePreviewTapCommands on StudioRuntimeController {
  // 发送预览点击。
  Future<bool> tapViewportFraction({
    required double xRatio,
    required double yRatio,
    String label = '预览点击',
    int? tapDurationMs,
  }) async {
    final session = _requireIdleConnectedSession('点击预览');
    if (session == null) return false;
    if (!_validateViewportPoint(xRatio: xRatio, yRatio: yRatio, label: '点击')) {
      return false;
    }

    final durationMs = tapDurationMs ?? defaultTapDurationMs;
    try {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '发送点击。')));
      final viewport = await _deviceActions.viewportSize(session.id);
      final point = _pointForViewportRatio(
        viewport,
        xRatio: xRatio,
        yRatio: yRatio,
      );
      await _deviceActions.tap(
        session.id,
        RuntimeTap(point: point, label: label, durationMs: durationMs),
      );
      return true;
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '预览点击失败：$error')));
      return false;
    } finally {
      await _releasePreviewActions(session.id, actionName: '点击');
    }
  }

  // 发送预览双击。
  Future<bool> doubleTapViewportFraction({
    required double xRatio,
    required double yRatio,
    String label = '预览双击',
    int? tapDurationMs,
  }) async {
    final session = _requireIdleConnectedSession('双击预览');
    if (session == null) return false;
    if (!_validateViewportPoint(xRatio: xRatio, yRatio: yRatio, label: '双击')) {
      return false;
    }

    final durationMs = tapDurationMs ?? defaultTapDurationMs;
    try {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '发送双击。')));
      final viewport = await _deviceActions.viewportSize(session.id);
      final point = _pointForViewportRatio(
        viewport,
        xRatio: xRatio,
        yRatio: yRatio,
      );
      for (var index = 0; index < 2; index += 1) {
        await _deviceActions.tap(
          session.id,
          RuntimeTap(point: point, label: label, durationMs: durationMs),
        );
      }
      return true;
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '预览双击失败：$error')));
      return false;
    } finally {
      await _releasePreviewActions(session.id, actionName: '双击');
    }
  }

  // 发送预览长按。
  Future<bool> longPressViewportFraction({
    required double xRatio,
    required double yRatio,
    String label = '预览长按',
    int pressDurationMs = 650,
  }) async {
    final session = _requireIdleConnectedSession('长按预览');
    if (session == null) return false;
    if (!_validatePreviewDuration(
      durationMs: pressDurationMs,
      warningMessage: '长按时长不能为负数。',
    )) {
      return false;
    }
    if (!_validateViewportPoint(xRatio: xRatio, yRatio: yRatio, label: '长按')) {
      return false;
    }

    try {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '发送长按。')));
      final viewport = await _deviceActions.viewportSize(session.id);
      final point = _pointForViewportRatio(
        viewport,
        xRatio: xRatio,
        yRatio: yRatio,
      );
      await _deviceActions.tap(
        session.id,
        RuntimeTap(point: point, label: label, durationMs: pressDurationMs),
      );
      return true;
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '预览长按失败：$error')));
      return false;
    } finally {
      await _releasePreviewActions(session.id, actionName: '长按');
    }
  }
}
