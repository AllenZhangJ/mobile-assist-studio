part of '../../studio_mac_workspace.dart';

// 设备预览舞台，负责手机外框、截图、手势绑定和覆盖层展示。
class _DevicePreviewStage extends StatelessWidget {
  const _DevicePreviewStage({
    required this.screenshot,
    required this.screenshotSize,
    required this.previewScale,
    required this.canGesture,
    required this.lastTapRatio,
    required this.dragStartRatio,
    required this.dragEndRatio,
    required this.lastSwipeFromRatio,
    required this.lastSwipeToRatio,
    required this.tapSending,
    required this.doubleTapSending,
    required this.longPressSending,
    required this.swipeSending,
    required this.keyboardFocusNode,
    required this.onKeyboardSwipeUp,
    required this.onKeyboardSwipeDown,
    required this.onKeyboardSwipeLeft,
    required this.onKeyboardSwipeRight,
    required this.onPointerSignal,
    required this.onTapUp,
    required this.onDoubleTapDown,
    required this.onLongPressStart,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  final Uint8List? screenshot;
  final Size? screenshotSize;
  final double previewScale;
  final bool canGesture;
  final Offset? lastTapRatio;
  final Offset? dragStartRatio;
  final Offset? dragEndRatio;
  final Offset? lastSwipeFromRatio;
  final Offset? lastSwipeToRatio;
  final bool tapSending;
  final bool doubleTapSending;
  final bool longPressSending;
  final bool swipeSending;
  final FocusNode keyboardFocusNode;
  final VoidCallback onKeyboardSwipeUp;
  final VoidCallback onKeyboardSwipeDown;
  final VoidCallback onKeyboardSwipeLeft;
  final VoidCallback onKeyboardSwipeRight;
  final void Function(PointerSignalEvent event, Size containerSize)
  onPointerSignal;
  final void Function(TapUpDetails details, Size containerSize) onTapUp;
  final void Function(TapDownDetails details, Size containerSize)
  onDoubleTapDown;
  final void Function(LongPressStartDetails details, Size containerSize)
  onLongPressStart;
  final void Function(DragStartDetails details, Size containerSize) onPanStart;
  final void Function(DragUpdateDetails details, Size containerSize)
  onPanUpdate;
  final void Function(DragEndDetails details) onPanEnd;

  // 渲染设备预览主体，所有动作仍回调到 State 后由 Runtime 执行。
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.arrowUp): onKeyboardSwipeUp,
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              onKeyboardSwipeDown,
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              onKeyboardSwipeLeft,
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              onKeyboardSwipeRight,
        },
        child: Focus(
          key: const ValueKey('device-preview-keyboard-focus'),
          focusNode: keyboardFocusNode,
          autofocus: true,
          child: Center(
            child: AspectRatio(
              aspectRatio: 9 / 19.5,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final containerSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final contentRect = _devicePreviewDisplayRect(
                    containerSize: containerSize,
                    screenshotSize: screenshotSize,
                    scale: previewScale,
                  );
                  return Listener(
                    onPointerSignal: canGesture
                        ? (event) => onPointerSignal(event, containerSize)
                        : null,
                    child: Container(
                      key: const ValueKey('device-preview-tap-target'),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: canGesture
                            ? (details) => onTapUp(details, containerSize)
                            : null,
                        onDoubleTapDown: canGesture
                            ? (details) =>
                                  onDoubleTapDown(details, containerSize)
                            : null,
                        onLongPressStart: canGesture
                            ? (details) =>
                                  onLongPressStart(details, containerSize)
                            : null,
                        onPanStart: canGesture
                            ? (details) => onPanStart(details, containerSize)
                            : null,
                        onPanUpdate: canGesture
                            ? (details) => onPanUpdate(details, containerSize)
                            : null,
                        onPanEnd: canGesture ? onPanEnd : null,
                        child: _DevicePreviewFrame(
                          screenshot: screenshot,
                          previewScale: previewScale,
                          contentRect: contentRect,
                          lastTapRatio: lastTapRatio,
                          dragStartRatio: dragStartRatio,
                          dragEndRatio: dragEndRatio,
                          lastSwipeFromRatio: lastSwipeFromRatio,
                          lastSwipeToRatio: lastSwipeToRatio,
                          tapSending:
                              tapSending ||
                              doubleTapSending ||
                              longPressSending,
                          swipeSending: swipeSending,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 手机预览外框，负责截图内容和点击/滑动覆盖层组合。
class _DevicePreviewFrame extends StatelessWidget {
  const _DevicePreviewFrame({
    required this.screenshot,
    required this.previewScale,
    required this.contentRect,
    required this.lastTapRatio,
    required this.dragStartRatio,
    required this.dragEndRatio,
    required this.lastSwipeFromRatio,
    required this.lastSwipeToRatio,
    required this.tapSending,
    required this.swipeSending,
  });

  final Uint8List? screenshot;
  final double previewScale;
  final Rect contentRect;
  final Offset? lastTapRatio;
  final Offset? dragStartRatio;
  final Offset? dragEndRatio;
  final Offset? lastSwipeFromRatio;
  final Offset? lastSwipeToRatio;
  final bool tapSending;
  final bool swipeSending;

  // 渲染截图和覆盖层，空态不暴露底层会话细节。
  @override
  Widget build(BuildContext context) {
    final screenshot = this.screenshot;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF05080C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: StudioColors.cyan.withValues(alpha: 0.36),
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          screenshot == null
              ? const _PreviewEmptyState()
              : Transform.scale(
                  scale: previewScale,
                  child: Image.memory(
                    screenshot,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
          if (lastTapRatio != null)
            _PreviewTapMarker(
              ratio: lastTapRatio!,
              contentRect: contentRect,
              sending: tapSending,
            ),
          if (dragStartRatio != null && dragEndRatio != null)
            _PreviewSwipeLine(
              fromRatio: dragStartRatio!,
              toRatio: dragEndRatio!,
              contentRect: contentRect,
              sending: false,
            ),
          if (lastSwipeFromRatio != null && lastSwipeToRatio != null)
            _PreviewSwipeLine(
              fromRatio: lastSwipeFromRatio!,
              toRatio: lastSwipeToRatio!,
              contentRect: contentRect,
              sending: swipeSending,
            ),
        ],
      ),
    );
  }
}
