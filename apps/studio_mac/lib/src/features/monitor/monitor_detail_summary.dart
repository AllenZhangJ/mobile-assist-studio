part of '../../studio_mac_workspace.dart';

// Monitor 运行详情摘要分片，负责基础摘要、指标 chip 和路径摘要。
class _RunDetailSummary extends StatelessWidget {
  const _RunDetailSummary({required this.entry, required this.detail});

  final RunHistoryEntry entry;
  final RunDetail? detail;

  // 渲染运行详情顶部摘要，只展示脱敏后的轮次、耗时和问题原因。
  @override
  Widget build(BuildContext context) {
    final failureReason = detail?.failureReason;
    final issueNodeLabel = detail == null
        ? null
        : _monitorNodeDisplayLabel(
            label: detail!.failureAnalysis.failedNodeLabel,
            nodeType: detail!.failureAnalysis.failedNodeType,
            fallback: '节点',
          );
    final hasIssueNode =
        detail?.failedNodeId != null || detail?.pausedNodeId != null;
    final issueTone = entry.status == '暂停'
        ? StudioStatusTone.warning
        : StudioStatusTone.error;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _RunDetailChip(
          label: '轮',
          value: '${entry.completedLoops}/${entry.loops}',
          tone: StudioStatusTone.running,
        ),
        _RunDetailChip(
          label: '时长',
          value: _formatDuration(detail?.duration),
          tone: StudioStatusTone.offline,
        ),
        _RunDetailChip(
          label: '问题节点',
          value: hasIssueNode ? issueNodeLabel ?? '节点' : '无',
          tone: hasIssueNode ? issueTone : StudioStatusTone.ready,
        ),
        _RunDetailChip(
          label: '原因',
          value: failureReason ?? '无',
          tone: failureReason == null ? StudioStatusTone.ready : issueTone,
        ),
      ],
    );
  }
}

class _RunDetailChip extends StatelessWidget {
  const _RunDetailChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;

  // 渲染运行详情里的紧凑指标块，统一尺寸和文本溢出。
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 136, maxWidth: 310),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.46),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(label: label, tone: tone),
          const SizedBox(height: 8),
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RunExecutionMetricsPanel extends StatelessWidget {
  const _RunExecutionMetricsPanel({required this.metrics});

  final RunDetailMetrics metrics;

  // 渲染执行路径摘要，所有数据都来自本地 RunDetail 聚合。
  @override
  Widget build(BuildContext context) {
    final slowestNodes = metrics.slowestNodeId == null
        ? '无'
        : _monitorNodeDisplayLabel(
            label: metrics.slowestNodeLabel,
            nodeType: metrics.slowestNodeType,
          );
    return _InsetSurface(
      key: const ValueKey('run-execution-metrics'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline_outlined, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '路径摘要',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RunDetailChip(
                label: '步数',
                value: '${metrics.completedSteps}/${metrics.totalSteps}',
                tone: metrics.totalSteps == 0
                    ? StudioStatusTone.offline
                    : StudioStatusTone.ready,
              ),
              _RunDetailChip(
                label: '问题',
                value: '${metrics.issueSteps}',
                tone: metrics.issueSteps == 0
                    ? StudioStatusTone.ready
                    : StudioStatusTone.warning,
              ),
              _RunDetailChip(
                label: '截图',
                value: '${metrics.screenshotEvidenceCount}',
                tone: metrics.screenshotEvidenceCount == 0
                    ? StudioStatusTone.offline
                    : StudioStatusTone.running,
              ),
              _RunDetailChip(
                label: '最慢节点',
                value: slowestNodes,
                tone: metrics.slowestNodeId == null
                    ? StudioStatusTone.offline
                    : StudioStatusTone.warning,
              ),
              _RunDetailChip(
                label: '最慢耗时',
                value: _formatDuration(metrics.slowestDuration),
                tone: metrics.slowestDuration == null
                    ? StudioStatusTone.offline
                    : StudioStatusTone.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
