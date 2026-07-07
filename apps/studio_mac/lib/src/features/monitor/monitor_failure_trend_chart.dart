part of '../../studio_mac_workspace.dart';

// 失败趋势图表组件，负责把失败、暂停和停止按天绘制为堆叠柱。

// 失败趋势图表，负责把日聚合数据绘制为堆叠柱。
class _FailureTrendChart extends StatelessWidget {
  const _FailureTrendChart({required this.days, required this.totals});

  final List<RunHistoryDay> days;
  final _FailureTrendTotals totals;

  // 根据是否有问题记录切换空态或柱状图。
  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: StudioColors.muted)),
      );
    }
    if (totals.issueRuns == 0) {
      return const Center(
        child: Text('暂无失败', style: TextStyle(color: StudioColors.muted)),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days) ...[
          Expanded(
            child: _FailureTrendDayBar(day: day, maxIssues: totals.maxIssues),
          ),
          if (day != days.last) SizedBox(width: _trendBarGap(days.length)),
        ],
      ],
    );
  }
}

// 单日失败趋势柱，按失败、暂停、停止三个来源堆叠。
class _FailureTrendDayBar extends StatelessWidget {
  const _FailureTrendDayBar({required this.day, required this.maxIssues});

  final RunHistoryDay day;
  final int maxIssues;

  // 按父级高度压缩标签，保证 90 日窗口仍能稳定显示。
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 72;
        final issueRuns = day.issueRuns;
        final ratio = maxIssues == 0 ? 0.0 : issueRuns / maxIssues;
        final maxBarHeight = compact ? 34.0 : 52.0;
        final totalHeight = math.max(5.0, maxBarHeight * ratio);
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!compact) ...[
              Text(
                '$issueRuns',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudioColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
            ],
            _FailureTrendStackedBar(day: day, totalHeight: totalHeight),
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

// 失败趋势堆叠柱主体，零值时保留微弱占位便于扫读时间轴。
class _FailureTrendStackedBar extends StatelessWidget {
  const _FailureTrendStackedBar({required this.day, required this.totalHeight});

  final RunHistoryDay day;
  final double totalHeight;

  // 渲染三个问题类型的垂直堆叠片段。
  @override
  Widget build(BuildContext context) {
    final issueRuns = day.issueRuns;
    final contentHeight = math.max(3.0, totalHeight - 2);
    if (issueRuns == 0) {
      return Container(
        height: totalHeight,
        constraints: const BoxConstraints(minWidth: 3),
        decoration: BoxDecoration(
          color: StudioColors.border.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }
    return Container(
      height: totalHeight,
      constraints: const BoxConstraints(minWidth: 3),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: StudioColors.panelSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: StudioColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _FailureTrendSegment(
            value: day.failedRuns,
            total: issueRuns,
            height: contentHeight,
            color: StudioColors.red,
          ),
          _FailureTrendSegment(
            value: day.pausedRuns,
            total: issueRuns,
            height: contentHeight,
            color: StudioColors.amber,
          ),
          _FailureTrendSegment(
            value: day.stoppedRuns,
            total: issueRuns,
            height: contentHeight,
            color: StudioColors.cyan,
          ),
        ],
      ),
    );
  }
}

// 失败趋势堆叠片段，负责按占比换算高度。
class _FailureTrendSegment extends StatelessWidget {
  const _FailureTrendSegment({
    required this.value,
    required this.total,
    required this.height,
    required this.color,
  });

  final int value;
  final int total;
  final double height;
  final Color color;

  // 零值不渲染，非零值保留最小高度避免单次问题不可见。
  @override
  Widget build(BuildContext context) {
    if (value == 0 || total == 0) return const SizedBox.shrink();
    final segmentHeight = math.max(1.0, height * value / total);
    return Container(
      height: segmentHeight,
      color: color.withValues(alpha: 0.88),
    );
  }
}
