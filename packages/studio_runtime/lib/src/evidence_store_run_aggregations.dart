part of '../studio_runtime.dart';

// 运行历史基础聚合 helper。
// 这里只处理运行级趋势、均耗时和聚合排序，不读取单次运行详情。

// 计算本地运行的平均耗时，只纳入有开始和结束时间的有效记录。
// 异常时间不会污染 Monitor 的均耗时 KPI。
Duration? _averageRunDuration(List<RunHistoryEntry> entries) {
  var count = 0;
  var totalMicroseconds = 0;
  for (final entry in entries) {
    final startedAt = entry.startedAt;
    final finishedAt = entry.finishedAt;
    if (startedAt == null || finishedAt == null) continue;
    final duration = finishedAt.difference(startedAt);
    if (duration.isNegative) continue;
    count += 1;
    totalMicroseconds += duration.inMicroseconds;
  }
  if (count == 0) return null;
  return Duration(microseconds: totalMicroseconds ~/ count);
}

// 生成固定窗口的日运行趋势。
// 空数据或无效窗口会返回空列表，避免上层再做防御。
List<RunHistoryDay> _dailyRuns(
  List<RunHistoryEntry> entries, {
  required int windowDays,
}) {
  if (entries.isEmpty) return const <RunHistoryDay>[];
  if (windowDays < 1) return const <RunHistoryDay>[];
  final days = <DateTime, _RunHistoryDayCounts>{};
  DateTime? latestDay;
  for (final entry in entries) {
    final timestamp = entry.startedAt ?? entry.finishedAt;
    if (timestamp == null) continue;
    final day = _utcDay(timestamp);
    if (latestDay == null || day.isAfter(latestDay)) latestDay = day;
    final counts = days.putIfAbsent(day, _RunHistoryDayCounts.new);
    counts.totalRuns += 1;
    switch (entry.status) {
      case 'completed':
        counts.completedRuns += 1;
      case 'failed':
        counts.failedRuns += 1;
      case 'paused':
        counts.pausedRuns += 1;
      case 'stopped':
        counts.stoppedRuns += 1;
    }
  }
  final anchor = latestDay;
  if (anchor == null) return const <RunHistoryDay>[];
  return List<RunHistoryDay>.unmodifiable(
    List.generate(windowDays, (index) {
      final day = anchor.subtract(Duration(days: windowDays - 1 - index));
      final counts = days[day] ?? _RunHistoryDayCounts();
      return RunHistoryDay(
        day: day,
        totalRuns: counts.totalRuns,
        completedRuns: counts.completedRuns,
        failedRuns: counts.failedRuns,
        pausedRuns: counts.pausedRuns,
        stoppedRuns: counts.stoppedRuns,
      );
    }),
  );
}

// 把时间截断到 UTC 日期，避免本地时区写入污染聚合。
DateTime _utcDay(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

// 判断节点 trace 是否应该计入问题样本。
bool _traceHasIssue(RunNodeTrace trace) {
  return trace.error != null ||
      trace.status == 'failed' ||
      trace.status == 'paused';
}

// 统一关联运行的排序规则，先看最近时间，再用 run id 稳定兜底。
int _compareRecentRun(
  DateTime leftAt,
  String leftRunId,
  DateTime rightAt,
  String rightRunId,
) {
  final byTime = rightAt.compareTo(leftAt);
  if (byTime != 0) return byTime;
  return leftRunId.compareTo(rightRunId);
}

// 单日运行计数暂存模型。
// 该模型只在聚合窗口内使用，不进入 Runtime 对外快照。
final class _RunHistoryDayCounts {
  _RunHistoryDayCounts({
    this.totalRuns = 0,
    this.completedRuns = 0,
    this.failedRuns = 0,
    this.pausedRuns = 0,
    this.stoppedRuns = 0,
  });

  int totalRuns;
  int completedRuns;
  int failedRuns;
  int pausedRuns;
  int stoppedRuns;
}
