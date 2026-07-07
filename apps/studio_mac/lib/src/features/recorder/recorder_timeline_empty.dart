part of '../../studio_mac_workspace.dart';

// 录制时间轴空态，提示用户先开始录制。
class _RecorderTimelineEmpty extends StatelessWidget {
  const _RecorderTimelineEmpty();

  // 渲染空态文案，不展示坐标或技术细节。
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '开始录制后添加点击、等待或滑动。',
        textAlign: TextAlign.center,
        style: TextStyle(color: StudioColors.muted),
      ),
    );
  }
}
