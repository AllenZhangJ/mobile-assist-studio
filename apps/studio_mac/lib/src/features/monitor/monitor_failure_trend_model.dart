part of '../../studio_mac_workspace.dart';

// 失败趋势聚合模型，负责把运行日统计转换成图表和标题可用的摘要。

// 失败趋势聚合值，避免 Widget 中重复计算各类问题数量。
class _FailureTrendTotals {
  const _FailureTrendTotals({
    required this.failedRuns,
    required this.pausedRuns,
    required this.stoppedRuns,
    required this.maxIssues,
  });

  final int failedRuns;
  final int pausedRuns;
  final int stoppedRuns;
  final int maxIssues;

  // 汇总当前窗口内所有需要关注的问题次数。
  int get issueRuns => failedRuns + pausedRuns + stoppedRuns;

  // 从日聚合列表生成标题和图表所需的摘要数据。
  factory _FailureTrendTotals.fromDays(List<RunHistoryDay> days) {
    var failedRuns = 0;
    var pausedRuns = 0;
    var stoppedRuns = 0;
    var maxIssues = 0;
    for (final day in days) {
      failedRuns += day.failedRuns;
      pausedRuns += day.pausedRuns;
      stoppedRuns += day.stoppedRuns;
      maxIssues = math.max(maxIssues, day.issueRuns);
    }
    return _FailureTrendTotals(
      failedRuns: failedRuns,
      pausedRuns: pausedRuns,
      stoppedRuns: stoppedRuns,
      maxIssues: maxIssues,
    );
  }
}
