part of '../../studio_mac_workspace.dart';

// 时间线行内工具按钮，保持紧凑尺寸避免挤压动作摘要。
class _RecorderActionIconButton extends StatelessWidget {
  const _RecorderActionIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  // 渲染单个图标按钮，禁用态用于边界位置。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 17,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
