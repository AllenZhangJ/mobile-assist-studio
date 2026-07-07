part of '../../studio_mac_workspace.dart';

// 录制设备舞台，负责截图预览和从预览点选动作。
class _RecorderDeviceStage extends StatelessWidget {
  const _RecorderDeviceStage({
    required this.snapshot,
    required this.screenshotSize,
    required this.canCapture,
    required this.recording,
    required this.onPickTap,
    required this.onPickSwipe,
    required this.onCapture,
  });

  final StudioRuntimeSnapshot snapshot;
  final Size? screenshotSize;
  final bool canCapture;
  final bool recording;
  final ValueChanged<Offset>? onPickTap;
  final void Function(Offset fromRatio, Offset toRatio)? onPickSwipe;
  final Future<void> Function() onCapture;

  // 渲染可录制的手机预览，点击或拖动时只输出比例坐标。
  @override
  Widget build(BuildContext context) {
    final screenshot = _decodeScreenshot(snapshot.latestScreenshotBase64);
    final canPick =
        recording &&
        screenshot != null &&
        screenshotSize != null &&
        (onPickTap != null || onPickSwipe != null);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecorderPreviewHeader(
            hasScreenshot: screenshot != null,
            canCapture: canCapture,
            canPick: canPick,
            onCapture: onCapture,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 19.5,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final containerSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final contentRect = _previewContentRect(
                      containerSize,
                      screenshotSize,
                    );
                    return _RecorderPreviewTapTarget(
                      contentRect: contentRect,
                      screenshot: screenshot,
                      canPick: canPick,
                      onPickTap: onPickTap,
                      onPickSwipe: onPickSwipe,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
