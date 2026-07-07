part of '../../studio_mac_workspace.dart';

// 节点耗时面板，独立承载 Monitor 的慢节点聚合展示。
class _RunNodeDurationPanel extends StatelessWidget {
  const _RunNodeDurationPanel({
    required this.history,
    required this.onShowRuns,
  });

  final RunHistorySummary history;
  final ValueChanged<RunNodeDurationStat> onShowRuns;

  // 根据本地历史摘要渲染慢节点列表，空态保持简短可懂。
  @override
  Widget build(BuildContext context) {
    final stats = history.nodeDurationStats;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '耗时节点',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: stats.isEmpty ? '暂无数据' : '${stats.length} 项',
                tone: stats.isEmpty
                    ? StudioStatusTone.offline
                    : StudioStatusTone.running,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (stats.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  '暂无耗时',
                  style: TextStyle(color: StudioColors.muted),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(4, stats.length),
                separatorBuilder: (_, _) =>
                    const Divider(color: StudioColors.border, height: 12),
                itemBuilder: (context, index) {
                  return _NodeDurationRow(
                    stat: stats[index],
                    rank: index + 1,
                    maxAverageDuration: stats.first.averageDuration,
                    onShowRuns: onShowRuns,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// 单个耗时节点行，负责进度条比例与指标摘要。
class _NodeDurationRow extends StatelessWidget {
  const _NodeDurationRow({
    required this.stat,
    required this.rank,
    required this.maxAverageDuration,
    required this.onShowRuns,
  });

  final RunNodeDurationStat stat;
  final int rank;
  final Duration maxAverageDuration;
  final ValueChanged<RunNodeDurationStat> onShowRuns;

  // 将平均耗时映射为稳定宽度的条形展示，避免文字撑开布局。
  @override
  Widget build(BuildContext context) {
    final label = _nodeDurationLabel(stat);
    final ratio = _nodeDurationRatio(stat, maxAverageDuration);
    final tone = stat.issueCount == 0
        ? StudioStatusTone.running
        : StudioStatusTone.warning;
    final content = Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            '#$rank',
            style: const TextStyle(
              color: StudioColors.muted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: ratio,
                  color: _colorForTone(tone),
                  backgroundColor: StudioColors.background.withValues(
                    alpha: 0.64,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _MonitorCompactMetric(
          label: '均',
          value: _formatDuration(stat.averageDuration),
        ),
        const SizedBox(width: 8),
        _MonitorCompactMetric(
          label: '峰',
          value: _formatDuration(stat.maxDuration),
        ),
        const SizedBox(width: 8),
        _MonitorCompactMetric(label: '样本', value: '${stat.sampleCount}'),
        const SizedBox(width: 8),
        _MonitorCompactMetric(label: '问题', value: '${stat.issueCount}'),
      ],
    );
    if (stat.relatedRuns.isEmpty) {
      return KeyedSubtree(
        key: ValueKey('node-duration-row-${stat.nodeId}'),
        child: content,
      );
    }
    return Tooltip(
      message: '看记录',
      child: InkWell(
        key: ValueKey('node-duration-runs-${stat.nodeId}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => onShowRuns(stat),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: content,
        ),
      ),
    );
  }
}

// 生成耗时节点短标题，缺失标签时回退节点类型。
String _nodeDurationLabel(RunNodeDurationStat stat) {
  return _monitorNodeDisplayLabel(label: stat.label, nodeType: stat.nodeType);
}

// 计算节点耗时条比例，保留最小可见宽度。
double _nodeDurationRatio(
  RunNodeDurationStat stat,
  Duration maxAverageDuration,
) {
  if (maxAverageDuration.inMicroseconds <= 0) return 0.05;
  final raw =
      stat.averageDuration.inMicroseconds / maxAverageDuration.inMicroseconds;
  return raw.clamp(0.05, 1.0).toDouble();
}
