part of '../studio_mac_workspace.dart';

// 控制台标签按钮，负责切换日志、错误、检查、网络和调试视图。
class _ConsoleTabButton extends StatelessWidget {
  const _ConsoleTabButton({
    required this.tab,
    required this.selected,
    required this.onPressed,
  });

  final _ConsoleTab tab;
  final bool selected;
  final VoidCallback onPressed;

  // 渲染单个控制台标签按钮。
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: selected ? StudioColors.cyan : StudioColors.muted,
        backgroundColor: selected
            ? StudioColors.cyan.withValues(alpha: 0.10)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? StudioColors.cyan.withValues(alpha: 0.36)
                : StudioColors.border,
          ),
        ),
      ),
      child: Text(tab.label),
    );
  }
}

// 控制台级别筛选按钮，负责切换全部、信息、提醒和错误。
class _ConsoleLevelFilterButton extends StatelessWidget {
  const _ConsoleLevelFilterButton({
    required this.filter,
    required this.selected,
    required this.onPressed,
  });

  final _ConsoleLevelFilter filter;
  final bool selected;
  final VoidCallback onPressed;

  // 渲染单个级别筛选按钮。
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '筛选${filter.label}',
      child: SizedBox(
        height: 30,
        child: TextButton(
          key: ValueKey('console-level-filter-${filter.name}'),
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(44, 30),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            foregroundColor: selected ? StudioColors.cyan : StudioColors.muted,
            backgroundColor: selected
                ? StudioColors.cyan.withValues(alpha: 0.10)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: selected
                    ? StudioColors.cyan.withValues(alpha: 0.36)
                    : StudioColors.border,
              ),
            ),
          ),
          child: Text(filter.label, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

enum _ConsoleTab {
  log('日志'),
  error('错误'),
  inspector('检查'),
  network('网络'),
  debug('调试');

  const _ConsoleTab(this.label);

  final String label;
}

enum _ConsoleLevelFilter {
  all('全部'),
  info('信息'),
  warning('提醒'),
  error('错误');

  const _ConsoleLevelFilter(this.label);

  final String label;

  // 判断事件是否命中当前级别筛选。
  bool matches(RuntimeEvent event) {
    final level = _runtimeLevelLabel(event.level);
    return switch (this) {
      _ConsoleLevelFilter.all => true,
      _ConsoleLevelFilter.info => level == '信息',
      _ConsoleLevelFilter.warning => level == '提醒',
      _ConsoleLevelFilter.error => level == '错误',
    };
  }
}
