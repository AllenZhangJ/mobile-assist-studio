part of '../../studio_mac_workspace.dart';

// 方向键滑动方向，集中描述键盘输入到手机滑动的语义映射。
// 它只服务设备预览，不写入 Project DSL。
enum _PreviewKeyboardSwipeDirection { up, down, left, right }

// 方向键滑动参数，使用 Dart 记录类型把坐标和文案绑定为一个只读值。
extension _PreviewKeyboardSwipeDirectionSpec on _PreviewKeyboardSwipeDirection {
  // 返回方向对应的标准滑动轨迹，坐标均为手机视口比例。
  ({Offset from, Offset to, String label}) get spec => switch (this) {
    _PreviewKeyboardSwipeDirection.up => (
      from: const Offset(0.5, 0.68),
      to: const Offset(0.5, 0.32),
      label: '键盘上滑',
    ),
    _PreviewKeyboardSwipeDirection.down => (
      from: const Offset(0.5, 0.32),
      to: const Offset(0.5, 0.68),
      label: '键盘下滑',
    ),
    _PreviewKeyboardSwipeDirection.left => (
      from: const Offset(0.72, 0.5),
      to: const Offset(0.28, 0.5),
      label: '键盘左滑',
    ),
    _PreviewKeyboardSwipeDirection.right => (
      from: const Offset(0.28, 0.5),
      to: const Offset(0.72, 0.5),
      label: '键盘右滑',
    ),
  };
}

// 设备预览键盘动作，负责方向键到受控手机滑动的映射。
extension _DevicePreviewKeyboardActions on _DevicePreviewState {
  // 方向键上滑，模拟用户手指从下往上滑动。
  void _sendKeyboardSwipeUp() {
    _sendKeyboardSwipe(_PreviewKeyboardSwipeDirection.up);
  }

  // 方向键下滑，模拟用户手指从上往下滑动。
  void _sendKeyboardSwipeDown() {
    _sendKeyboardSwipe(_PreviewKeyboardSwipeDirection.down);
  }

  // 方向键左滑，模拟用户手指从右往左滑动。
  void _sendKeyboardSwipeLeft() {
    _sendKeyboardSwipe(_PreviewKeyboardSwipeDirection.left);
  }

  // 方向键右滑，模拟用户手指从左往右滑动。
  void _sendKeyboardSwipeRight() {
    _sendKeyboardSwipe(_PreviewKeyboardSwipeDirection.right);
  }

  // 发送键盘触发的标准滑动，沿用预览手势的安全锁和 Runtime 通道。
  void _sendKeyboardSwipe(_PreviewKeyboardSwipeDirection direction) {
    if (!_interaction.canGesture(
      widget.snapshot,
      hasScreenshot: widget.snapshot.latestScreenshotBase64 != null,
    )) {
      return;
    }
    final (:from, :to, :label) = direction.spec;
    _focusPreviewKeyboard();
    unawaited(
      _sendPreviewSwipe(from: from, to: to, label: label, durationMs: 320),
    );
  }
}
