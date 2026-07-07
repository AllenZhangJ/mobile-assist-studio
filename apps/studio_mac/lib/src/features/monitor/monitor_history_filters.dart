part of '../../studio_mac_workspace.dart';

// 运行记录筛选条，负责展示各类本地记录数量。
class _MonitorRunFilterBar extends StatelessWidget {
  const _MonitorRunFilterBar({
    required this.selected,
    required this.runs,
    required this.onSelected,
  });

  final _MonitorRunFilter selected;
  final List<RunHistoryEntry> runs;
  final ValueChanged<_MonitorRunFilter> onSelected;

  // 渲染紧凑筛选按钮组，数量由 shared helper 派生。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final filter in _MonitorRunFilter.values)
          _MonitorRunFilterChip(
            filter: filter,
            selected: selected == filter,
            count: _filterRunHistory(runs, filter).length,
            onSelected: () => onSelected(filter),
          ),
      ],
    );
  }
}

// 单个运行记录筛选按钮，只承载显示态和点击回调。
class _MonitorRunFilterChip extends StatelessWidget {
  const _MonitorRunFilterChip({
    required this.filter,
    required this.selected,
    required this.count,
    required this.onSelected,
  });

  final _MonitorRunFilter filter;
  final bool selected;
  final int count;
  final VoidCallback onSelected;

  // 渲染短中文筛选文案，避免把底层状态码展示给用户。
  @override
  Widget build(BuildContext context) {
    final tone = _toneForMonitorFilter(filter);
    final color = _colorForTone(tone);
    return OutlinedButton(
      key: ValueKey('monitor-filter-${filter.name}'),
      onPressed: onSelected,
      style: OutlinedButton.styleFrom(
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
          Icon(_iconForMonitorFilter(filter), size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '${_labelForMonitorFilter(filter)} $count',
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

// 运行记录搜索框，负责本地关键字输入和清空入口。
class _MonitorRunSearchField extends StatelessWidget {
  const _MonitorRunSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  // 渲染固定宽度搜索框，保持中文短文案不撑开工具栏。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 360,
      child: TextField(
        key: const ValueKey('monitor-run-search'),
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: '清空搜索',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 16),
                ),
          hintText: '搜记录',
          filled: true,
          fillColor: StudioColors.background.withValues(alpha: 0.44),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: StudioColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: StudioColors.cyan),
          ),
        ),
      ),
    );
  }
}

// 关联运行提示条，说明当前列表来自某个本地问题聚类。
class _MonitorRelatedRunBanner extends StatelessWidget {
  const _MonitorRelatedRunBanner({
    required this.label,
    required this.count,
    required this.onClear,
  });

  final String label;
  final int count;
  final VoidCallback onClear;

  // 渲染可清除的本地关联筛选，不展示 run id 或底层错误。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('monitor-related-runs-banner'),
      decoration: BoxDecoration(
        color: StudioColors.amber.withValues(alpha: 0.1),
        border: Border.all(color: StudioColors.amber.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.account_tree_outlined,
              color: StudioColors.amber,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$label · $count 条',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('monitor-related-runs-clear'),
              onPressed: onClear,
              icon: const Icon(Icons.close, size: 16),
              label: const Text('清除'),
            ),
          ],
        ),
      ),
    );
  }
}
