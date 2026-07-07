part of '../../studio_mac_workspace.dart';

// Execute 主按钮分片，负责高优先级操作按钮的尺寸、文案和异步入口。
class _ExecutePrimaryButton extends StatelessWidget {
  const _ExecutePrimaryButton({
    required this.controlKey,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Key controlKey;
  final String label;
  final IconData icon;
  final Future<void> Function()? onPressed;

  // 渲染高优先级操作按钮，并将异步任务交给 controller 处理。
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: controlKey,
      onPressed: onPressed == null ? null : () => unawaited(onPressed!()),
      style: FilledButton.styleFrom(
        minimumSize: const Size(168, 52),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
      ),
      icon: Icon(icon, size: 20),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}
