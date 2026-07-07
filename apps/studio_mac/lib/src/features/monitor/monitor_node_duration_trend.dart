part of '../../studio_mac_workspace.dart';

// 节点耗时趋势面板，负责展示 Runtime 聚合出的跨日期耗时变化。
class _NodeDurationTrendPanel extends StatelessWidget {
  const _NodeDurationTrendPanel({
    required this.history,
    required this.onShowRuns,
  });

  final RunHistorySummary history;
  final ValueChanged<RunNodeDurationTrend> onShowRuns;

  // 渲染节点耗时趋势，空态保持简短并避免技术细节外露。
  @override
  Widget build(BuildContext context) {
    final trends = history.nodeDurationTrends;
    return _Surface(
      child: SizedBox(
        height: 174,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.show_chart_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '耗时趋势',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(
                  label: trends.isEmpty ? '暂无数据' : '${trends.length} 项',
                  tone: trends.isEmpty
                      ? StudioStatusTone.offline
                      : StudioStatusTone.running,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (trends.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    '暂无趋势',
                    style: TextStyle(color: StudioColors.muted),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: math.min(2, trends.length),
                  separatorBuilder: (_, _) =>
                      const Divider(color: StudioColors.border, height: 12),
                  itemBuilder: (context, index) {
                    return _NodeDurationTrendRow(
                      trend: trends[index],
                      onShowRuns: onShowRuns,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 单个节点耗时趋势行，展示短标题、趋势柱和摘要指标。
class _NodeDurationTrendRow extends StatelessWidget {
  const _NodeDurationTrendRow({required this.trend, required this.onShowRuns});

  final RunNodeDurationTrend trend;
  final ValueChanged<RunNodeDurationTrend> onShowRuns;

  // 将节点趋势压缩为一行，保证 Monitor 概览可扫读。
  @override
  Widget build(BuildContext context) {
    final label = _nodeDurationTrendLabel(trend);
    return Row(
      key: ValueKey('node-duration-trend-${trend.nodeId}'),
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(flex: 5, child: _NodeDurationTrendBars(trend: trend)),
        const SizedBox(width: 12),
        _MonitorCompactMetric(
          label: '均',
          value: _formatDuration(trend.averageDuration),
          width: 50,
        ),
        const SizedBox(width: 8),
        _MonitorCompactMetric(
          label: '峰',
          value: _formatDuration(trend.maxDuration),
          width: 50,
        ),
        const SizedBox(width: 8),
        _MonitorCompactMetric(
          label: '样本',
          value: '${trend.sampleCount}',
          width: 50,
        ),
        const SizedBox(width: 4),
        IconButton(
          key: ValueKey('node-duration-trend-runs-${trend.nodeId}'),
          tooltip: '看记录',
          onPressed: trend.relatedRuns.isEmpty ? null : () => onShowRuns(trend),
          icon: const Icon(Icons.manage_search_outlined, size: 17),
        ),
      ],
    );
  }
}

// 生成耗时趋势短标题，缺失标签时回退节点类型。
String _nodeDurationTrendLabel(RunNodeDurationTrend trend) {
  return _monitorNodeDisplayLabel(label: trend.label, nodeType: trend.nodeType);
}

// 节点耗时趋势柱组，按日平均耗时绘制固定宽度微图。
class _NodeDurationTrendBars extends StatelessWidget {
  const _NodeDurationTrendBars({required this.trend});

  final RunNodeDurationTrend trend;

  // 渲染 7 日趋势柱，问题日使用提醒色。
  @override
  Widget build(BuildContext context) {
    final maxMicros = trend.points.fold<int>(0, (value, point) {
      return math.max(value, point.averageDuration?.inMicroseconds ?? 0);
    });
    return SizedBox(
      height: 42,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in trend.points) ...[
            Expanded(
              child: _NodeDurationTrendBar(
                point: point,
                maxMicroseconds: maxMicros,
              ),
            ),
            if (point != trend.points.last) const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

// 单日节点耗时趋势柱，空样本保留弱占位。
class _NodeDurationTrendBar extends StatelessWidget {
  const _NodeDurationTrendBar({
    required this.point,
    required this.maxMicroseconds,
  });

  final RunNodeDurationTrendPoint point;
  final int maxMicroseconds;

  // 根据当天平均耗时映射柱高，并用颜色提示问题样本。
  @override
  Widget build(BuildContext context) {
    final duration = point.averageDuration;
    final ratio = duration == null || maxMicroseconds <= 0
        ? 0.0
        : duration.inMicroseconds / maxMicroseconds;
    final height = duration == null ? 5.0 : math.max(6.0, 38.0 * ratio);
    final color = point.issueCount > 0 ? StudioColors.amber : StudioColors.cyan;
    return Tooltip(
      message:
          '${_trendDayLabel(point.day)} ${_formatDuration(duration)} · ${point.sampleCount} 次',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: duration == null
              ? StudioColors.border.withValues(alpha: 0.52)
              : color.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: StudioColors.border),
        ),
      ),
    );
  }
}
