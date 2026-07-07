part of '../studio_runtime.dart';

// 运行问题分类模型，支撑 Monitor 的本地问题统计。
// 这里只保存脱敏摘要，不承载截图、路径或底层 payload。

// RunIssueCategoryCount 表示本地问题分类聚合。
// 分类来自运行证据，不接入远程遥测。
final class RunIssueCategoryCount {
  // 创建问题分类计数。
  const RunIssueCategoryCount({
    required this.category,
    required this.count,
    this.relatedRuns = const <RunIssueCategoryRun>[],
  });

  final String category;
  final int count;
  final List<RunIssueCategoryRun> relatedRuns;
}

// RunIssueCategoryRun 表示问题分类关联的一次本地运行。
// 它只保留筛选需要的脱敏摘要，不包含截图、路径或底层 payload。
final class RunIssueCategoryRun {
  // 创建问题分类关联运行摘要。
  const RunIssueCategoryRun({
    required this.runId,
    required this.workflowName,
    required this.status,
    required this.happenedAt,
  });

  final String runId;
  final String workflowName;
  final String status;
  final DateTime? happenedAt;
}
