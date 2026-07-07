part of '../../studio_mac_workspace.dart';

// 录制时间线头部，承载标题、摘要复制和录制状态。
class _RecorderTimelineHeader extends StatelessWidget {
  const _RecorderTimelineHeader({
    required this.recording,
    required this.onCopySummary,
  });

  final bool recording;
  final VoidCallback? onCopySummary;

  // 渲染时间线头部，不展示坐标或动作内部编号。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '动作线',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const Spacer(),
        SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            key: const ValueKey('recorder-copy-actions-summary'),
            onPressed: onCopySummary,
            tooltip: '复制摘要',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            icon: const Icon(Icons.copy_all_outlined, size: 18),
          ),
        ),
        const SizedBox(width: 10),
        StatusPill(
          label: recording ? '截图中' : '就绪',
          tone: recording ? StudioStatusTone.error : StudioStatusTone.ready,
        ),
      ],
    );
  }
}
