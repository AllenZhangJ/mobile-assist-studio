part of '../../studio_mac_workspace.dart';

// Monitor 相关事件筛选分片，承载筛选枚举、筛选条和按钮。
// 筛选只作用于当前详情视图，不写 Runtime 或本地 evidence。

enum _RunEventFilter { all, nodes, issues, screenshots }

// 运行事件筛选条，展示各类事件的本地计数。
class _RunEventFilterBar extends StatelessWidget {
  const _RunEventFilterBar({
    required this.selected,
    required this.events,
    required this.onSelected,
  });

  final _RunEventFilter selected;
  final List<RunEvidenceEvent> events;
  final ValueChanged<_RunEventFilter> onSelected;

  // 渲染事件筛选条，各筛选项只基于本地事件列表计数。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _RunEventFilter.values)
          _RunEventFilterChip(
            filter: filter,
            selected: selected == filter,
            count: _filterRunEvents(events, filter).length,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

// 单个事件筛选按钮，负责选中态样式和短中文标签。
class _RunEventFilterChip extends StatelessWidget {
  const _RunEventFilterChip({
    required this.filter,
    required this.selected,
    required this.count,
    required this.onSelected,
  });

  final _RunEventFilter filter;
  final bool selected;
  final int count;
  final ValueChanged<_RunEventFilter> onSelected;

  // 渲染单个筛选按钮，选中态只改变当前列表视图。
  @override
  Widget build(BuildContext context) {
    final tone = _toneForRunEventFilter(filter);
    final color = _colorForTone(tone);
    return OutlinedButton(
      key: ValueKey('run-event-filter-${filter.name}'),
      onPressed: () => onSelected(filter),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? color : StudioColors.text,
        backgroundColor: selected
            ? color.withValues(alpha: 0.14)
            : Colors.transparent,
        side: BorderSide(
          color: selected ? color : StudioColors.border,
          width: selected ? 1.2 : 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForRunEventFilter(filter), size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '${_labelForRunEventFilter(filter)} $count',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? color : StudioColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
