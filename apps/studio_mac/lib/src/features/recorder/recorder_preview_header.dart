part of '../../studio_mac_workspace.dart';

// 录制预览头部，展示预览状态和手动截图入口。
class _RecorderPreviewHeader extends StatelessWidget {
  const _RecorderPreviewHeader({
    required this.hasScreenshot,
    required this.canCapture,
    required this.canPick,
    required this.onCapture,
  });

  final bool hasScreenshot;
  final bool canCapture;
  final bool canPick;
  final Future<void> Function() onCapture;

  // 渲染简短状态，不在主界面堆叠设备技术细节。
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
        const Text(
          '实时截图',
          style: TextStyle(color: StudioColors.muted, fontSize: 12),
        ),
        OutlinedButton.icon(
          key: const ValueKey('recorder-capture-screen'),
          onPressed: canCapture ? () => unawaited(onCapture()) : null,
          icon: const Icon(Icons.screenshot_monitor_outlined, size: 16),
          label: const Text('截图'),
        ),
        StatusPill(
          label: canPick ? '可录' : '预览',
          tone: canPick ? StudioStatusTone.ready : StudioStatusTone.offline,
        ),
      ],
    );
  }
}
