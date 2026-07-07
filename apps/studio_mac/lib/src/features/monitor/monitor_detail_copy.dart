part of '../../studio_mac_workspace.dart';

// 运行详情复制按钮，负责生成脱敏诊断摘要并写入剪贴板。
class _RunDetailCopyButton extends StatelessWidget {
  const _RunDetailCopyButton({required this.entry, required this.detail});

  final RunHistoryEntry entry;
  final RunDetail? detail;

  // 渲染复制入口；缺少详情时禁用，避免复制弱诊断信息。
  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('copy-run-detail-summary'),
      tooltip: '复制摘要',
      onPressed: detail == null ? null : () => _copySummary(context),
      icon: const Icon(Icons.copy_all_outlined),
    );
  }

  // 复制本地诊断摘要，只包含脱敏聚合字段。
  Future<void> _copySummary(BuildContext context) async {
    final runDetail = detail;
    if (runDetail == null) return;
    await _copyPlainText(
      context,
      text: _runDetailDiagnosticSummary(entry, runDetail),
      message: '已复制摘要。',
    );
  }
}

// 生成运行详情诊断摘要，供用户带到外部排查或交给 AI 阅读。
String _runDetailDiagnosticSummary(RunHistoryEntry entry, RunDetail detail) {
  final analysis = detail.failureAnalysis;
  final metrics = detail.metrics;
  final issueNode = analysis.failedNodeId == null
      ? '无'
      : _monitorNodeDisplayLabel(
          label: analysis.failedNodeLabel,
          nodeType: analysis.failedNodeType,
        );
  final issueType = analysis.failedNodeType == null
      ? '无'
      : _runtimeNodeTypeLabel(analysis.failedNodeType!);
  final reason = _analysisReasonLabel(analysis.reason);
  final category = _analysisCategoryLabel(analysis.category);
  final slowestNode = metrics.slowestNodeId == null
      ? '无'
      : _monitorNodeDisplayLabel(
          label: metrics.slowestNodeLabel,
          nodeType: metrics.slowestNodeType,
        );
  final visualCount = detail.visualEvidenceEvents.length;

  return [
    'iOS Assist Studio 运行摘要',
    '流程：${entry.workflowName}',
    '状态：${_runStatusLabelFromText(entry.status)}',
    '轮次：${entry.completedLoops}/${entry.loops}',
    '时长：${_formatDuration(detail.duration)}',
    '问题类型：$category',
    '问题节点：$issueNode',
    '节点类型：$issueType',
    '原因：$reason',
    '路径：${metrics.completedSteps}/${metrics.totalSteps} 步，问题 ${metrics.issueSteps}，截图 ${metrics.screenshotEvidenceCount}',
    '最慢节点：$slowestNode，耗时 ${_formatDuration(metrics.slowestDuration)}',
    '视觉检查：$visualCount 次',
    '说明：摘要仅包含本地脱敏诊断信息，不含截图、路径、设备标识或底层会话。',
  ].join('\n');
}

// 把运行状态转为短中文，复制文本不暴露底层状态枚举。
String _runStatusLabelFromText(String status) {
  return switch (status) {
    'completed' || '完成' => '完成',
    'failed' || '失败' => '失败',
    'paused' || '暂停' => '暂停',
    'stopped' || '已停' => '已停',
    'running' || '运行中' => '运行中',
    _ => status,
  };
}
