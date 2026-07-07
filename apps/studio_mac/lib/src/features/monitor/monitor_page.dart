part of '../../studio_mac_workspace.dart';

// 监控页入口，负责筛选运行记录并组合指标、趋势和历史列表。
class _MonitorPage extends StatefulWidget {
  const _MonitorPage({required this.snapshot, required this.controller});

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;

  // 创建监控页状态对象，页面内筛选和搜索状态都归属 State。
  @override
  State<_MonitorPage> createState() => _MonitorPageState();
}

// 监控页状态，集中管理筛选、搜索、关联运行和详情加载状态。
class _MonitorPageState extends State<_MonitorPage> {
  String? _loadingRunId;
  _MonitorTrendWindow _trendWindow = _MonitorTrendWindow.seven;
  _MonitorRunFilter _filter = _MonitorRunFilter.all;
  Set<String>? _relatedRunIds;
  String? _relatedRunLabel;
  RunNodeDurationTrend? _durationTrendDrilldown;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  // 释放搜索输入控制器，避免测试和页面切换后遗留监听。
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 提供给 Monitor 动作分片的受控状态更新入口。
  // 动作逻辑保持外置，但 setState 仍只在 State 子类内部调用。
  void _updateMonitorPageState(VoidCallback callback) {
    setState(callback);
  }

  // 渲染 Monitor 页面主体，所有筛选只作用于当前本地视图。
  @override
  Widget build(BuildContext context) {
    final history = widget.snapshot.runHistory;
    final filteredRuns = _filterRunHistory(history.recentRuns, _filter);
    final relatedRuns = _filterRelatedRunHistory(filteredRuns, _relatedRunIds);
    final visibleRuns = _searchRunHistory(relatedRuns, _query);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: ListView(
        key: const ValueKey('monitor-page-scroll'),
        children: [
          _MonitorMetricGrid(history: history),
          const SizedBox(height: 14),
          SizedBox(
            height: 196,
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: _RunTrendPanel(
                    history: history,
                    selected: _trendWindow,
                    onSelected: (window) {
                      setState(() => _trendWindow = window);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _RunStatusDistributionPanel(history: history),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 2,
                  child: _RunIssueCategoryPanel(
                    history: history,
                    onShowRuns: _showIssueCategoryRuns,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 3,
                  child: _RunNodeDurationPanel(
                    history: history,
                    onShowRuns: _showNodeDurationRuns,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FailureTrendPanel(history: history, selected: _trendWindow),
          const SizedBox(height: 14),
          _FailureClusterPanel(
            history: history,
            onShowRuns: _showFailureClusterRuns,
          ),
          const SizedBox(height: 14),
          _NodeDurationTrendPanel(
            history: history,
            onShowRuns: _showNodeDurationTrendRuns,
          ),
          const SizedBox(height: 14),
          _Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '最近记录',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    _CommandButton(
                      controlKey: const ValueKey('monitor-copy-runs-summary'),
                      label: '复制摘要',
                      icon: Icons.copy_all_outlined,
                      onPressed: visibleRuns.isEmpty
                          ? null
                          : () => _copyVisibleRunSummary(visibleRuns),
                    ),
                    const SizedBox(width: 8),
                    _CommandButton(
                      label: '刷新',
                      icon: Icons.refresh,
                      onPressed: () => widget.controller.refreshRunHistory(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _MonitorRunFilterBar(
                  selected: _filter,
                  runs: history.recentRuns,
                  onSelected: _selectRunFilter,
                ),
                const SizedBox(height: 12),
                _MonitorRunSearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: _query.isEmpty
                      ? null
                      : () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                ),
                if (_relatedRunIds != null) ...[
                  const SizedBox(height: 12),
                  _MonitorRelatedRunBanner(
                    label: _relatedRunLabel ?? '关联问题',
                    count: relatedRuns.length,
                    onClear: _clearRelatedRuns,
                  ),
                  const SizedBox(height: 12),
                  _MonitorDrilldownPanel(
                    label: _relatedRunLabel ?? '关联问题',
                    runs: relatedRuns,
                    onClear: _clearRelatedRuns,
                  ),
                  const SizedBox(height: 12),
                  _MonitorRunComparePanel(runs: relatedRuns),
                  if (_durationTrendDrilldown != null) ...[
                    const SizedBox(height: 12),
                    _MonitorDurationTrendDrilldownPanel(
                      trend: _durationTrendDrilldown!,
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                if (history.recentRuns.isEmpty)
                  const SizedBox(height: 140, child: _MonitorEmptyState())
                else if (visibleRuns.isEmpty)
                  const SizedBox(
                    height: 140,
                    child: _MonitorEmptyState(message: '无匹配记录'),
                  )
                else
                  Column(
                    children: [
                      for (
                        var index = 0;
                        index < visibleRuns.length;
                        index++
                      ) ...[
                        if (index > 0)
                          const Divider(color: StudioColors.border),
                        _RunHistoryRow(
                          entry: visibleRuns[index],
                          loading: _loadingRunId == visibleRuns[index].runId,
                          onOpen: () => _openRunDetail(visibleRuns[index]),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
