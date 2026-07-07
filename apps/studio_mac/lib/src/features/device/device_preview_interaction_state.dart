part of '../../studio_mac_workspace.dart';

// 设备预览交互状态，集中管理点击、拖动、滑动和发送中标记。
// UI 只读取这个对象，避免页面 State 持有大量零散字段。
final class _DevicePreviewInteractionState {
  const _DevicePreviewInteractionState({
    this.screenshotSize,
    this.lastTapRatio,
    this.dragStartRatio,
    this.dragEndRatio,
    this.lastSwipeFromRatio,
    this.lastSwipeToRatio,
    this.tapSending = false,
    this.doubleTapSending = false,
    this.longPressSending = false,
    this.swipeSending = false,
    this.pinchSending = false,
    this.inputSending = false,
    this.homeButtonSending = false,
    this.previewScale = 1,
  });

  final Size? screenshotSize;
  final Offset? lastTapRatio;
  final Offset? dragStartRatio;
  final Offset? dragEndRatio;
  final Offset? lastSwipeFromRatio;
  final Offset? lastSwipeToRatio;
  final bool tapSending;
  final bool doubleTapSending;
  final bool longPressSending;
  final bool swipeSending;
  final bool pinchSending;
  final bool inputSending;
  final bool homeButtonSending;
  final double previewScale;

  // 判断当前是否有动作正在发送，用于统一锁定预览手势。
  bool get isSending =>
      tapSending ||
      doubleTapSending ||
      longPressSending ||
      swipeSending ||
      pinchSending ||
      inputSending ||
      homeButtonSending;

  // 根据连接、运行和截图状态判断是否允许在预览上操作。
  bool canGesture(
    StudioRuntimeSnapshot snapshot, {
    required bool hasScreenshot,
  }) {
    return hasScreenshot &&
        snapshot.connectionStatus == ConnectionStatus.connected &&
        snapshot.runStatus == RunStatus.idle &&
        !isSending;
  }

  // 判断文本输入是否可用，输入发送中或运行中都会锁定。
  bool inputEnabled(StudioRuntimeSnapshot snapshot) {
    return snapshot.connectionStatus == ConnectionStatus.connected &&
        snapshot.runStatus == RunStatus.idle &&
        !isSending;
  }

  // 判断硬件键是否可发送，保持和其它设备动作一致的锁定边界。
  bool buttonEnabled(StudioRuntimeSnapshot snapshot) {
    return snapshot.connectionStatus == ConnectionStatus.connected &&
        snapshot.runStatus == RunStatus.idle &&
        !isSending;
  }

  // 复制状态并保留未传入字段，允许显式写入 null。
  _DevicePreviewInteractionState copyWith({
    Object? screenshotSize = _devicePreviewUnset,
    Object? lastTapRatio = _devicePreviewUnset,
    Object? dragStartRatio = _devicePreviewUnset,
    Object? dragEndRatio = _devicePreviewUnset,
    Object? lastSwipeFromRatio = _devicePreviewUnset,
    Object? lastSwipeToRatio = _devicePreviewUnset,
    bool? tapSending,
    bool? doubleTapSending,
    bool? longPressSending,
    bool? swipeSending,
    bool? pinchSending,
    bool? inputSending,
    bool? homeButtonSending,
    double? previewScale,
  }) {
    return _DevicePreviewInteractionState(
      screenshotSize: identical(screenshotSize, _devicePreviewUnset)
          ? this.screenshotSize
          : screenshotSize as Size?,
      lastTapRatio: identical(lastTapRatio, _devicePreviewUnset)
          ? this.lastTapRatio
          : lastTapRatio as Offset?,
      dragStartRatio: identical(dragStartRatio, _devicePreviewUnset)
          ? this.dragStartRatio
          : dragStartRatio as Offset?,
      dragEndRatio: identical(dragEndRatio, _devicePreviewUnset)
          ? this.dragEndRatio
          : dragEndRatio as Offset?,
      lastSwipeFromRatio: identical(lastSwipeFromRatio, _devicePreviewUnset)
          ? this.lastSwipeFromRatio
          : lastSwipeFromRatio as Offset?,
      lastSwipeToRatio: identical(lastSwipeToRatio, _devicePreviewUnset)
          ? this.lastSwipeToRatio
          : lastSwipeToRatio as Offset?,
      tapSending: tapSending ?? this.tapSending,
      doubleTapSending: doubleTapSending ?? this.doubleTapSending,
      longPressSending: longPressSending ?? this.longPressSending,
      swipeSending: swipeSending ?? this.swipeSending,
      pinchSending: pinchSending ?? this.pinchSending,
      inputSending: inputSending ?? this.inputSending,
      homeButtonSending: homeButtonSending ?? this.homeButtonSending,
      previewScale: previewScale ?? this.previewScale,
    );
  }

