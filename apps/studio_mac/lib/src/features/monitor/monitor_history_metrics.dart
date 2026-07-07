part of '../../studio_mac_workspace.dart';

// 监控 KPI 网格，负责把本地运行摘要转成用户可读的短指标。
class _MonitorMetricGrid extends StatelessWidget {
  const _MonitorMetricGrid({required this.history});

  final RunHistorySummary history;

  // 根据当前工作区宽度生成紧凑 KPI 排布，避免中文指标挤出首屏。
  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        label: '总数',
        value: '${history.totalRuns}',
        tone: history.totalRuns == 0
            ? StudioStatusTone.offline
            : StudioStatusTone.ready,
      ),
      (
        label: '成功率',
        value: _formatPercent(history.successRate),
        tone: history.successRate >= 0.95
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
      ),
      (
        label: '均耗时',
        value: _formatDuration(history.averageDuration),
        tone: history.averageDuration == null
            ? StudioStatusTone.offline
            : StudioStatusTone.running,
      ),
      (
        label: '失败',
        value: '${history.failedRuns}',
        tone: history.failedRuns == 0
            ? StudioStatusTone.ready
            : StudioStatusTone.error,
      ),
      (
        label: '暂停',
        value: '${history.pausedRuns}',
        tone: history.pausedRuns == 0
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
      ),
      (
        label: '已停',
        value: '${history.stoppedRuns}',
        tone: history.stoppedRuns == 0
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1120
            ? 6
            : constraints.maxWidth >= 520
            ? 3
            : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: _HistoryMetricCard(
                  label: metric.label,
                  value: metric.value,
                  tone: metric.tone,
                ),
              ),
          ],
        );
      },
    );
  }
}

// 单个监控指标条，负责展示短标签、状态色和值。
class _HistoryMetricCard extends StatelessWidget {
  const _HistoryMetricCard({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;

  // 渲染低高度指标条，保证小窗口下不撑开监控页。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panelSoft,
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Flexible(
              child: StatusPill(label: label, tone: tone),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
