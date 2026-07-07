part of '../../studio_mac_workspace.dart';

// Workflow 画布控制组件，负责控制条、锁定提示、节点导航和连线工具栏。
class _WorkflowCanvasControls extends StatelessWidget {
  const _WorkflowCanvasControls({
    required this.scale,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onReset,
    required this.onFit,
    required this.selectionMode,
    required this.onToggleSelection,
    required this.onAutoLayout,
  });

  final double scale;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onReset;
  final VoidCallback onFit;
  final bool selectionMode;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onAutoLayout;

  // 渲染画布基础控制条，所有按钮只触发上层传入的受控动作。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.90),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _WorkflowCanvasIconButton(
              key: const ValueKey('workflow-canvas-fit'),
              tooltip: '适应画布',
              icon: Icons.fit_screen_outlined,
              onPressed: onFit,
            ),
            _WorkflowCanvasIconButton(
              tooltip: '重置缩放',
              icon: Icons.center_focus_strong_outlined,
              onPressed: onReset,
            ),
            _WorkflowCanvasIconButton(
              key: const ValueKey('workflow-canvas-auto-layout'),
              tooltip: '自动整理',
              icon: Icons.auto_awesome_mosaic_outlined,
              onPressed: onAutoLayout,
            ),
            _WorkflowCanvasIconButton(
              tooltip: selectionMode ? '退出框选' : '框选',
              icon: Icons.select_all_outlined,
              selected: selectionMode,
              onPressed: onToggleSelection,
            ),
            const SizedBox(height: 4),
            Text(
              '${(scale * 100).round()}%',
              key: const ValueKey('workflow-canvas-zoom-label'),
              style: const TextStyle(
                color: StudioColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            _WorkflowCanvasIconButton(
              tooltip: '缩小',
              icon: Icons.remove,
              onPressed: onZoomOut,
            ),
            _WorkflowCanvasIconButton(
              tooltip: '放大',
              icon: Icons.add,
              onPressed: onZoomIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowCanvasLockBanner extends StatelessWidget {
  const _WorkflowCanvasLockBanner({required this.locked, required this.reason});

  final bool locked;
  final String? reason;

  // 渲染画布锁定摘要，用短文案解释当前是否可编辑。
  @override
  Widget build(BuildContext context) {
    final tone = locked ? StudioStatusTone.warning : StudioStatusTone.ready;
    final color = locked ? StudioColors.amber : StudioColors.green;
    return IgnorePointer(
      child: DecoratedBox(
        key: const ValueKey('workflow-canvas-lock-banner'),
        decoration: BoxDecoration(
          color: StudioColors.panel.withValues(alpha: 0.92),
          border: Border.all(color: color.withValues(alpha: 0.42)),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.26),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  locked ? Icons.lock_outline : Icons.edit_outlined,
                  size: 15,
                  color: color,
                ),
                const SizedBox(width: 8),
                StatusPill(label: locked ? '画布锁定' : '画布就绪', tone: tone),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    locked ? reason ?? '画布暂不可编辑。' : '画布修改会保存到流程文件。',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudioColors.muted,
                      fontSize: 11,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowCanvasIconButton extends StatelessWidget {
  const _WorkflowCanvasIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool selected;

  // 渲染固定尺寸图标按钮，保持画布控制条布局稳定。
  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 30,
      child: IconButton(
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? StudioColors.cyan.withValues(alpha: 0.16)
              : Colors.transparent,
        ),
        icon: Icon(
          icon,
          color: selected ? StudioColors.cyan : StudioColors.text,
        ),
      ),
    );
  }
}
