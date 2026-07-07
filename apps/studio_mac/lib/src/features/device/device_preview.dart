part of '../../studio_mac_workspace.dart';

// 设备预览组件，负责截图预览、缩放、点击标记和滑动轨迹展示。
class _DevicePreview extends StatefulWidget {
  const _DevicePreview({required this.snapshot, required this.controller});

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;

  @override
  State<_DevicePreview> createState() => _DevicePreviewState();
}

// 设备预览状态，保留生命周期、截图解码和布局装配。
// 具体动作放在 actions 分片，避免 State 主文件继续膨胀。
class _DevicePreviewState extends State<_DevicePreview> {
  _DevicePreviewInteractionState _interaction =
      const _DevicePreviewInteractionState();
  int _decodeGeneration = 0;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: '设备预览键盘');

  // 初始化输入监听并尝试解析首张截图尺寸。
  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
    _decodeScreenshotSize();
  }

  // 释放输入控制器，避免页面切换后保留监听。
  @override
  void dispose() {
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // 截图变化时重新解析尺寸，无截图时清理预览交互痕迹。
  @override
  void didUpdateWidget(_DevicePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.latestScreenshotBase64 !=
        widget.snapshot.latestScreenshotBase64) {
      _decodeScreenshotSize();
    }
    if (widget.snapshot.latestScreenshotBase64 == null) {
      _interaction = _interaction.resetPreviewArtifacts();
    }
  }

  // 输入框内容变化只影响发送按钮启用态。
  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  // 统一写入预览交互状态，动作分片不直接调用 setState。
  void _setInteraction(_DevicePreviewInteractionState next) {
    setState(() => _interaction = next);
  }

  // 异步解析截图尺寸，并用 generation 防止旧解析结果覆盖新截图。
  Future<void> _decodeScreenshotSize() async {
    final generation = ++_decodeGeneration;
    final screenshot = _decodeScreenshot(
      widget.snapshot.latestScreenshotBase64,
    );
    if (screenshot == null) {
      if (mounted) {
        setState(() {
          _interaction = _interaction.copyWith(screenshotSize: null);
        });
      }
      return;
    }
    final size = await _imageSizeFromBytes(screenshot);
    if (!mounted || generation != _decodeGeneration) return;
    setState(() {
      _interaction = _interaction.copyWith(screenshotSize: size);
    });
  }

  // 渲染设备预览整体布局，并根据连接和运行状态锁定手势。
  @override
  Widget build(BuildContext context) {
    final screenshot = _decodeScreenshot(
      widget.snapshot.latestScreenshotBase64,
    );
    final canGesture = _interaction.canGesture(
      widget.snapshot,
      hasScreenshot: screenshot != null,
    );
    final inputEnabled = _interaction.inputEnabled(widget.snapshot);
    final buttonEnabled = _interaction.buttonEnabled(widget.snapshot);
    final canInput = inputEnabled && _inputController.text.trim().isNotEmpty;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DevicePreviewHeader(
            hasScreenshot: screenshot != null,
            canGesture: canGesture,
            tapSending: _interaction.tapSending,
            doubleTapSending: _interaction.doubleTapSending,
            longPressSending: _interaction.longPressSending,
            swipeSending: _interaction.swipeSending,
            pinchSending: _interaction.pinchSending,
            homeButtonSending: _interaction.homeButtonSending,
            latestScreenshotAt: widget.snapshot.latestScreenshotAt,
            previewScale: _interaction.previewScale,
            inputController: _inputController,
            inputEnabled: inputEnabled,
            inputSending: _interaction.inputSending,
            canInput: canInput,
            buttonEnabled: buttonEnabled,
            onZoomOut: () => _setPreviewScale(_interaction.previewScale - 0.25),
            onZoomIn: () => _setPreviewScale(_interaction.previewScale + 0.25),
            onZoomReset: () => _setPreviewScale(1),
            onPinchOut: canGesture ? _sendDevicePinchOut : null,
            onPinchIn: canGesture ? _sendDevicePinchIn : null,
            onHomePressed: buttonEnabled ? _sendHomeButton : null,
            onInputSubmitted: canInput ? (_) => _sendFocusedInput() : null,
            onInputSend: canInput ? _sendFocusedInput : null,
          ),
          const SizedBox(height: 16),
          _DevicePreviewStage(
            screenshot: screenshot,
            screenshotSize: _interaction.screenshotSize,
            previewScale: _interaction.previewScale,
            canGesture: canGesture,
            lastTapRatio: _interaction.lastTapRatio,
            dragStartRatio: _interaction.dragStartRatio,
            dragEndRatio: _interaction.dragEndRatio,
            lastSwipeFromRatio: _interaction.lastSwipeFromRatio,
            lastSwipeToRatio: _interaction.lastSwipeToRatio,
            tapSending: _interaction.tapSending,
            doubleTapSending: _interaction.doubleTapSending,
            longPressSending: _interaction.longPressSending,
            swipeSending: _interaction.swipeSending,
            keyboardFocusNode: _keyboardFocusNode,
            onKeyboardSwipeUp: _sendKeyboardSwipeUp,
            onKeyboardSwipeDown: _sendKeyboardSwipeDown,
            onKeyboardSwipeLeft: _sendKeyboardSwipeLeft,
            onKeyboardSwipeRight: _sendKeyboardSwipeRight,
            onPointerSignal: _handlePreviewScroll,
            onTapUp: _handlePreviewTap,
            onDoubleTapDown: _handlePreviewDoubleTap,
            onLongPressStart: _handlePreviewLongPress,
            onPanStart: _handlePreviewPanStart,
            onPanUpdate: _handlePreviewPanUpdate,
            onPanEnd: _handlePreviewPanEnd,
          ),
        ],
      ),
    );
  }
}
