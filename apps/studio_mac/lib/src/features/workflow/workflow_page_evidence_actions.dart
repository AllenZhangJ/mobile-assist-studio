part of '../../studio_mac_workspace.dart';

// Workflow 页面最近运行留档动作，负责从 Runtime 读取轻量节点索引。
extension _WorkflowPageEvidenceActions on _WorkflowPageState {
  // 读取最近一次运行详情，并聚合为画布节点可消费的留档摘要。
  Future<void> _refreshWorkflowNodeEvidence() async {
    final latestRun = _latestWorkflowRunEntry;
    if (latestRun == null) {
      if (_latestNodeEvidenceKey != null ||
          _latestNodeEvidenceByNodeId.isNotEmpty ||
          _loadingLatestNodeEvidence) {
        _latestNodeEvidenceRequestToken += 1;
        _updateWorkflowPageState(() {
          _latestNodeEvidenceKey = null;
          _latestNodeEvidenceByNodeId = const {};
          _loadingLatestNodeEvidence = false;
        });
      }
      return;
    }

    final key = _workflowNodeEvidenceKey(latestRun);
    if (_latestNodeEvidenceKey == key) return;

    final requestToken = _latestNodeEvidenceRequestToken + 1;
    _latestNodeEvidenceRequestToken = requestToken;
    _updateWorkflowPageState(() {
      _latestNodeEvidenceKey = key;
      _loadingLatestNodeEvidence = true;
    });

    final detail = await widget.controller.readRunDetail(latestRun.runId);
    if (!mounted || requestToken != _latestNodeEvidenceRequestToken) return;

    _updateWorkflowPageState(() {
      _latestNodeEvidenceByNodeId = detail == null
          ? const <String, _WorkflowNodeEvidenceSummary>{}
          : _workflowNodeEvidenceByNodeId(detail);
      _loadingLatestNodeEvidence = false;
    });
  }

  // 最近一次运行摘要；不存在时返回 null。
  RunHistoryEntry? get _latestWorkflowRunEntry {
    final recentRuns = widget.snapshot.runHistory.recentRuns;
    return recentRuns.isEmpty ? null : recentRuns.first;
  }

  // 为最近运行生成刷新键，运行状态变化时重新读一次详情。
  String _workflowNodeEvidenceKey(RunHistoryEntry entry) {
    return [
      entry.runId,
      entry.status,
      entry.completedLoops,
      entry.finishedAt?.toIso8601String() ?? 'running',
    ].join('|');
  }

  // 跳转到记录页，详情仍由 Monitor 统一承载。
  void _openLatestRunEvidenceInMonitor() {
    final latestRun = _latestWorkflowRunEntry;
    if (latestRun == null) {
      widget.onNavigate(5);
      return;
    }
    widget.onOpenMonitorFocus(latestRun.runId, _selectedNodeId);
  }
}
