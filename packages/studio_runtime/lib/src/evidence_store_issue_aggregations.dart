part of '../studio_runtime.dart';

// 问题分类与失败聚类 helper。
// 这里只生成本地脱敏问题摘要，不接入云端遥测或截图内容。

// 问题分类累加器，负责给分类计数补充脱敏关联运行。
final class _IssueCategoryAggregation {
  _IssueCategoryAggregation({required this.category});

  final String category;
  final Map<String, RunIssueCategoryRun> _relatedRuns =
      <String, RunIssueCategoryRun>{};
  int count = 0;

  // 追加一次分类样本，并记录当前运行的脱敏摘要。
  void add(RunHistoryEntry entry) {
    count += 1;
    _relatedRuns[entry.runId] = RunIssueCategoryRun(
      runId: entry.runId,
      workflowName: entry.workflowName,
      status: entry.status,
      happenedAt: entry.startedAt ?? entry.finishedAt,
    );
  }

  // 输出 Monitor 可消费的不可变分类计数。
  RunIssueCategoryCount toCount() {
    final relatedRuns = _relatedRuns.values.toList()
      ..sort((a, b) {
        final left = a.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return _compareRecentRun(left, a.runId, right, b.runId);
      });
    return RunIssueCategoryCount(
      category: category,
      count: count,
      relatedRuns: List<RunIssueCategoryRun>.unmodifiable(relatedRuns.take(6)),
    );
  }
}

// 单个失败聚类累加器，负责把多个运行压成一个问题摘要。
final class _FailureClusterAggregation {
  _FailureClusterAggregation({
    required this.category,
    required this.nodeId,
    required this.nodeType,
    required this.label,
  });

  final String category;
  final String? nodeId;
  final String? nodeType;
  final String? label;
  final Set<String> _workflowNames = <String>{};
  final Map<String, RunFailureClusterRun> _relatedRuns =
      <String, RunFailureClusterRun>{};
  int count = 0;
  String? recentReason;
  DateTime? recentAt;

  // 追加一次问题样本，并记录最近发生时间、脱敏原因和关联运行。
  void add(RunHistoryEntry entry, RunFailureAnalysis analysis) {
    count += 1;
    _workflowNames.add(entry.workflowName);
    final timestamp = entry.startedAt ?? entry.finishedAt;
    _relatedRuns[entry.runId] = RunFailureClusterRun(
      runId: entry.runId,
      workflowName: entry.workflowName,
      status: entry.status,
      happenedAt: timestamp,
    );
    if (timestamp != null &&
        (recentAt == null || timestamp.isAfter(recentAt!))) {
      recentAt = timestamp;
      recentReason = _compactIssueReason(analysis.reason);
    }
    recentReason ??= _compactIssueReason(analysis.reason);
  }

  // 输出 Monitor 可直接消费的不可变聚类模型。
  RunFailureCluster toCluster() {
    final relatedRuns = _relatedRuns.values.toList()
      ..sort((a, b) {
        final left = a.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.happenedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return _compareRecentRun(left, a.runId, right, b.runId);
      });
    return RunFailureCluster(
      category: category,
      nodeId: nodeId,
      nodeType: nodeType,
      label: label,
      count: count,
      workflowCount: _workflowNames.length,
      recentReason: recentReason,
      recentAt: recentAt,
      relatedRuns: List<RunFailureClusterRun>.unmodifiable(relatedRuns.take(6)),
    );
  }
}

// 生成失败聚类 key，优先按问题分类和节点聚合。
String _failureClusterKey(RunFailureAnalysis analysis) {
  final nodeKey =
      analysis.failedNodeId ??
      analysis.failedNodeLabel ??
      analysis.failedNodeType ??
      'unknown';
  return '${analysis.category}|$nodeKey';
}

// 生成稳定排序标签，避免同次数聚类抖动。
String _failureClusterSortLabel(RunFailureCluster cluster) {
  return '${cluster.category}|${cluster.nodeId ?? cluster.label ?? ''}';
}

// 压缩问题原因，避免把本机路径或超长底层错误带到概览。
String? _compactIssueReason(String? reason) {
  final trimmed = reason?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final withoutPaths = trimmed.replaceAll(
    RegExp(r'/(?:Users|private|var|tmp)/\S+'),
    '[local-path]',
  );
  if (withoutPaths.length <= 96) return withoutPaths;
  return '${withoutPaths.substring(0, 93)}...';
}
