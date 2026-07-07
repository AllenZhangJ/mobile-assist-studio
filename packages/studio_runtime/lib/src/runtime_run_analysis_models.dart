part of '../studio_runtime.dart';

// 运行分析模型分片，负责失败摘要和详情指标。

// RunFailureAnalysis 汇总运行失败或暂停原因。
// Monitor 详情页用它做 Summary First 的问题说明。
final class RunFailureAnalysis {
  // 创建失败分析摘要。
  const RunFailureAnalysis({
    required this.category,
    required this.failedNodeId,
    required this.failedNodeLabel,
    required this.failedNodeType,
    required this.failedLoopIndex,
    required this.failedDuration,
    required this.reason,
    required this.screenshotEvidenceCount,
  });

  final String category;
  final String? failedNodeId;
  final String? failedNodeLabel;
  final String? failedNodeType;
  final int? failedLoopIndex;
  final Duration? failedDuration;
  final String? reason;
  final int screenshotEvidenceCount;
}

// RunDetailMetrics 汇总详情页的节点路径指标。
// 它让 UI 不需要重复扫描事件流。
final class RunDetailMetrics {
  // 创建运行详情指标。
  const RunDetailMetrics({
    required this.totalSteps,
    required this.completedSteps,
    required this.failedSteps,
    required this.pausedSteps,
    required this.runningSteps,
    required this.screenshotEvidenceCount,
    required this.slowestNodeId,
    required this.slowestNodeLabel,
    required this.slowestNodeType,
    required this.slowestDuration,
  });

  final int totalSteps;
  final int completedSteps;
  final int failedSteps;
  final int pausedSteps;
  final int runningSteps;
  final int screenshotEvidenceCount;
  final String? slowestNodeId;
  final String? slowestNodeLabel;
  final String? slowestNodeType;
  final Duration? slowestDuration;

  // 统计失败和暂停节点数量，供详情页状态摘要使用。
  int get issueSteps => failedSteps + pausedSteps;
}

// 将运行状态和失败原因归类为用户可理解的问题类型。
String _failureCategory(String status, String? reason) {
  if (status == 'stopped') return 'Stopped';
  if (status == 'paused') return 'Paused';
  if (status != 'failed') return 'None';
  final normalized = (reason ?? '').toLowerCase();
  if (normalized.contains('confidence') || normalized.contains('置信')) {
    return 'Low Confidence';
  }
  if (normalized.contains('timeout') || normalized.contains('timed out')) {
    return 'Timeout';
  }
  if (normalized.contains('not executable') ||
      normalized.contains('unsupported')) {
    return 'Unsupported Node';
  }
  if (normalized.contains('webdriver') || normalized.contains('appium')) {
    return 'Driver Error';
  }
  if (normalized.contains('session')) return 'Session Error';
  return 'Runtime Error';
}
