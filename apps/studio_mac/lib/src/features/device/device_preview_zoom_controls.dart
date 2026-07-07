part of '../../studio_mac_workspace.dart';

// 设备预览顶部缩放控件，负责显示比例和缩放入口。
class _PreviewZoomControls extends StatelessWidget {
  const _PreviewZoomControls({
    required this.scale,
    required this.enabled,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
  });

  final double scale;
  final bool enabled;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;

  // 渲染紧凑工具条，避免缩放文字撑开设备页头部。
  @override
  Widget build(BuildContext context) {
    final percent = '${(scale * 100).round()}%';
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.62),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PreviewZoomButton(
            tooltip: '缩小',
            icon: Icons.remove,
            enabled: enabled && scale > 1,
            onPressed: onZoomOut,
          ),
          SizedBox(
            width: 48,
            child: Text(
              percent,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: StudioColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _PreviewZoomButton(
            tooltip: '放大',
            icon: Icons.add,
            enabled: enabled && scale < 2.5,
            onPressed: onZoomIn,
          ),
          _PreviewZoomButton(
            tooltip: '还原',
            icon: Icons.fit_screen_outlined,
            enabled: enabled && scale != 1,
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

// 设备预览缩放按钮，统一缩放工具条里的图标按钮尺寸和颜色。
class _PreviewZoomButton extends StatelessWidget {
  const _PreviewZoomButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  // 渲染固定 32 像素按钮，保持顶部控件稳定不跳动。
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      iconSize: 16,
      color: StudioColors.text,
      disabledColor: StudioColors.muted.withValues(alpha: 0.45),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    );
  }
}
