part of '../../studio_mac_workspace.dart';

// Monitor 证据预览框，统一截图加载、不可用和实际图片的外层样式。
class _EvidencePreviewFrame extends StatelessWidget {
  const _EvidencePreviewFrame({required this.child});

  final Widget child;

  // 构建固定边界的证据预览容器，避免截图加载时布局跳动。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.48),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
