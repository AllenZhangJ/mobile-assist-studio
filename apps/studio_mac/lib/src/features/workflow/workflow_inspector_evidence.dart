part of '../../studio_mac_workspace.dart';

// 节点 Inspector 的最近留档卡，只展示 Runtime 聚合摘要。
class _NodeInspectorEvidenceCard extends StatelessWidget {
  const _NodeInspectorEvidenceCard({
    required this.summary,
    required this.loading,
    required this.latestRun,
    required this.onOpenMonitor,
  });

  final _WorkflowNodeEvidenceSummary? summary;
  final bool loading;
  final RunHistoryEntry? latestRun;
  final VoidCallback? onOpenMonitor;

  // 渲染节点级留档入口；详情仍统一交给记录页。
  @override
  Widget build(BuildContext context) {
    final summary = this.summary;
    final latestRun = this.latestRun;
    final hasSummary = summary != null;
    return DecoratedBox(
      key: const ValueKey('node-inspector-evidence-card'),
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
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
                const Expanded(
                  child: Text(
                    '上次留档',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(
                  label: loading
                      ? '读取中'
                      : hasSummary
                      ? summary.badgeLabel
                      : '无',
                  tone: loading
                      ? StudioStatusTone.running
                      : hasSummary
                      ? summary.badgeTone
                      : StudioStatusTone.offline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hasSummary
                  ? '${summary.summaryLine} · ${summary.latestStatusLabel}'
                  : latestRun == null
                  ? '暂无记录'
                  : '此节点暂无留档',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('node-inspector-open-monitor'),
                onPressed: latestRun == null ? null : onOpenMonitor,
                icon: const Icon(Icons.monitor_heart_outlined, size: 16),
                label: const Text('看记录'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
