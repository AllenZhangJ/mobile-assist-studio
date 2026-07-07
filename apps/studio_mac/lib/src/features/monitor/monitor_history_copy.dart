part of '../../studio_mac_workspace.dart';

// 生成当前运行记录视图的脱敏可复制摘要。
String _visibleRunHistorySummary({
  required List<RunHistoryEntry> runs,
  required _MonitorRunFilter filter,
  required String query,
  required String? relatedLabel,
}) {
  final normalizedQuery = query.trim();
  final header = <String>[
    '运行记录摘要',
    '筛选：${_labelForMonitorFilter(filter)}',
    '搜索：${normalizedQuery.isEmpty ? '无' : normalizedQuery}',
    '关联：${relatedLabel ?? '无'}',
    '数量：${runs.length}',
  ];
  if (runs.isEmpty) {
    return [...header, '记录：无'].join('\n');
  }
  return [
    ...header,
    for (final entry in runs) _visibleRunHistoryLine(entry),
  ].join('\n');
}

// 生成单条运行记录摘要，不包含 run id、路径、设备或底层 payload。
String _visibleRunHistoryLine(RunHistoryEntry entry) {
  final finishedAt = entry.finishedAt == null
      ? '-'
      : _timeOnly(entry.finishedAt!);
  return [
    _runHistoryStatusLabel(entry.status),
    entry.workflowName,
    '${entry.completedLoops}/${entry.loops} 轮',
    finishedAt,
  ].join(' · ');
}
