part of '../../studio_mac_workspace.dart';

// 运行详情建议模型，负责把问题分析转换成用户可执行的排查步骤。
final class _RunIssueRecommendation {
  // 创建一条排查建议，所有文案都应短且不暴露底层标识。
  const _RunIssueRecommendation({
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String title;
  final String detail;
  final StudioStatusTone tone;
}

// 从运行分析和指标生成问题定位建议，不读取截图或原始事件 payload。
List<_RunIssueRecommendation> _issueRecommendationsForDetail(
  RunFailureAnalysis analysis,
  RunDetailMetrics metrics,
  List<RunEvidenceEvent> visualEvidenceEvents,
) {
  final recommendations = <_RunIssueRecommendation>[
    _primaryIssueRecommendation(analysis),
  ];
  if (metrics.screenshotEvidenceCount == 0) {
    recommendations.add(
      const _RunIssueRecommendation(
        title: '先补截图',
        detail: '当前没有截图证据，建议在问题节点前加入截图。',
        tone: StudioStatusTone.warning,
      ),
    );
  } else {
    recommendations.add(
      _RunIssueRecommendation(
        title: '看证据',
        detail: '已有 ${metrics.screenshotEvidenceCount} 张截图，可先核对问题前后的画面。',
        tone: StudioStatusTone.running,
      ),
    );
  }
  if (metrics.slowestDuration != null &&
      metrics.slowestDuration! >= const Duration(seconds: 5)) {
    recommendations.add(
      _RunIssueRecommendation(
        title: '查慢点',
        detail:
            '${_slowestNodeLabel(metrics)} 耗时 ${_formatDuration(metrics.slowestDuration)}，建议检查等待或页面加载。',
        tone: StudioStatusTone.warning,
      ),
    );
  }
  if (visualEvidenceEvents.isNotEmpty) {
    recommendations.add(_visualEvidenceRecommendation(visualEvidenceEvents));
  }
  return recommendations.take(4).toList(growable: false);
}

// 根据问题分类生成第一条主建议。
_RunIssueRecommendation _primaryIssueRecommendation(
  RunFailureAnalysis analysis,
) {
  final node = _monitorNodeDisplayLabel(
    label: analysis.failedNodeLabel,
    nodeType: analysis.failedNodeType,
    fallback: '问题节点',
  );
  return switch (analysis.category) {
    'Low Confidence' => _RunIssueRecommendation(
      title: '先看画面',
      detail: '$node 判断不够确定，建议核对截图、规则和阈值。',
      tone: StudioStatusTone.warning,
    ),
    'Paused' => _RunIssueRecommendation(
      title: '人工确认',
      detail: '$node 已暂停，先处理手机上的提示或异常画面。',
      tone: StudioStatusTone.warning,
    ),
    'Timeout' => _RunIssueRecommendation(
      title: '查等待',
      detail: '$node 等待过久，建议增加等待或检查页面是否卡住。',
      tone: StudioStatusTone.warning,
    ),
    'Driver Error' || 'Session Error' => _RunIssueRecommendation(
      title: '重连手机',
      detail: '驱动通道异常，建议先重新连接，再重跑一次。',
      tone: StudioStatusTone.error,
    ),
    'Stopped' => const _RunIssueRecommendation(
      title: '已停止',
      detail: '本次是人为停止，建议确认是否需要从当前流程重跑。',
      tone: StudioStatusTone.warning,
    ),
    'None' => const _RunIssueRecommendation(
      title: '无问题',
      detail: '本次没有记录失败或暂停，可继续查看路径摘要。',
      tone: StudioStatusTone.ready,
    ),
    _ => _RunIssueRecommendation(
      title: '查节点',
      detail: '$node 有异常，建议先看原因、路径和最近事件。',
      tone: StudioStatusTone.error,
    ),
  };
}

// 根据视觉证据生成简短建议。
_RunIssueRecommendation _visualEvidenceRecommendation(
  List<RunEvidenceEvent> events,
) {
  final pausedCount = events
      .where((event) => event.visualEvidence?.result != true)
      .length;
  if (pausedCount == 0) {
    return const _RunIssueRecommendation(
      title: '视觉通过',
      detail: '视觉检查都已通过，问题可能在后续节点。',
      tone: StudioStatusTone.ready,
    );
  }
  return _RunIssueRecommendation(
    title: '查规则',
    detail: '$pausedCount 次视觉检查未通过，建议核对规则和目标画面。',
    tone: StudioStatusTone.warning,
  );
}

// 生成最慢节点短标签，缺失标签时回退节点类型。
String _slowestNodeLabel(RunDetailMetrics metrics) {
  return _monitorNodeDisplayLabel(
    label: metrics.slowestNodeLabel,
    nodeType: metrics.slowestNodeType,
    fallback: '最慢节点',
  );
}
