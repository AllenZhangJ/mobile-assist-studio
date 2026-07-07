part of '../studio_runtime.dart';

// 运行耗时模型，支撑 Monitor 的慢节点和耗时趋势分析。
// 这里只保存统计摘要，不展示坐标、截图或底层 payload。

// RunNodeDurationStat 表示运行历史里的节点耗时聚合。
// Monitor 用它发现慢节点，而不展示坐标或底层 payload。
final class RunNodeDurationStat {
  // 创建节点耗时聚合。
  const RunNodeDurationStat({
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.sampleCount,
    required this.issueCount,
    required this.averageDuration,
    required this.maxDuration,
    this.relatedRuns = const <RunNodeDurationRun>[],
  });

  final String nodeId;
  final String? nodeType;
  final String? label;
  final int sampleCount;
  final int issueCount;
  final Duration averageDuration;
  final Duration maxDuration;
  final List<RunNodeDurationRun> relatedRuns;
}

// RunNodeDurationRun 表示某个耗时节点关联的一次本地运行。
// 它只保留筛选需要的脱敏摘要，不包含截图、坐标或底层 payload。
final class RunNodeDurationRun {
  // 创建耗时节点关联运行摘要。
  const RunNodeDurationRun({
    required this.runId,
    required this.workflowName,
    required this.status,
    required this.duration,
    required this.happenedAt,
  });

  final String runId;
  final String workflowName;
  final String status;
  final Duration duration;
  final DateTime? happenedAt;
}

// RunNodeDurationTrendPoint 表示单个节点某一天的耗时聚合。
// 它只包含统计值，不包含运行路径、截图或底层 payload。
final class RunNodeDurationTrendPoint {
  // 创建节点单日耗时趋势点。
  const RunNodeDurationTrendPoint({
    required this.day,
    required this.averageDuration,
    required this.sampleCount,
    required this.issueCount,
  });

  final DateTime day;
  final Duration? averageDuration;
  final int sampleCount;
  final int issueCount;
}

// RunNodeDurationTrend 表示跨日期的节点耗时趋势。
// Monitor 用它观察节点耗时变化，而不扫描运行详情。
final class RunNodeDurationTrend {
  // 创建节点耗时趋势。
  const RunNodeDurationTrend({
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.points,
    required this.averageDuration,
    required this.maxDuration,
    required this.sampleCount,
    required this.issueCount,
    this.relatedRuns = const <RunNodeDurationRun>[],
  });

  final String nodeId;
  final String? nodeType;
  final String? label;
  final List<RunNodeDurationTrendPoint> points;
  final Duration averageDuration;
  final Duration maxDuration;
  final int sampleCount;
  final int issueCount;
  final List<RunNodeDurationRun> relatedRuns;
}
