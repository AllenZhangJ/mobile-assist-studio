part of '../../studio_mac_workspace.dart';

// 耗时趋势深挖面板，负责解释单个节点最近 7 日耗时变化。
class _MonitorDurationTrendDrilldownPanel extends StatelessWidget {
  const _MonitorDurationTrendDrilldownPanel({required this.trend});

  final RunNodeDurationTrend trend;

  // 渲染趋势深挖摘要，只消费 Runtime 已聚合的趋势点。
  @override
  Widget build(BuildContext context) {
    final summary = _MonitorDurationTrendSummary.fromTrend(trend);
    final title = _nodeDurationTrendLabel(trend);
    return DecoratedBox(
      key: const ValueKey('monitor-duration-drilldown-panel'),
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.5),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.query_stats_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '耗时深挖 · $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusPill(
                  label: '${summary.sampleCount} 样本',
                  tone: summary.tone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MonitorDurationTrendMetric(
                  label: '峰值日',
                  value: summary.peakDayLabel,
                  tone: StudioStatusTone.warning,
                ),
                _MonitorDurationTrendMetric(
                  label: '峰值',
                  value: summary.peakDurationLabel,
                  tone: StudioStatusTone.warning,
                ),
                _MonitorDurationTrendMetric(
                  label: '问题日',
                  value: '${summary.issueDayCount}',
                  tone: summary.issueDayCount == 0
                      ? StudioStatusTone.ready
                      : StudioStatusTone.warning,
                ),
                _MonitorDurationTrendMetric(
                  label: '最近',
                  value: summary.latestSampleDayLabel,
                  tone: StudioStatusTone.offline,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MonitorDurationTrendPointStrip(points: trend.points),
          ],
        ),
      ),
    );
  }
}

// 耗时趋势深挖指标块，统一展示短标题和值。
class _MonitorDurationTrendMetric extends StatelessWidget {
  const _MonitorDurationTrendMetric({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;

  // 渲染固定宽度指标，避免日期和耗时文案撑开面板。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);
    return Container(
      width: 112,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, fontSize: 11),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// 趋势点条，展示最近几天是否有样本和问题。
class _MonitorDurationTrendPointStrip extends StatelessWidget {
  const _MonitorDurationTrendPointStrip({required this.points});

  final List<RunNodeDurationTrendPoint> points;

  // 渲染每日小块，保留日期、耗时和样本数。
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Text('暂无趋势点', style: TextStyle(color: StudioColors.muted));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final point in points)
          _MonitorDurationTrendPointChip(point: point),
      ],
    );
  }
}

// 单日趋势点，使用提醒色标记有问题样本的日期。
class _MonitorDurationTrendPointChip extends StatelessWidget {
  const _MonitorDurationTrendPointChip({required this.point});

  final RunNodeDurationTrendPoint point;

  // 渲染单个日期的耗时摘要，不展示任何运行 id 或路径。
  @override
  Widget build(BuildContext context) {
    final hasIssue = point.issueCount > 0;
    final color = hasIssue ? StudioColors.amber : StudioColors.cyan;
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: hasIssue ? 0.12 : 0.08),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _trendDayLabel(point.day),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: StudioColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDuration(point.averageDuration),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            '${point.sampleCount} 次${hasIssue ? ' · 问题' : ''}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: hasIssue ? StudioColors.amber : StudioColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
