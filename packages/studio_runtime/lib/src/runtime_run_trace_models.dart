part of '../studio_runtime.dart';

// 运行轨迹模型分片，负责节点路径和截图证据引用。

// RunNodeTrace 表示单个节点在运行中的路径片段。
// 它由 stepStart / stepEnd 事件合成，供详情页展示执行路径。
final class RunNodeTrace {
  // 创建节点执行轨迹。
  const RunNodeTrace({
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.loopIndex,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.error,
    required this.screenshotPath,
  });

  final String nodeId;
  final String? nodeType;
  final String? label;
  final int? loopIndex;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? error;
  final String? screenshotPath;

  // 计算节点耗时，缺少开始或结束时间时返回空。
  Duration? get duration {
    final start = startedAt;
    final finish = finishedAt;
    if (start == null || finish == null) return null;
    return finish.difference(start);
  }
}

// RunScreenshotEvidenceRef 表示截图证据的本地相对引用。
// UI 必须通过 Runtime 读取，不直接拼接本机绝对路径。
final class RunScreenshotEvidenceRef {
  // 创建截图证据引用。
  const RunScreenshotEvidenceRef({
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.loopIndex,
    required this.status,
    required this.duration,
    required this.relativePath,
  });

  final String nodeId;
  final String? nodeType;
  final String? label;
  final int? loopIndex;
  final String status;
  final Duration? duration;
  final String relativePath;
}
