part of '../../studio_mac_workspace.dart';

// Workflow 节点留档摘要，来自最近一次 RunDetail 聚合。
// 它只保存计数和状态，不保存截图路径或本机 evidence 路径。
final class _WorkflowNodeEvidenceSummary {
  const _WorkflowNodeEvidenceSummary({
    required this.runId,
    required this.nodeId,
    required this.traceCount,
    required this.screenshotCount,
    required this.visualCount,
    required this.issueCount,
    required this.latestStatus,
  });

  final String runId;
  final String nodeId;
  final int traceCount;
  final int screenshotCount;
  final int visualCount;
  final int issueCount;
  final String latestStatus;

  // 是否存在任何可追溯留档。
  bool get hasEvidence => traceCount > 0 || visualCount > 0;

  // 是否存在失败或暂停类问题。
  bool get hasIssue => issueCount > 0;

  // 画布节点上的极短标记，避免撑开节点卡片。
  String get badgeLabel {
    if (hasIssue) return '问题';
    if (screenshotCount > 0) return '截图';
    if (visualCount > 0) return '视觉';
    return '留档';
  }

  // 画布节点上的状态色。
  StudioStatusTone get badgeTone {
    if (hasIssue) return StudioStatusTone.warning;
    if (screenshotCount > 0 || visualCount > 0) return StudioStatusTone.ready;
    return StudioStatusTone.running;
  }

  // Inspector 卡片中的最近状态，复用 Monitor 的短中文状态。
  String get latestStatusLabel => _runTraceStatusLabelForStatus(latestStatus);

  // Inspector 卡片中的一行摘要。
  String get summaryLine {
    final parts = <String>[
      '$traceCount 步',
      if (screenshotCount > 0) '$screenshotCount 图',
      if (visualCount > 0) '$visualCount 视觉',
      if (issueCount > 0) '$issueCount 问题',
    ];
    return parts.join(' · ');
  }
}

// 从 RunDetail 生成按节点聚合的留档摘要。
Map<String, _WorkflowNodeEvidenceSummary> _workflowNodeEvidenceByNodeId(
  RunDetail detail,
) {
  final builders = <String, _WorkflowNodeEvidenceBuilder>{};

  _WorkflowNodeEvidenceBuilder builderFor(String nodeId) {
    return builders.putIfAbsent(
      nodeId,
      () => _WorkflowNodeEvidenceBuilder(
        runId: detail.entry.runId,
        nodeId: nodeId,
      ),
    );
  }

  for (final trace in detail.nodeTraces) {
    builderFor(trace.nodeId).addTrace(trace);
  }
  for (final event in detail.visualEvidenceEvents) {
    final nodeId = event.nodeId;
    if (nodeId == null || nodeId.trim().isEmpty) continue;
    builderFor(nodeId).addVisualEvidence(event);
  }

  return Map<String, _WorkflowNodeEvidenceSummary>.unmodifiable({
    for (final entry in builders.entries) entry.key: entry.value.build(),
  });
}

// 聚合单个节点的最近运行留档。
final class _WorkflowNodeEvidenceBuilder {
  _WorkflowNodeEvidenceBuilder({required this.runId, required this.nodeId});

  final String runId;
  final String nodeId;
  int traceCount = 0;
  int screenshotCount = 0;
  int visualCount = 0;
  int issueCount = 0;
  String latestStatus = 'unknown';

  // 合并节点轨迹，状态与截图只保留聚合结果。
  void addTrace(RunNodeTrace trace) {
    traceCount += 1;
    latestStatus = trace.status;
    if (trace.screenshotPath != null) screenshotCount += 1;
    if (_workflowTraceHasIssue(trace)) issueCount += 1;
  }

  // 合并视觉证据事件，不读取截图内容。
  void addVisualEvidence(RunEvidenceEvent event) {
    visualCount += 1;
    final status = event.status;
    if (status != null && status.trim().isNotEmpty) {
      latestStatus = status;
    }
    if (_workflowEventHasIssue(event)) issueCount += 1;
  }

  // 输出不可变摘要。
  _WorkflowNodeEvidenceSummary build() {
    return _WorkflowNodeEvidenceSummary(
      runId: runId,
      nodeId: nodeId,
      traceCount: traceCount,
      screenshotCount: screenshotCount,
      visualCount: visualCount,
      issueCount: issueCount,
      latestStatus: latestStatus,
    );
  }
}

// 兼容 Runtime 英文状态和 UI 中文状态，避免问题节点漏标。
bool _workflowTraceHasIssue(RunNodeTrace trace) {
  return trace.error != null || _workflowStatusHasIssue(trace.status);
}

// 兼容 Runtime 英文状态和 UI 中文状态，避免视觉事件漏标。
bool _workflowEventHasIssue(RunEvidenceEvent event) {
  return event.error != null || _workflowStatusHasIssue(event.status);
}

// 判断状态是否代表人工介入或失败。
bool _workflowStatusHasIssue(String? status) {
  return status == 'failed' ||
      status == '失败' ||
      status == 'paused' ||
      status == '暂停' ||
      status == 'stopped' ||
      status == '已停';
}
