part of '../../studio_mac_workspace.dart';

// Monitor 页面动作分片，承载详情读取、关联筛选和复制摘要等页面事件。

extension _MonitorPageActions on _MonitorPageState {
  // 打开单次运行详情抽屉，只读取当前 run 的本地详情。
  Future<void> _openRunDetail(RunHistoryEntry entry) async {
    if (_loadingRunId != null) return;
    _updateMonitorPageState(() => _loadingRunId = entry.runId);
    final detailFuture = widget.controller.readRunDetail(entry.runId);
    final reportFuture = widget.controller.readRunReport(entry.runId);
    final detail = await detailFuture;
    final report = await reportFuture;
    if (!mounted) return;
    _updateMonitorPageState(() => _loadingRunId = null);
    await _showRunDetailDrawer(
      context,
      entry: entry,
      detail: detail,
      report: report,
      controller: widget.controller,
    );
  }

  // 将常见问题聚类映射为最近记录筛选，形成本地跨运行深挖入口。
  void _showFailureClusterRuns(RunFailureCluster cluster) {
    final linkedRunIds = cluster.relatedRuns.map((run) => run.runId).toSet();
    final runIds = linkedRunIds.isNotEmpty
        ? linkedRunIds
        : _fallbackFailureClusterRunIds(
            cluster,
            widget.snapshot.runHistory.recentRuns,
          );
    if (runIds.isEmpty) return;
    _searchController.clear();
    _updateMonitorPageState(() {
      _filter = _MonitorRunFilter.issues;
      _query = '';
      _relatedRunIds = runIds;
      _relatedRunLabel =
          '${_analysisCategoryLabel(cluster.category)} · ${_failureClusterNodeLabel(cluster)}';
      _durationTrendDrilldown = null;
    });
  }

  // 将问题分类映射为最近记录筛选，提供轻量跨运行深挖入口。
  void _showIssueCategoryRuns(RunIssueCategoryCount category) {
    final linkedRunIds = category.relatedRuns.map((run) => run.runId).toSet();
    final runIds = linkedRunIds.isNotEmpty
        ? linkedRunIds
        : _fallbackIssueCategoryRunIds(
            category,
            widget.snapshot.runHistory.recentRuns,
          );
    if (runIds.isEmpty) return;
    _searchController.clear();
    _updateMonitorPageState(() {
      _filter = _MonitorRunFilter.issues;
      _query = '';
      _relatedRunIds = runIds;
      _relatedRunLabel = '分类 · ${_analysisCategoryLabel(category.category)}';
      _durationTrendDrilldown = null;
    });
  }

  // 将耗时节点映射为最近记录筛选，帮助定位慢节点来自哪些运行。
  void _showNodeDurationRuns(RunNodeDurationStat stat) {
    final runIds = stat.relatedRuns.map((run) => run.runId).toSet();
    if (runIds.isEmpty) return;
    _searchController.clear();
    _updateMonitorPageState(() {
      _filter = _MonitorRunFilter.all;
      _query = '';
      _relatedRunIds = runIds;
      _relatedRunLabel = '耗时 · ${_nodeDurationLabel(stat)}';
      _durationTrendDrilldown = null;
    });
  }

  // 将耗时趋势映射为最近记录筛选，保持趋势分析可追溯。
  void _showNodeDurationTrendRuns(RunNodeDurationTrend trend) {
    final runIds = trend.relatedRuns.map((run) => run.runId).toSet();
    if (runIds.isEmpty) return;
    _searchController.clear();
    _updateMonitorPageState(() {
      _filter = _MonitorRunFilter.all;
      _query = '';
      _relatedRunIds = runIds;
      _relatedRunLabel = '趋势 · ${_nodeDurationTrendLabel(trend)}';
      _durationTrendDrilldown = trend;
    });
  }

  // 清除关联筛选，回到当前问题视图的普通运行列表。
  void _clearRelatedRuns() {
    _updateMonitorPageState(() {
      _relatedRunIds = null;
      _relatedRunLabel = null;
      _durationTrendDrilldown = null;
    });
  }

  // 手动切换列表筛选时退出关联深挖，避免两个筛选语义叠加。
  void _selectRunFilter(_MonitorRunFilter filter) {
    _updateMonitorPageState(() {
      _filter = filter;
      _relatedRunIds = null;
      _relatedRunLabel = null;
      _durationTrendDrilldown = null;
    });
  }

  // 复制当前可见运行记录摘要，只写剪贴板，不读取详情或截图。
  Future<void> _copyVisibleRunSummary(List<RunHistoryEntry> visibleRuns) async {
    await _copyPlainText(
      context,
      text: _visibleRunHistorySummary(
        runs: visibleRuns,
        filter: _filter,
        query: _query,
        relatedLabel: _relatedRunLabel,
      ),
    );
  }
}
