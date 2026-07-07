part of '../../studio_mac_workspace.dart';

// 节点轨迹筛选模型，只表达详情时间轴的本地视图过滤。
enum _RunTraceFilter { all, issues, screenshots }

// 轨迹筛选条组件，负责展示过滤入口和当前数量。
class _RunTraceFilterBar extends StatelessWidget {
  const _RunTraceFilterBar({
    required this.selected,
    required this.traces,
    required this.onSelected,
  });

  final _RunTraceFilter selected;
  final List<RunNodeTrace> traces;
  final ValueChanged<_RunTraceFilter> onSelected;

  // 渲染轨迹筛选条，数量来自当前详情本地数据。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _RunTraceFilter.values)
          _RunTraceFilterChip(
            filter: filter,
            selected: selected == filter,
            count: _filterRunNodeTraces(traces, filter).length,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

// 单个轨迹筛选按钮，保持筛选状态和数量呈现内聚。
class _RunTraceFilterChip extends StatelessWidget {
  const _RunTraceFilterChip({
    required this.filter,
    required this.selected,
    required this.count,
    required this.onSelected,
  });

  final _RunTraceFilter filter;
  final bool selected;
  final int count;
  final ValueChanged<_RunTraceFilter> onSelected;

  // 渲染单个轨迹筛选按钮，使用 tone 保持状态一致。
  @override
  Widget build(BuildContext context) {
    final tone = _toneForRunTraceFilter(filter);
    final color = _colorForTone(tone);
    return OutlinedButton(
      key: ValueKey('run-trace-filter-${filter.name}'),
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
          Icon(_iconForRunTraceFilter(filter), size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '${_labelForRunTraceFilter(filter)} $count',
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
