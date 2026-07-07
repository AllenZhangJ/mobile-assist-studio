part of '../../studio_mac_workspace.dart';

// 失败趋势面板，负责把本地历史中的失败、暂停和停止聚合为可扫读图表。
class _FailureTrendPanel extends StatelessWidget {
  const _FailureTrendPanel({required this.history, required this.selected});

  final RunHistorySummary history;
  final _MonitorTrendWindow selected;

  // 渲染失败趋势卡片，窗口跟随主趋势选择，避免用户重复配置。
  @override
  Widget build(BuildContext context) {
    final days = _trendRunsForWindow(history, selected);
    final totals = _FailureTrendTotals.fromDays(days);
    return _Surface(
      child: SizedBox(
        height: 174,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FailureTrendHeader(selected: selected, totals: totals),
            const SizedBox(height: 12),
            Expanded(
              child: _FailureTrendChart(days: days, totals: totals),
            ),
          ],
        ),
      ),
    );
  }
}

// 失败趋势头部，承载标题、状态和短摘要。
class _FailureTrendHeader extends StatelessWidget {
  const _FailureTrendHeader({required this.selected, required this.totals});

  final _MonitorTrendWindow selected;
  final _FailureTrendTotals totals;

  // 以短中文展示当前窗口的问题总览。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Text(
              '失败趋势',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            StatusPill(
              label: totals.issueRuns == 0
                  ? '暂无失败'
                  : _trendWindowShortLabel(selected),
              tone: totals.issueRuns == 0
                  ? StudioStatusTone.ready
                  : StudioStatusTone.warning,
            ),
            const SizedBox(width: 8),
            _FailureTrendChip(
              label: '失败',
              value: totals.failedRuns,
              color: StudioColors.red,
            ),
            const SizedBox(width: 8),
            _FailureTrendChip(
              label: '暂停',
              value: totals.pausedRuns,
              color: StudioColors.amber,
            ),
            const SizedBox(width: 8),
            _FailureTrendChip(
              label: '已停',
              value: totals.stoppedRuns,
              color: StudioColors.cyan,
            ),
          ],
        ),
      ),
    );
  }
}

// 失败趋势摘要胶囊，用于展示某类问题的总次数。
class _FailureTrendChip extends StatelessWidget {
  const _FailureTrendChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  // 渲染固定高度胶囊，确保短中文不会撑高标题行。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        '$label $value',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
