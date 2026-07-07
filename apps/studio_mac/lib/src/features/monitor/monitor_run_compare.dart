part of '../../studio_mac_workspace.dart';

// 跨运行对比面板，负责解释关联记录之间的状态变化。
class _MonitorRunComparePanel extends StatelessWidget {
  const _MonitorRunComparePanel({required this.runs});

  final List<RunHistoryEntry> runs;

  // 渲染跨运行对比，只消费本地运行摘要，不读取详情或截图。
  @override
  Widget build(BuildContext context) {
    final summary = _MonitorRunCompareSummary.fromRuns(runs);
    return DecoratedBox(
      key: const ValueKey('monitor-run-compare-panel'),
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.44),
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
                const Icon(Icons.compare_arrows_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '运行对比',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(
                  label: summary.issueStreakCount == 0
                      ? '无连续问题'
                      : '${summary.issueStreakCount} 连续问题',
                  tone: summary.tone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MonitorDrilldownMetric(
                  label: '完成',
                  value: '${summary.completedCount}',
                  tone: StudioStatusTone.ready,
                ),
                _MonitorDrilldownMetric(
                  label: '失败',
                  value: '${summary.failedCount}',
                  tone: summary.failedCount == 0
                      ? StudioStatusTone.offline
                      : StudioStatusTone.error,
                ),
                _MonitorDrilldownMetric(
                  label: '暂停',
                  value: '${summary.pausedCount}',
                  tone: summary.pausedCount == 0
                      ? StudioStatusTone.offline
                      : StudioStatusTone.warning,
                ),
                _MonitorDrilldownMetric(
                  label: '已停',
                  value: '${summary.stoppedCount}',
                  tone: summary.stoppedCount == 0
                      ? StudioStatusTone.offline
                      : StudioStatusTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MonitorRunCompareFactRow(
              label: '最近变化',
              value: summary.recentChangeLabel,
            ),
            const SizedBox(height: 6),
            _MonitorRunCompareFactRow(
              label: '最近记录',
              value: summary.latestRunLabel,
            ),
            if (summary.timelineItems.isNotEmpty) ...[
              const SizedBox(height: 10),
              _MonitorRunCompareTimeline(items: summary.timelineItems),
            ],
          ],
        ),
      ),
    );
  }
}

// 运行对比事实行，用于展示最近变化和最近记录。
class _MonitorRunCompareFactRow extends StatelessWidget {
  const _MonitorRunCompareFactRow({required this.label, required this.value});

  final String label;
  final String value;

  // 渲染一条紧凑事实，长流程名会省略避免撑开布局。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// 运行对比时间线，展示最近几条关联运行的状态路径。
class _MonitorRunCompareTimeline extends StatelessWidget {
  const _MonitorRunCompareTimeline({required this.items});

  final List<_MonitorRunCompareTimelineItem> items;

  // 渲染脱敏时间线 chip，不展示 run id 或本地路径。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items) _MonitorRunCompareTimelineChip(item: item),
      ],
    );
  }
}

// 单条运行时间线 chip，使用状态色帮助快速扫读。
class _MonitorRunCompareTimelineChip extends StatelessWidget {
  const _MonitorRunCompareTimelineChip({required this.item});

  final _MonitorRunCompareTimelineItem item;

  // 渲染单次运行摘要，只包含流程名、状态和短时间。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(item.tone);
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${item.workflowName} · ${item.statusLabel} · ${item.timeLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
