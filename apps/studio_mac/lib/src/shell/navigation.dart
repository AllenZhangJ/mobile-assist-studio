part of '../studio_mac_workspace.dart';

// 左侧导航栏，负责页面切换、折叠状态和全局入口呈现。
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
    required this.onOpenSettings,
  });

  final int selectedIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenSettings;

  // 构建固定宽度侧栏，保持 L1-L6 入口稳定。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      decoration: const BoxDecoration(
        color: Color(0xCC070B10),
        border: Border(right: BorderSide(color: StudioColors.border)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _NavButton(
                  item: items[index],
                  selected: selectedIndex == index,
                  onPressed: () => onSelect(index),
                );
              },
            ),
          ),
          IconButton(
            key: const ValueKey('open-settings-drawer'),
            tooltip: '设置',
            onPressed: onOpenSettings,
            icon: const Icon(
              Icons.settings_outlined,
              color: StudioColors.muted,
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onPressed;

  // 构建单个导航按钮，用短中文名称提升识别效率。
  @override
  Widget build(BuildContext context) {
    final color = selected ? StudioColors.cyan : StudioColors.muted;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Tooltip(
        message: item.label,
        child: InkWell(
          key: ValueKey('nav-${item.shortLabel}'),
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: selected
                  ? StudioColors.cyan.withValues(alpha: 0.12)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? StudioColors.cyan.withValues(alpha: 0.42)
                    : Colors.transparent,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, color: color, size: 20),
                const SizedBox(height: 3),
                Text(
                  item.shortLabel,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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

// 一级导航元信息，使用短中文名称和图标驱动侧栏。
final class _NavItem {
  const _NavItem(this.shortLabel, this.label, this.icon);

  final String shortLabel;
  final String label;
  final IconData icon;
}
