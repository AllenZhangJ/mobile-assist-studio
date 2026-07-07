part of '../studio_runtime.dart';

// 运行历史模型入口，只保留基础历史摘要和汇总模型。
// 问题分类、节点耗时和失败聚类已拆入相邻分片。

// RunHistoryEntry 是一次本地运行的摘要。
// Monitor 列表和 Dashboard 最近流程只读取这里的脱敏字段。
final class RunHistoryEntry {
  // 创建一次运行历史摘要。
  const RunHistoryEntry({
    required this.runId,
    required this.workflowName,
    required this.status,
    required this.loops,
    required this.completedLoops,
    required this.startedAt,
    required this.finishedAt,
  });

  final String runId;
  final String workflowName;
  final String status;
  final int loops;
  final int completedLoops;
  final DateTime? startedAt;
  final DateTime? finishedAt;
}

// RunHistoryDay 表示某一天的本地运行聚合。
// 它用于 Monitor 趋势，不包含任何设备或截图内容。
final class RunHistoryDay {
  // 创建单日运行聚合。
  const RunHistoryDay({
    required this.day,
    required this.totalRuns,
    required this.completedRuns,
    required this.failedRuns,
    required this.pausedRuns,
    required this.stoppedRuns,
  });

  final DateTime day;
  final int totalRuns;
  final int completedRuns;
  final int failedRuns;
  final int pausedRuns;
  final int stoppedRuns;

  // 汇总非成功运行数量，供趋势图和问题分类复用。
  int get issueRuns => failedRuns + pausedRuns + stoppedRuns;

  // 计算单日成功率，空数据时返回 0。
  double get successRate {
    if (totalRuns == 0) return 0;
    return completedRuns / totalRuns;
  }
}

// RunHistorySummary 是 Monitor 与 Dashboard 共用的本地统计真源。
// 所有指标都来自本地 evidence store 聚合。
final class RunHistorySummary {
  // 创建运行历史汇总。
  const RunHistorySummary({
    required this.totalRuns,
    required this.completedRuns,
    required this.failedRuns,
    required this.pausedRuns,
    required this.stoppedRuns,
    required this.dailyRuns,
    required this.recentRuns,
    this.averageDuration,
    this.dailyRuns30 = const <RunHistoryDay>[],
    this.dailyRuns90 = const <RunHistoryDay>[],
    this.issueCategories = const <RunIssueCategoryCount>[],
    this.nodeDurationStats = const <RunNodeDurationStat>[],
    this.nodeDurationTrends = const <RunNodeDurationTrend>[],
    this.failureClusters = const <RunFailureCluster>[],
  });

  final int totalRuns;
  final int completedRuns;
  final int failedRuns;
  final int pausedRuns;
  final int stoppedRuns;
  final List<RunHistoryDay> dailyRuns;
  final Duration? averageDuration;
  final List<RunHistoryDay> dailyRuns30;
  final List<RunHistoryDay> dailyRuns90;
  final List<RunHistoryEntry> recentRuns;
  final List<RunIssueCategoryCount> issueCategories;
  final List<RunNodeDurationStat> nodeDurationStats;
  final List<RunNodeDurationTrend> nodeDurationTrends;
  final List<RunFailureCluster> failureClusters;

  // 计算本地运行成功率，空数据时返回 0 避免 UI 自行判断。
  double get successRate {
    if (totalRuns == 0) return 0;
    return completedRuns / totalRuns;
  }

  static const empty = RunHistorySummary(
    totalRuns: 0,
    completedRuns: 0,
    failedRuns: 0,
    pausedRuns: 0,
    stoppedRuns: 0,
    dailyRuns: <RunHistoryDay>[],
    averageDuration: null,
    dailyRuns30: <RunHistoryDay>[],
    dailyRuns90: <RunHistoryDay>[],
    recentRuns: <RunHistoryEntry>[],
    issueCategories: <RunIssueCategoryCount>[],
    nodeDurationStats: <RunNodeDurationStat>[],
    nodeDurationTrends: <RunNodeDurationTrend>[],
    failureClusters: <RunFailureCluster>[],
  );
}
