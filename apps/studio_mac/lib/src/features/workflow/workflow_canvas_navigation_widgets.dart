part of '../../studio_mac_workspace.dart';

// Workflow 节点导航展示组件，承载快捷按钮和搜索结果行的轻量 UI。

// 节点导航外层面板，统一折叠和展开两种状态的阴影与边框。
class _WorkflowNavigatorSurface extends StatelessWidget {
  const _WorkflowNavigatorSurface({required this.child});

  final Widget child;

  // 渲染导航浮层外观，避免各状态重复维护样式。
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        key: const ValueKey('workflow-node-navigator'),
        decoration: BoxDecoration(
          color: StudioColors.panel.withValues(alpha: 0.92),
          border: Border.all(color: StudioColors.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// 节点导航折叠按钮，负责打开完整导航面板。
class _WorkflowNodeNavigatorCollapsed extends StatelessWidget {
  const _WorkflowNodeNavigatorCollapsed({required this.onToggleExpanded});

  final VoidCallback onToggleExpanded;

  // 渲染紧凑入口，折叠态不占用画布空间。
  @override
  Widget build(BuildContext context) {
    return _WorkflowNavigatorSurface(
      child: SizedBox.square(
        dimension: 42,
        child: IconButton(
          key: const ValueKey('workflow-node-navigator-toggle'),
          tooltip: '打开导航',
          icon: const Icon(Icons.travel_explore_outlined, size: 18),
          onPressed: onToggleExpanded,
        ),
      ),
    );
  }
}

// 节点导航快捷按钮，负责当前、选中、失败和问题等定位入口。
class _WorkflowNavigatorChip extends StatelessWidget {
  const _WorkflowNavigatorChip({
    super.key,
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  // 渲染紧凑图标按钮，保证导航面板在小宽度下不被撑开。
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// 节点导航搜索结果，负责展示节点摘要和运行/问题状态。
class _WorkflowNavigatorResult extends StatelessWidget {
  const _WorkflowNavigatorResult({required this.item, required this.onPressed});

  final _WorkflowNavigatorResultItem item;
  final VoidCallback onPressed;

  // 渲染单个搜索结果，点击后交给画布定位而不修改 DSL。
  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: ValueKey('workflow-navigator-result-${item.nodeId}'),
      borderRadius: BorderRadius.circular(8),
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: item.selected
              ? StudioColors.cyan.withValues(alpha: 0.10)
              : StudioColors.background.withValues(alpha: 0.60),
          border: Border.all(
            color: item.selected
                ? StudioColors.cyan.withValues(alpha: 0.46)
                : StudioColors.border,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              _iconForNodes(item.type),
              size: 15,
              color: _colorForTone(item.tone),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudioColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.statusLabel case final statusLabel?)
              StatusPill(label: statusLabel, tone: item.tone),
          ],
        ),
      ),
    );
  }
}
