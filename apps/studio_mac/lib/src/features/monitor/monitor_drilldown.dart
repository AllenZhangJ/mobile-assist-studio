part of '../../studio_mac_workspace.dart';

// Monitor 深挖面板，负责把当前关联运行列表压缩成可扫读摘要。
class _MonitorDrilldownPanel extends StatelessWidget {
  const _MonitorDrilldownPanel({
    required this.label,
    required this.runs,
    required this.onClear,
  });

  final String label;
  final List<RunHistoryEntry> runs;
  final VoidCallback onClear;

  // 渲染本地深挖摘要，只读取运行摘要，不读取详情、截图或底层 payload。
  @override
  Widget build(BuildContext context) {
    final summary = _MonitorDrilldownSummary.fromRuns(runs);
    return DecoratedBox(
      key: const ValueKey('monitor-drilldown-panel'),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.72),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.manage_search_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '深挖摘要 · $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusPill(label: '${runs.length} 条', tone: summary.tone),
                const SizedBox(width: 8),
                TextButton.icon(
                  key: const ValueKey('monitor-drilldown-clear'),
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('清除'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MonitorDrilldownMetric(
                  label: '影响',
                  value: '${summary.workflowCount} 流程',
                  tone: StudioStatusTone.running,
                ),
                _MonitorDrilldownMetric(
                  label: '问题',
                  value: '${summary.issueCount}',
                  tone: summary.issueCount == 0
                      ? StudioStatusTone.ready
                      : StudioStatusTone.warning,
                ),
                _MonitorDrilldownMetric(
                  label: '完成',
                  value: '${summary.completedCount}',
                  tone: StudioStatusTone.ready,
                ),
                _MonitorDrilldownMetric(
                  label: '最近',
                  value: summary.recentLabel,
                  tone: StudioStatusTone.offline,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              summary.workflowNamesLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted, height: 1.35),
            ),
          ],
        ),
      ),
    );
  }
}

// 深挖面板指标块，保持和 Monitor 其它短指标一致的紧凑表达。
class _MonitorDrilldownMetric extends StatelessWidget {
  const _MonitorDrilldownMetric({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;

  // 渲染单个深挖指标，固定宽度避免中文文案撑开布局。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);
    return Container(
      width: 118,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
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

// Monitor 深挖摘要模型，集中承载 UI 需要的本地派生字段。
final class _MonitorDrilldownSummary {
  // 创建深挖摘要，调用方传入已计算好的脱敏统计字段。
  const _MonitorDrilldownSummary({
    required this.workflowCount,
    required this.issueCount,
    required this.completedCount,
    required this.recentLabel,
    required this.workflowNamesLabel,
    required this.tone,
  });

  final int workflowCount;
  final int issueCount;
  final int completedCount;
  final String recentLabel;
  final String workflowNamesLabel;
  final StudioStatusTone tone;

  // 从当前关联运行列表派生深挖摘要，不读取运行详情或截图。
  factory _MonitorDrilldownSummary.fromRuns(List<RunHistoryEntry> runs) {
    final workflowNames = runs
        .map((entry) => entry.workflowName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);
    final completedCount = runs
        .where((entry) => _runHistoryStatusLabel(entry.status) == '完成')
        .length;
    final issueCount = runs.length - completedCount;
    final recentAt = runs
        .map((entry) => entry.finishedAt ?? entry.startedAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, value) {
          if (latest == null || value.isAfter(latest)) return value;
          return latest;
        });
    return _MonitorDrilldownSummary(
      workflowCount: workflowNames.length,
      issueCount: issueCount,
      completedCount: completedCount,
      recentLabel: recentAt == null ? '-' : _timeOnly(recentAt),
      workflowNamesLabel: _drilldownWorkflowNamesLabel(workflowNames),
      tone: issueCount == 0 ? StudioStatusTone.ready : StudioStatusTone.warning,
    );
  }
}

// 生成深挖流程名摘要，最多展示三个名称，其余用数量收束。
String _drilldownWorkflowNamesLabel(List<String> workflowNames) {
  if (workflowNames.isEmpty) return '关联流程：无';
  final visible = workflowNames.take(3).join('、');
  final hiddenCount = workflowNames.length - math.min(3, workflowNames.length);
  if (hiddenCount <= 0) return '关联流程：$visible';
  return '关联流程：$visible 等 ${workflowNames.length} 个';
}
