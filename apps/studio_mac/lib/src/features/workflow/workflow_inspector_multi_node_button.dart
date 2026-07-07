part of '../../studio_mac_workspace.dart';

// 多选批量布局按钮，复用禁用态和保存态样式，避免按钮实现散落重复。
class _MultiNodeAlignButton extends StatelessWidget {
  const _MultiNodeAlignButton({
    required this.buttonKey,
    required this.locked,
    required this.savingGraphEdit,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final bool locked;
  final bool savingGraphEdit;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  // 渲染单个多选布局按钮，保存中统一显示等待图标。
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: locked ? null : onPressed,
      icon: Icon(savingGraphEdit ? Icons.hourglass_top : icon, size: 18),
      label: Text(
        savingGraphEdit ? '保存中...' : label,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
