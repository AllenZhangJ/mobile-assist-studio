part of '../../studio_mac_workspace.dart';

// 跨运行对比摘要模型，集中承载关联记录的状态分布和最近变化。
final class _MonitorRunCompareSummary {
  // 创建跨运行对比摘要，字段均来自本地运行摘要。
  const _MonitorRunCompareSummary({
    required this.completedCount,
    required this.failedCount,
    required this.pausedCount,
    required this.stoppedCount,
    required this.issueStreakCount,
    required this.latestRunLabel,
    required this.recentChangeLabel,
    required this.timelineItems,
    required this.tone,
  });

  final int completedCount;
  final int failedCount;
  final int pausedCount;
  final int stoppedCount;
  final int issueStreakCount;
  final String latestRunLabel;
  final String recentChangeLabel;
  final List<_MonitorRunCompareTimelineItem> timelineItems;
  final StudioStatusTone tone;

  // 从关联运行摘要中派生状态分布，不读取详情或截图。
  factory _MonitorRunCompareSummary.fromRuns(List<RunHistoryEntry> runs) {
    final sortedRuns = [...runs]..sort(_compareRunsByTimeDesc);
    final latestRun = sortedRuns.isEmpty ? null : sortedRuns.first;
    final issueStreakCount = _countIssueStreak(sortedRuns);
    return _MonitorRunCompareSummary(
      completedCount: _countRunsByLabel(sortedRuns, '完成'),
      failedCount: _countRunsByLabel(sortedRuns, '失败'),
      pausedCount: _countRunsByLabel(sortedRuns, '暂停'),
      stoppedCount: _countRunsByLabel(sortedRuns, '已停'),
      issueStreakCount: issueStreakCount,
      latestRunLabel: latestRun == null ? '-' : _latestRunLabel(latestRun),
      recentChangeLabel: _recentChangeLabel(sortedRuns),
      timelineItems: sortedRuns
          .take(5)
          .map(_MonitorRunCompareTimelineItem.fromRun)
          .toList(growable: false),
      tone: issueStreakCount == 0
          ? StudioStatusTone.ready
          : StudioStatusTone.warning,
    );
  }
}

// 跨运行时间线条目，隐藏 run id，仅展示流程名、状态和时间。
final class _MonitorRunCompareTimelineItem {
  // 创建单条时间线展示项。
  const _MonitorRunCompareTimelineItem({
    required this.workflowName,
    required this.statusLabel,
    required this.timeLabel,
    required this.tone,
  });

  final String workflowName;
  final String statusLabel;
  final String timeLabel;
  final StudioStatusTone tone;

  // 从运行摘要生成脱敏时间线条目。
  factory _MonitorRunCompareTimelineItem.fromRun(RunHistoryEntry run) {
    final statusLabel = _runHistoryStatusLabel(run.status);
    return _MonitorRunCompareTimelineItem(
      workflowName: _safeWorkflowName(run.workflowName),
      statusLabel: statusLabel,
      timeLabel: _runCompareTimeLabel(run),
      tone: _toneForRunStatus(run.status),
    );
  }
}

// 比较运行时间，最近的运行排在前面。
int _compareRunsByTimeDesc(RunHistoryEntry a, RunHistoryEntry b) {
  final aTime = a.finishedAt ?? a.startedAt;
  final bTime = b.finishedAt ?? b.startedAt;
  if (aTime == null && bTime == null) return 0;
  if (aTime == null) return 1;
  if (bTime == null) return -1;
  return bTime.compareTo(aTime);
}

// 统计指定短中文状态的运行数量。
int _countRunsByLabel(List<RunHistoryEntry> runs, String label) {
  return runs
      .where((run) => _runHistoryStatusLabel(run.status) == label)
      .length;
}

// 统计最近连续问题次数，遇到完成即停止。
int _countIssueStreak(List<RunHistoryEntry> sortedRuns) {
  var count = 0;
  for (final run in sortedRuns) {
    if (_runHistoryStatusLabel(run.status) == '完成') break;
    count++;
  }
  return count;
}

// 生成最近运行摘要，避免显示 run id。
String _latestRunLabel(RunHistoryEntry run) {
  return '${_safeWorkflowName(run.workflowName)} · ${_runHistoryStatusLabel(run.status)} · ${_runCompareTimeLabel(run)}';
}

// 生成最近两次运行的状态变化说明。
String _recentChangeLabel(List<RunHistoryEntry> sortedRuns) {
  if (sortedRuns.length < 2) return '暂无对比';
  final previous = _runHistoryStatusLabel(sortedRuns[1].status);
  final latest = _runHistoryStatusLabel(sortedRuns.first.status);
  if (previous == latest) return '保持 $latest';
  return '$previous -> $latest';
}

// 生成运行时间短文案，缺失时间时安全降级。
String _runCompareTimeLabel(RunHistoryEntry run) {
  final time = run.finishedAt ?? run.startedAt;
  return time == null ? '-' : _timeOnly(time);
}

// 生成安全流程名，空名称时给用户可懂兜底。
String _safeWorkflowName(String workflowName) {
  final trimmed = workflowName.trim();
  return trimmed.isEmpty ? '未命名流程' : trimmed;
}
