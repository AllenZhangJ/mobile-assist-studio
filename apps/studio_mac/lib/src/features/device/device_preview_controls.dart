part of '../../studio_mac_workspace.dart';

// 设备预览头部工具条，负责状态、截图时间、缩放和输入控件组合。
class _DevicePreviewHeader extends StatelessWidget {
  const _DevicePreviewHeader({
    required this.hasScreenshot,
    required this.canGesture,
    required this.tapSending,
    required this.doubleTapSending,
    required this.longPressSending,
    required this.swipeSending,
    required this.pinchSending,
    required this.homeButtonSending,
    required this.latestScreenshotAt,
    required this.previewScale,
    required this.inputController,
    required this.inputEnabled,
    required this.inputSending,
    required this.canInput,
    required this.buttonEnabled,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onZoomReset,
    required this.onPinchOut,
    required this.onPinchIn,
    required this.onHomePressed,
    required this.onInputSubmitted,
    required this.onInputSend,
  });

  final bool hasScreenshot;
  final bool canGesture;
  final bool tapSending;
  final bool doubleTapSending;
  final bool longPressSending;
  final bool swipeSending;
  final bool pinchSending;
  final bool homeButtonSending;
  final DateTime? latestScreenshotAt;
  final double previewScale;
  final TextEditingController inputController;
  final bool inputEnabled;
  final bool inputSending;
  final bool canInput;
  final bool buttonEnabled;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomReset;
  final VoidCallback? onPinchOut;
  final VoidCallback? onPinchIn;
  final VoidCallback? onHomePressed;
  final ValueChanged<String>? onInputSubmitted;
  final VoidCallback? onInputSend;

  // 渲染预览头部摘要，保持主界面只显示用户能理解的短状态。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        StatusPill(
          label: hasScreenshot ? '有预览' : '无预览',
          tone: hasScreenshot
              ? StudioStatusTone.ready
              : StudioStatusTone.offline,
        ),
        StatusPill(
          label: canGesture
              ? '可操作'
              : homeButtonSending
              ? '回主页'
              : doubleTapSending
              ? '双击中'
              : longPressSending
              ? '长按中'
              : pinchSending
              ? '缩放中'
              : tapSending
              ? '点击中'
              : swipeSending
              ? '滑动中'
              : '已锁定',
          tone: canGesture
              ? StudioStatusTone.ready
              : tapSending ||
                    doubleTapSending ||
                    longPressSending ||
                    swipeSending ||
                    pinchSending ||
                    homeButtonSending
              ? StudioStatusTone.running
              : StudioStatusTone.offline,
        ),
        Text(
          latestScreenshotAt == null
              ? '暂无截图'
              : '已截图 ${_timeOnly(latestScreenshotAt!)}',
          style: const TextStyle(color: StudioColors.muted, fontSize: 12),
        ),
        _PreviewZoomControls(
          scale: previewScale,
          enabled: hasScreenshot,
          onZoomOut: onZoomOut,
          onZoomIn: onZoomIn,
          onReset: onZoomReset,
        ),
        _PreviewPinchControls(
          enabled: canGesture,
          sending: pinchSending,
          onPinchOut: onPinchOut,
          onPinchIn: onPinchIn,
        ),
        _PreviewButtonControls(
          enabled: buttonEnabled,
          sending: homeButtonSending,
          onHomePressed: onHomePressed,
        ),
        _PreviewInputControl(
          controller: inputController,
          enabled: inputEnabled,
          sending: inputSending,
          canSend: canInput,
          onSubmitted: onInputSubmitted,
          onSend: onInputSend,
        ),
      ],
    );
  }
}
