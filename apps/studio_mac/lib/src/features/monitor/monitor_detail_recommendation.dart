part of '../../studio_mac_workspace.dart';

// 运行详情建议面板，负责把分析结果呈现为下一步动作。
class _RunIssueRecommendationPanel extends StatelessWidget {
  const _RunIssueRecommendationPanel({
    required this.analysis,
    required this.metrics,
    required this.visualEvidenceEvents,
  });

  final RunFailureAnalysis analysis;
  final RunDetailMetrics metrics;
  final List<RunEvidenceEvent> visualEvidenceEvents;

  // 渲染建议列表，只读展示，不触发设备动作或读取截图。
  @override
  Widget build(BuildContext context) {
    final recommendations = _issueRecommendationsForDetail(
      analysis,
      metrics,
      visualEvidenceEvents,
    );
    return _InsetSurface(
      key: const ValueKey('run-issue-recommendations'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '处理建议',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: '${recommendations.length} 条',
                tone:
                    recommendations.any(
                      (item) => item.tone == StudioStatusTone.error,
                    )
                    ? StudioStatusTone.error
                    : StudioStatusTone.running,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final recommendation in recommendations) ...[
            _RunIssueRecommendationRow(recommendation: recommendation),
            if (recommendation != recommendations.last)
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// 单条处理建议，保持短中文和固定视觉密度。
class _RunIssueRecommendationRow extends StatelessWidget {
  const _RunIssueRecommendationRow({required this.recommendation});

  final _RunIssueRecommendation recommendation;

  // 渲染建议标题和说明，长说明会省略以保护抽屉布局。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(recommendation.tone);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.26)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right_alt, size: 18, color: color),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              recommendation.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              recommendation.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
