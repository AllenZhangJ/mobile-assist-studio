part of '../../studio_mac_workspace.dart';

// 监控趋势面板，负责按时间窗口展示本地运行数量。
class _RunTrendPanel extends StatelessWidget {
  const _RunTrendPanel({
    required this.history,
    required this.selected,
    required this.onSelected,
  });

  final RunHistorySummary history;
  final _MonitorTrendWindow selected;
  final ValueChanged<_MonitorTrendWindow> onSelected;

  // 渲染趋势卡片，并把窗口切换交还给页面状态。
  @override
  Widget build(BuildContext context) {
    final dailyRuns = _trendRunsForWindow(history, selected);
    final maxRuns = dailyRuns.fold<int>(
      0,
      (value, day) => math.max(value, day.totalRuns),
    );
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                _trendWindowTitle(selected),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              _RunTrendWindowSelector(
                selected: selected,
                onSelected: onSelected,
              ),
              StatusPill(
                label: dailyRuns.isEmpty ? '暂无数据' : '本机',
                tone: dailyRuns.isEmpty
                    ? StudioStatusTone.offline
                    : StudioStatusTone.running,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: dailyRuns.isEmpty
                ? const Center(
                    child: Text(
                      '暂无趋势',
                      style: TextStyle(color: StudioColors.muted),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final day in dailyRuns) ...[
                        Expanded(
                          child: _RunTrendDayBar(day: day, maxRuns: maxRuns),
                        ),
                        if (day != dailyRuns.last)
                          SizedBox(width: _trendBarGap(dailyRuns.length)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// 单日趋势柱，绿色表示总量，黄色表示问题占比。
class _RunTrendDayBar extends StatelessWidget {
  const _RunTrendDayBar({required this.day, required this.maxRuns});

  final RunHistoryDay day;
  final int maxRuns;

  // 根据父级高度自适应标签密度和柱高。
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 76;
        final ratio = maxRuns == 0 ? 0.0 : day.totalRuns / maxRuns;
        final issueRatio = day.totalRuns == 0
            ? 0.0
            : day.issueRuns / day.totalRuns;
        final maxBarHeight = compact ? 30.0 : 46.0;
        final totalHeight = math.max(5.0, maxBarHeight * ratio);
        final issueHeight = math.max(0.0, totalHeight * issueRatio);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!compact) ...[
              Text(
                '${day.totalRuns}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudioColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
            ],
            Container(
              height: totalHeight,
              constraints: const BoxConstraints(minWidth: 3),
              decoration: BoxDecoration(
                color: StudioColors.green.withValues(
                  alpha: day.totalRuns == 0 ? 0.16 : 0.74,
                ),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: StudioColors.border),
              ),
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: issueHeight,
                decoration: BoxDecoration(
                  color: StudioColors.amber.withValues(alpha: 0.86),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _trendDayLabel(day.day),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StudioColors.muted,
                fontSize: compact ? 9 : 10,
              ),
            ),
          ],
        );
      },
    );
  }
}

// 趋势窗口选择器，固定在卡片标题行内。
class _RunTrendWindowSelector extends StatelessWidget {
  const _RunTrendWindowSelector({
    required this.selected,
    required this.onSelected,
  });

  final _MonitorTrendWindow selected;
  final ValueChanged<_MonitorTrendWindow> onSelected;

  // 渲染三个紧凑按钮，选中项禁用以减少误触。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.54),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final window in _MonitorTrendWindow.values)
            _RunTrendWindowButton(
              window: window,
              selected: selected == window,
              onPressed: () => onSelected(window),
            ),
        ],
      ),
    );
  }
}

// 单个趋势窗口按钮，负责选中态颜色。
class _RunTrendWindowButton extends StatelessWidget {
  const _RunTrendWindowButton({
    required this.window,
    required this.selected,
    required this.onPressed,
  });

  final _MonitorTrendWindow window;
  final bool selected;
  final VoidCallback onPressed;

  // 渲染固定高度按钮，保证短中文不会影响标题行高度。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: TextButton(
        key: ValueKey('monitor-trend-${window.name}'),
        onPressed: selected ? null : onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          minimumSize: const Size(34, 28),
          foregroundColor: selected
              ? StudioColors.background
              : StudioColors.text,
          backgroundColor: selected ? StudioColors.green : Colors.transparent,
          disabledForegroundColor: StudioColors.background,
          disabledBackgroundColor: StudioColors.green,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Text(_trendWindowShortLabel(window)),
      ),
    );
  }
}
