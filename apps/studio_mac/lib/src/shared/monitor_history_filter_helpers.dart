part of '../studio_mac_workspace.dart';

// Monitor 运行记录筛选 helper。
// 这里只处理本地 run 摘要的筛选、搜索和按钮元信息，不读取详情或截图。

// 运行记录筛选类型，用于 Monitor 页和后续执行详情复用。
enum _MonitorRunFilter { all, issues, failed, paused, completed }

// 根据 Monitor 顶部筛选项过滤本地运行记录。
List<RunHistoryEntry> _filterRunHistory(
  List<RunHistoryEntry> runs,
  _MonitorRunFilter filter,
) {
  return switch (filter) {
    _MonitorRunFilter.all => runs,
    _MonitorRunFilter.issues =>
      runs
          .where((entry) => _runHistoryStatusLabel(entry.status) != '完成')
          .toList(growable: false),
    _MonitorRunFilter.failed =>
      runs
          .where((entry) => _runHistoryStatusLabel(entry.status) == '失败')
          .toList(growable: false),
    _MonitorRunFilter.paused =>
      runs
          .where((entry) => _runHistoryStatusLabel(entry.status) == '暂停')
          .toList(growable: false),
    _MonitorRunFilter.completed =>
      runs
          .where((entry) => _runHistoryStatusLabel(entry.status) == '完成')
          .toList(growable: false),
  };
}

// 搜索运行记录，当前只匹配流程名、状态和本地 run id。
List<RunHistoryEntry> _searchRunHistory(
  List<RunHistoryEntry> runs,
  String query,
) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return runs;
  return runs
      .where((entry) {
        return entry.workflowName.toLowerCase().contains(normalized) ||
            entry.status.toLowerCase().contains(normalized) ||
            entry.runId.toLowerCase().contains(normalized);
      })
      .toList(growable: false);
}

// 按问题聚类关联的本地 run id 筛选最近记录。
List<RunHistoryEntry> _filterRelatedRunHistory(
  List<RunHistoryEntry> runs,
  Set<String>? relatedRunIds,
) {
  if (relatedRunIds == null || relatedRunIds.isEmpty) return runs;
  return runs
      .where((entry) => relatedRunIds.contains(entry.runId))
      .toList(growable: false);
}

// 为旧摘要补一个保守降级筛选，避免缺失关联 run 列表时深挖入口失效。
Set<String> _fallbackFailureClusterRunIds(
  RunFailureCluster cluster,
  List<RunHistoryEntry> runs,
) {
  final targetStatusLabel = switch (cluster.category) {
    'Paused' || '暂停' => '暂停',
    'Stopped' || '已停' => '已停',
    _ => '失败',
  };
  return runs
      .where(
        (entry) => _runHistoryStatusLabel(entry.status) == targetStatusLabel,
      )
      .map((entry) => entry.runId)
      .toSet();
}

// 为问题分类补本地记录筛选，当前分类计数不携带 run id 时用状态保守映射。
Set<String> _fallbackIssueCategoryRunIds(
  RunIssueCategoryCount category,
  List<RunHistoryEntry> runs,
) {
  final targetStatusLabel = switch (category.category) {
    'Paused' || '暂停' => '暂停',
    'Stopped' || '已停' => '已停',
    'None' || '无' => '完成',
    _ => '失败',
  };
  return runs
      .where(
        (entry) => _runHistoryStatusLabel(entry.status) == targetStatusLabel,
      )
      .map((entry) => entry.runId)
      .toSet();
}

// 返回 Monitor 运行筛选按钮的短标签。
String _labelForMonitorFilter(_MonitorRunFilter filter) {
  return switch (filter) {
    _MonitorRunFilter.all => '全部',
    _MonitorRunFilter.issues => '问题',
    _MonitorRunFilter.failed => '失败',
    _MonitorRunFilter.paused => '暂停',
    _MonitorRunFilter.completed => '完成',
  };
}

// 返回 Monitor 运行筛选按钮图标。
IconData _iconForMonitorFilter(_MonitorRunFilter filter) {
  return switch (filter) {
    _MonitorRunFilter.all => Icons.view_list_outlined,
    _MonitorRunFilter.issues => Icons.report_problem_outlined,
    _MonitorRunFilter.failed => Icons.error_outline,
    _MonitorRunFilter.paused => Icons.pause_circle_outline,
    _MonitorRunFilter.completed => Icons.check_circle_outline,
  };
}

// 返回 Monitor 运行筛选按钮的状态色。
StudioStatusTone _toneForMonitorFilter(_MonitorRunFilter filter) {
  return switch (filter) {
    _MonitorRunFilter.all => StudioStatusTone.running,
    _MonitorRunFilter.issues => StudioStatusTone.warning,
    _MonitorRunFilter.failed => StudioStatusTone.error,
    _MonitorRunFilter.paused => StudioStatusTone.warning,
    _MonitorRunFilter.completed => StudioStatusTone.ready,
  };
}
