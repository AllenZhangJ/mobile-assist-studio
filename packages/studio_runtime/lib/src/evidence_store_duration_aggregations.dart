part of '../studio_runtime.dart';

// 节点耗时聚合 helper。
// 这里只维护节点级平均耗时、趋势和脱敏关联运行摘要。

// 单个节点的耗时累加器，负责把多次运行压成一条统计。
// 关联运行只保留脱敏摘要，避免 Monitor 展示底层证据路径。
final class _NodeDurationAggregation {
  _NodeDurationAggregation({
    required this.nodeId,
    required this.nodeType,
    required this.label,
  });

  final String nodeId;
  final String? nodeType;
  final String? label;
  int sampleCount = 0;
  int issueCount = 0;
  int totalMicroseconds = 0;
  Duration maxDuration = Duration.zero;
  final Map<String, RunNodeDurationRun> _relatedRuns =
      <String, RunNodeDurationRun>{};

  // 追加一次节点耗时，并同步记录是否出现问题。
  void add(
    Duration duration, {
    required RunHistoryEntry entry,
    required RunNodeTrace trace,
    required bool hasIssue,
  }) {
    sampleCount += 1;
    if (hasIssue) issueCount += 1;
    totalMicroseconds += duration.inMicroseconds;
    if (duration > maxDuration) maxDuration = duration;
    _rememberDurationRun(_relatedRuns, entry, trace, duration);
  }

  // 输出 Monitor 可直接消费的不可变统计模型。
  RunNodeDurationStat toStat() {
    return RunNodeDurationStat(
      nodeId: nodeId,
      nodeType: nodeType,
      label: label,
      sampleCount: sampleCount,
      issueCount: issueCount,
      averageDuration: Duration(microseconds: totalMicroseconds ~/ sampleCount),
      maxDuration: maxDuration,
      relatedRuns: _sortedDurationRuns(_relatedRuns),
    );
  }
}

// 单个节点的按日耗时趋势累加器。
// 它同时维护整体摘要和日桶，供趋势图与慢节点榜共用。
final class _NodeDurationTrendAggregation {
  _NodeDurationTrendAggregation({
    required this.nodeId,
    required this.nodeType,
    required this.label,
  });

  final String nodeId;
  final String? nodeType;
  final String? label;
  final Map<DateTime, _NodeDurationTrendBucket> buckets =
      <DateTime, _NodeDurationTrendBucket>{};
  int sampleCount = 0;
  int issueCount = 0;
  int totalMicroseconds = 0;
  Duration maxDuration = Duration.zero;
  final Map<String, RunNodeDurationRun> _relatedRuns =
      <String, RunNodeDurationRun>{};

  // 追加某一天的节点耗时，并同步维护整体趋势摘要。
  void add(
    DateTime day,
    Duration duration, {
    required RunHistoryEntry entry,
    required RunNodeTrace trace,
    required bool hasIssue,
  }) {
    final bucket = buckets.putIfAbsent(day, _NodeDurationTrendBucket.new);
    bucket.add(duration, hasIssue: hasIssue);
    sampleCount += 1;
    if (hasIssue) issueCount += 1;
    totalMicroseconds += duration.inMicroseconds;
    if (duration > maxDuration) maxDuration = duration;
    _rememberDurationRun(_relatedRuns, entry, trace, duration);
  }

  // 输出固定窗口的节点耗时趋势，缺失日期保留空点。
  RunNodeDurationTrend toTrend({
    required DateTime anchor,
    required int windowDays,
  }) {
    final points = List<RunNodeDurationTrendPoint>.generate(windowDays, (
      index,
    ) {
      final day = anchor.subtract(Duration(days: windowDays - 1 - index));
      final bucket = buckets[day];
      return RunNodeDurationTrendPoint(
        day: day,
        averageDuration: bucket?.averageDuration,
        sampleCount: bucket?.sampleCount ?? 0,
        issueCount: bucket?.issueCount ?? 0,
      );
    }, growable: false);
    return RunNodeDurationTrend(
      nodeId: nodeId,
      nodeType: nodeType,
      label: label,
      points: List<RunNodeDurationTrendPoint>.unmodifiable(points),
      averageDuration: Duration(microseconds: totalMicroseconds ~/ sampleCount),
      maxDuration: maxDuration,
      sampleCount: sampleCount,
      issueCount: issueCount,
      relatedRuns: _sortedDurationRuns(_relatedRuns),
    );
  }
}

// 记录节点耗时关联运行，同一运行只保留该节点最慢的一次样本。
void _rememberDurationRun(
  Map<String, RunNodeDurationRun> relatedRuns,
  RunHistoryEntry entry,
  RunNodeTrace trace,
  Duration duration,
) {
  final happenedAt = trace.finishedAt ?? trace.startedAt ?? entry.finishedAt;
  final existing = relatedRuns[entry.runId];
  if (existing != null && existing.duration >= duration) return;
  relatedRuns[entry.runId] = RunNodeDurationRun(
    runId: entry.runId,
    workflowName: entry.workflowName,
    status: entry.status,
    duration: duration,
    happenedAt: happenedAt ?? entry.startedAt,
  );
}

// 输出按耗时和时间排序的关联运行，限制数量避免概览过重。
List<RunNodeDurationRun> _sortedDurationRuns(
  Map<String, RunNodeDurationRun> relatedRuns,
) {
  final runs = relatedRuns.values.toList()
    ..sort((a, b) {
      final byDuration = b.duration.compareTo(a.duration);
      if (byDuration != 0) return byDuration;
      final left = a.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return _compareRecentRun(left, a.runId, right, b.runId);
    });
  return List<RunNodeDurationRun>.unmodifiable(runs.take(6));
}

// 单日节点耗时桶，负责计算当天平均耗时。
// 空桶不会输出耗时，避免 Monitor 误读为 0ms。
final class _NodeDurationTrendBucket {
  int sampleCount = 0;
  int issueCount = 0;
  int totalMicroseconds = 0;

  // 追加当天的一次节点耗时样本。
  void add(Duration duration, {required bool hasIssue}) {
    sampleCount += 1;
    if (hasIssue) issueCount += 1;
    totalMicroseconds += duration.inMicroseconds;
  }

  // 计算当天平均耗时，空样本时返回空。
  Duration? get averageDuration {
    if (sampleCount == 0) return null;
    return Duration(microseconds: totalMicroseconds ~/ sampleCount);
  }
}
