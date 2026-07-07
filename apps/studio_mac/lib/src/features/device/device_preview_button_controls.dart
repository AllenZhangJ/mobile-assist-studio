part of '../../studio_mac_workspace.dart';

// 设备预览硬件键控件，只暴露受控白名单按钮。
class _PreviewButtonControls extends StatelessWidget {
  const _PreviewButtonControls({
    required this.enabled,
    required this.sending,
    required this.onHomePressed,
  });

  final bool enabled;
  final bool sending;
  final VoidCallback? onHomePressed;

  // 渲染固定宽度硬件键按钮，避免顶部栏因中文文案跳动。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Tooltip(
        message: sending ? '发送中' : '回主页',
        child: OutlinedButton.icon(
          key: const ValueKey('device-preview-home-button'),
          onPressed: enabled && !sending ? onHomePressed : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            side: const BorderSide(color: StudioColors.border),
            foregroundColor: StudioColors.text,
            disabledForegroundColor: StudioColors.muted.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: Icon(sending ? Icons.sync : Icons.home_outlined, size: 16),
          label: const Text(
            '主页',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}