  // 清空截图相关痕迹，保留输入发送状态但重置缩放。
  _DevicePreviewInteractionState resetPreviewArtifacts() {
    return copyWith(
      screenshotSize: null,
      lastTapRatio: null,
      dragStartRatio: null,
      dragEndRatio: null,
      lastSwipeFromRatio: null,
      lastSwipeToRatio: null,
      previewScale: 1,
    );
  }

  // 进入点击类发送状态，并同步最新点击坐标。
  _DevicePreviewInteractionState beginTap(Offset ratio) {
    return copyWith(lastTapRatio: ratio, tapSending: true);
  }

  // 结束单击发送，保留最后点击标记供用户确认。
  _DevicePreviewInteractionState finishTap() {
    return copyWith(tapSending: false);
  }

  // 进入双击发送状态，使用同一坐标标记。
  _DevicePreviewInteractionState beginDoubleTap(Offset ratio) {
    return copyWith(lastTapRatio: ratio, doubleTapSending: true);
  }

  // 结束双击发送，释放预览手势锁。
  _DevicePreviewInteractionState finishDoubleTap() {
    return copyWith(doubleTapSending: false);
  }

  // 进入长按发送状态，使用同一坐标标记。
  _DevicePreviewInteractionState beginLongPress(Offset ratio) {
    return copyWith(lastTapRatio: ratio, longPressSending: true);
  }

  // 结束长按发送，释放预览手势锁。
  _DevicePreviewInteractionState finishLongPress() {
    return copyWith(longPressSending: false);
  }

  // 记录拖动起点，拖动过程会持续更新终点。
  _DevicePreviewInteractionState beginDrag(Offset ratio) {
    return copyWith(dragStartRatio: ratio, dragEndRatio: ratio);
  }

  // 更新当前拖动终点，用于显示临时滑动轨迹。
  _DevicePreviewInteractionState updateDrag(Offset ratio) {
    return copyWith(dragEndRatio: ratio);
  }

  // 结束拖动并清空临时轨迹，由调用方决定是否发送 swipe。
  _DevicePreviewInteractionState finishDrag() {
    return copyWith(dragStartRatio: null, dragEndRatio: null);
  }

  // 进入滑动发送状态，并显示最近一次滑动轨迹。
  _DevicePreviewInteractionState beginSwipe({
    required Offset from,
    required Offset to,
  }) {
    return copyWith(
      lastTapRatio: null,
      lastSwipeFromRatio: from,
      lastSwipeToRatio: to,
      swipeSending: true,
    );
  }

  // 结束滑动发送，保留轨迹供用户确认。
  _DevicePreviewInteractionState finishSwipe() {
    return copyWith(swipeSending: false);
  }

  // 进入双指缩放发送状态，锁定其它手机手势。
  _DevicePreviewInteractionState beginPinch() {
    return copyWith(pinchSending: true);
  }

  // 结束双指缩放发送，释放预览手势锁。
  _DevicePreviewInteractionState finishPinch() {
    return copyWith(pinchSending: false);
  }

  // 进入硬件主页键发送状态。
  _DevicePreviewInteractionState beginHomeButton() {
    return copyWith(homeButtonSending: true);
  }

  // 结束硬件主页键发送状态。
  _DevicePreviewInteractionState finishHomeButton() {
    return copyWith(homeButtonSending: false);
  }

  // 更新缩放并限制范围，避免截图内容脱离预览视窗。
  _DevicePreviewInteractionState withPreviewScale(double value) {
    return copyWith(previewScale: value.clamp(1.0, 2.5).toDouble());
  }
}

const Object _devicePreviewUnset = Object();
