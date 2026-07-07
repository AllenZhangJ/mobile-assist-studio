part of '../../studio_mac_workspace.dart';

// 设备预览手机缩放控件，向真机发送双指手势而不是改变本地显示比例。
class _PreviewPinchControls extends StatelessWidget {
  const _PreviewPinchControls({
    required this.enabled,
    required this.sending,
    required this.onPinchOut,
    required this.onPinchIn,
  });

  final bool enabled;
  final bool sending;
  final VoidCallback? onPinchOut;
  final VoidCallback? onPinchIn;

  // 渲染固定高度的双指手势按钮组，避免中文文案撑开头部栏。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: StudioColors.background.withValues(alpha: 0.42),
          border: Border.all(color: StudioColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 9, right: 4),
              child: Text(
                '手势',
                style: TextStyle(
                  color: StudioColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _PreviewPinchButton(
              key: const ValueKey('device-preview-pinch-out'),
              tooltip: sending ? '发送中' : '手机放大',
              icon: sending ? Icons.sync : Icons.open_in_full,
              enabled: enabled && !sending,
              onPressed: onPinchOut,
            ),
            _PreviewPinchButton(
              key: const ValueKey('device-preview-pinch-in'),
              tooltip: sending ? '发送中' : '手机缩小',
              icon: sending ? Icons.sync : Icons.close_fullscreen,
              enabled: enabled && !sending,
              onPressed: onPinchIn,
            ),
          ],
        ),
      ),
    );
  }
}

// 单个手机缩放手势按钮，只负责图标、tooltip 和禁用态。
class _PreviewPinchButton extends StatelessWidget {
  const _PreviewPinchButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  // 渲染紧凑 icon button，避免与显示缩放按钮混成同一个语义。
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 16),
        color: StudioColors.text,
        disabledColor: StudioColors.muted.withValues(alpha: 0.45),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 30, height: 30),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
