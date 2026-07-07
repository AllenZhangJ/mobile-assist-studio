part of '../studio_runtime.dart';

// 运行失败聚类模型，支撑 Monitor 的本地失败分析。
// 聚类只保存脱敏摘要，不包含截图路径或原始证据 payload。

// RunFailureClusterRun 表示某个问题聚类关联的一次本地运行。
// 它只保留列表筛选需要的脱敏摘要，不包含截图或底层 payload。
final class RunFailureClusterRun {
  // 创建问题关联运行摘要。
  const RunFailureClusterRun({
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

// RunFailureCluster 表示跨运行的本地问题聚类。
// 它只聚合分类、节点和次数，不承载截图路径或底层 payload。
final class RunFailureCluster {
  // 创建本地问题聚类摘要。
  const RunFailureCluster({
    required this.category,
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.count,
    required this.workflowCount,
    required this.recentReason,
    required this.recentAt,
    this.relatedRuns = const <RunFailureClusterRun>[],
  });

  final String category;
  final String? nodeId;
  final String? nodeType;
  final String? label;
  final int count;
  final int workflowCount;
  final String? recentReason;
  final DateTime? recentAt;
  final List<RunFailureClusterRun> relatedRuns;
}
