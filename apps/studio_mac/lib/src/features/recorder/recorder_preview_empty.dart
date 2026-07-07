part of '../../studio_mac_workspace.dart';

// 设备预览空态，保持录制区在无截图时仍有稳定尺寸。
class _RecorderPreviewEmpty extends StatelessWidget {
  const _RecorderPreviewEmpty();

  // 渲染简洁空态图标，不展示技术错误。
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.phone_iphone_outlined,
        color: StudioColors.muted,
        size: 36,
      ),
    );
  }
}
