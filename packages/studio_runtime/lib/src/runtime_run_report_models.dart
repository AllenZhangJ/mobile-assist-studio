part of '../studio_runtime.dart';

// 本地运行报告模型分片，负责把 RunDetail 聚合成可导出报告。

// RunReportExportResult 是报告导出后的安全摘要。
// UI 只展示文件名，不展示本机完整路径。
final class RunReportExportResult {
  // 创建报告导出摘要。
  const RunReportExportResult({
    required this.runId,
    required this.fileName,
    required this.relativePath,
    required this.exportedAt,
  });

  final String runId;
  final String fileName;
  final String relativePath;
  final DateTime exportedAt;

  // 输出脱敏 JSON，供测试和后续 AI 工具读取。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runId': _sanitizeReportText(runId),
      'fileName': _sanitizeReportText(fileName),
      'relativePath': _sanitizeReportText(relativePath),
      'exportedAt': exportedAt.toIso8601String(),
    };
  }
}

// RunLocalReport 是一次运行的本地复盘报告。
// 它吸收 Airtest 报告心智，但只使用本项目 evidence 真源。
final class RunLocalReport {
  // 创建本地运行报告。
  const RunLocalReport({
    required this.overview,
    required this.issue,
    required this.timeline,
    required this.visualChecks,
    required this.screenshots,
    required this.logSummary,
    required this.platform,
  });

  final RunReportOverview overview;
  final RunReportIssue issue;
  final List<RunReportTimelineItem> timeline;
  final List<RunReportVisualCheck> visualChecks;
  final List<RunReportScreenshotItem> screenshots;
  final RunReportLogSummary logSummary;
  final RunReportPlatformSummary platform;

  // 从运行详情派生本地报告，不读取额外文件。
  factory RunLocalReport.fromDetail(RunDetail detail) {
    return RunLocalReport(
      overview: RunReportOverview.fromDetail(detail),
      issue: RunReportIssue.fromDetail(detail),
      timeline: detail.nodeTraces
          .map(RunReportTimelineItem.fromTrace)
          .toList(growable: false),
      visualChecks: _visualChecksFromDetail(detail),
      screenshots: detail.screenshotEvidenceRefs
          .where((ref) => _isSafeEvidenceRelativePath(ref.relativePath))
          .map(RunReportScreenshotItem.fromRef)
          .toList(growable: false),
      logSummary: RunReportLogSummary.fromDetail(detail),
      platform: RunReportPlatformSummary.fromDetail(detail),
    );
  }

  // 输出脱敏 JSON，供后续导出、AI 解释和 Monitor 复用。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'overview': overview.toJson(),
      'issue': issue.toJson(),
      'timeline': timeline.map((item) => item.toJson()).toList(),
      'visualChecks': visualChecks.map((item) => item.toJson()).toList(),
      'screenshots': screenshots.map((item) => item.toJson()).toList(),
      'logSummary': logSummary.toJson(),
      'platform': platform.toJson(),
    };
  }
}

// RunReportOverview 是报告顶部摘要。
// 它只包含本地运行指标，不包含设备标识或路径。
final class RunReportOverview {
  // 创建报告摘要。
  const RunReportOverview({
    required this.runId,
    required this.workflowName,
    required this.status,
    required this.loops,
    required this.completedLoops,
    required this.startedAt,
    required this.finishedAt,
    required this.duration,
    required this.totalSteps,
    required this.completedSteps,
    required this.failedSteps,
    required this.pausedSteps,
    required this.visualCheckCount,
    required this.screenshotCount,
  });

  final String runId;
  final String workflowName;
  final String status;
  final int loops;
  final int completedLoops;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final Duration? duration;
  final int totalSteps;
  final int completedSteps;
  final int failedSteps;
  final int pausedSteps;
  final int visualCheckCount;
  final int screenshotCount;

  // 从运行详情生成摘要。
  factory RunReportOverview.fromDetail(RunDetail detail) {
    final metrics = detail.metrics;
    return RunReportOverview(
      runId: _sanitizeReportText(detail.entry.runId),
      workflowName: _sanitizeReportText(detail.entry.workflowName),
      status: detail.entry.status,
      loops: detail.entry.loops,
      completedLoops: detail.entry.completedLoops,
      startedAt: detail.entry.startedAt,
      finishedAt: detail.entry.finishedAt,
      duration: detail.duration,
      totalSteps: metrics.totalSteps,
      completedSteps: metrics.completedSteps,
      failedSteps: metrics.failedSteps,
      pausedSteps: metrics.pausedSteps,
      visualCheckCount: detail.visualEvidenceEvents.length,
      screenshotCount: detail.screenshotEvidenceRefs
          .where((ref) => _isSafeEvidenceRelativePath(ref.relativePath))
          .length,
    );
  }

  // 输出脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'runId': runId,
      'workflowName': workflowName,
      'status': status,
      'loops': loops,
      'completedLoops': completedLoops,
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'durationMs': duration?.inMilliseconds,
      'totalSteps': totalSteps,
      'completedSteps': completedSteps,
      'failedSteps': failedSteps,
      'pausedSteps': pausedSteps,
      'visualCheckCount': visualCheckCount,
      'screenshotCount': screenshotCount,
    };
  }
}

// RunReportIssue 是报告的问题摘要。
// 它复用 RunFailureAnalysis 并脱敏错误文本。
final class RunReportIssue {
  // 创建报告问题摘要。
  const RunReportIssue({
    required this.category,
    required this.nodeId,
    required this.nodeLabel,
    required this.nodeType,
    required this.loopIndex,
    required this.duration,
    required this.reason,
  });

  final String category;
  final String? nodeId;
  final String? nodeLabel;
  final String? nodeType;
  final int? loopIndex;
  final Duration? duration;
  final String? reason;

  // 从运行详情生成问题摘要。
  factory RunReportIssue.fromDetail(RunDetail detail) {
    final analysis = detail.failureAnalysis;
    return RunReportIssue(
      category: analysis.category,
      nodeId: _sanitizeNullableReportText(analysis.failedNodeId),
      nodeLabel: _sanitizeNullableReportText(analysis.failedNodeLabel),
      nodeType: _sanitizeNullableReportText(analysis.failedNodeType),
      loopIndex: analysis.failedLoopIndex,
      duration: analysis.failedDuration,
      reason: _sanitizeNullableReportText(analysis.reason),
    );
  }

  // 输出脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'category': category,
      'nodeId': nodeId,
      'nodeLabel': nodeLabel,
      'nodeType': nodeType,
      'loopIndex': loopIndex,
      'durationMs': duration?.inMilliseconds,
      'reason': reason,
    };
  }
}

// RunReportTimelineItem 是报告里的节点时间线条目。
// 它只保留节点摘要、状态、耗时和安全截图引用。
final class RunReportTimelineItem {
  // 创建时间线条目。
  const RunReportTimelineItem({
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.loopIndex,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.duration,
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
  final Duration? duration;
  final String? error;
  final String? screenshotPath;

  // 从节点轨迹生成时间线条目。
  factory RunReportTimelineItem.fromTrace(RunNodeTrace trace) {
    final screenshotPath = trace.screenshotPath;
    return RunReportTimelineItem(
      nodeId: _sanitizeReportText(trace.nodeId),
      nodeType: _sanitizeNullableReportText(trace.nodeType),
      label: _sanitizeNullableReportText(trace.label),
      loopIndex: trace.loopIndex,
      status: trace.status,
      startedAt: trace.startedAt,
      finishedAt: trace.finishedAt,
      duration: trace.duration,
      error: _sanitizeNullableReportText(trace.error),
      screenshotPath:
          screenshotPath != null && _isSafeEvidenceRelativePath(screenshotPath)
          ? screenshotPath
          : null,
    );
  }

  // 输出脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nodeId': nodeId,
      'nodeType': nodeType,
      'label': label,
      'loopIndex': loopIndex,
      'status': status,
      'startedAt': startedAt?.toIso8601String(),
      'finishedAt': finishedAt?.toIso8601String(),
      'durationMs': duration?.inMilliseconds,
      'error': error,
      'screenshotPath': screenshotPath,
    };
  }
}

// RunReportVisualCheck 是报告里的视觉判断证据。
// 它描述规则、置信度、动作和原因，不保存原始截图或 source。
final class RunReportVisualCheck {
  // 创建视觉判断报告条目。
  const RunReportVisualCheck({
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.loopIndex,
    required this.rule,
    required this.screenshotAvailable,
    required this.confidence,
    required this.confidenceThreshold,
    required this.result,
    required this.action,
    required this.reason,
    required this.selectedNext,
  });

  final String? nodeId;
  final String? nodeType;
  final String? label;
  final int? loopIndex;
  final String rule;
  final bool screenshotAvailable;
  final double? confidence;
  final double? confidenceThreshold;
  final bool? result;
  final String action;
  final String reason;
  final String? selectedNext;

  // 从事件生成视觉判断条目。
  factory RunReportVisualCheck.fromEvent(RunEvidenceEvent event) {
    final evidence = event.visualEvidence!;
    return RunReportVisualCheck(
      nodeId: _sanitizeNullableReportText(event.nodeId),
      nodeType: _sanitizeNullableReportText(event.nodeType),
      label: _sanitizeNullableReportText(event.label),
      loopIndex: event.loopIndex,
      rule: _sanitizeReportText(evidence.rule),
      screenshotAvailable: evidence.screenshotAvailable,
      confidence: evidence.confidence,
      confidenceThreshold: evidence.confidenceThreshold,
      result: evidence.result,
      action: _sanitizeReportText(evidence.action),
      reason: _sanitizeReportText(evidence.reason),
      selectedNext: _sanitizeNullableReportText(evidence.selectedNext),
    );
  }

  // 输出脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nodeId': nodeId,
      'nodeType': nodeType,
      'label': label,
      'loopIndex': loopIndex,
      'rule': rule,
      'screenshotAvailable': screenshotAvailable,
      'confidence': confidence,
      'confidenceThreshold': confidenceThreshold,
      'result': result,
      'action': action,
      'reason': reason,
      'selectedNext': selectedNext,
    };
  }
}

// RunReportScreenshotItem 是报告截图胶片条目。
// 它只保存 evidence 内安全相对路径。
final class RunReportScreenshotItem {
  // 创建截图胶片条目。
  const RunReportScreenshotItem({
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

  // 从截图引用生成报告截图条目。
  factory RunReportScreenshotItem.fromRef(RunScreenshotEvidenceRef ref) {
    return RunReportScreenshotItem(
      nodeId: _sanitizeReportText(ref.nodeId),
      nodeType: _sanitizeNullableReportText(ref.nodeType),
      label: _sanitizeNullableReportText(ref.label),
      loopIndex: ref.loopIndex,
      status: ref.status,
      duration: ref.duration,
      relativePath: ref.relativePath,
    );
  }

  // 输出脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'nodeId': nodeId,
      'nodeType': nodeType,
      'label': label,
      'loopIndex': loopIndex,
      'status': status,
      'durationMs': duration?.inMilliseconds,
      'relativePath': relativePath,
    };
  }
}

// RunReportLogSummary 是报告里的事件摘要。
// 它只统计事件数量，不保存原始日志内容。
final class RunReportLogSummary {
  // 创建日志摘要。
  const RunReportLogSummary({
    required this.totalEvents,
    required this.warningEvents,
    required this.errorEvents,
    required this.visualEvents,
    required this.screenshotEvents,
    required this.inputSummaryEvents,
  });

  final int totalEvents;
  final int warningEvents;
  final int errorEvents;
  final int visualEvents;
  final int screenshotEvents;
  final int inputSummaryEvents;

  // 从运行详情生成事件摘要。
  factory RunReportLogSummary.fromDetail(RunDetail detail) {
    return RunReportLogSummary(
      totalEvents: detail.events.length,
      warningEvents: detail.events
          .where((event) => _eventLooksLikeWarning(event))
          .length,
      errorEvents: detail.events
          .where((event) => _eventLooksLikeError(event))
          .length,
      visualEvents: detail.visualEvidenceEvents.length,
      screenshotEvents: detail.screenshotEvidenceRefs
          .where((ref) => _isSafeEvidenceRelativePath(ref.relativePath))
          .length,
      inputSummaryEvents: detail.events
          .where((event) => event.hasInputSummary)
          .length,
    );
  }

  // 输出脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'totalEvents': totalEvents,
      'warningEvents': warningEvents,
      'errorEvents': errorEvents,
      'visualEvents': visualEvents,
      'screenshotEvents': screenshotEvents,
      'inputSummaryEvents': inputSummaryEvents,
    };
  }
}

// RunReportPlatformSummary 是 iOS / Android 差异排障摘要。
// 它只保留脱敏平台、设备和日志数量，不保存原始 logcat 或 payload。
final class RunReportPlatformSummary {
  // 创建平台差异摘要。
  const RunReportPlatformSummary({
    required this.platform,
    required this.deviceName,
    required this.maskedDeviceId,
    required this.osVersion,
    required this.connectionKind,
    required this.actionsAllowed,
    required this.logCount,
    required this.hint,
  });

  final String platform;
  final String? deviceName;
  final String? maskedDeviceId;
  final String? osVersion;
  final String? connectionKind;
  final bool? actionsAllowed;
  final int logCount;
  final String hint;

  // 从运行详情提取平台差异摘要，旧数据缺字段时保持 unknown。
  factory RunReportPlatformSummary.fromDetail(RunDetail detail) {
    String? platform;
    String? deviceName;
    String? maskedDeviceId;
    String? osVersion;
    String? connectionKind;
    bool? actionsAllowed;
    int logCount = 0;

    for (final event in detail.events) {
      platform ??= _sanitizeNullableReportText(event.platform);
      deviceName ??= _sanitizeNullableReportText(event.deviceName);
      maskedDeviceId ??= _sanitizeNullableReportText(event.maskedDeviceId);
      osVersion ??= _sanitizeNullableReportText(event.osVersion);
      connectionKind ??= _sanitizeNullableReportText(event.connectionKind);
      actionsAllowed ??= event.actionsAllowed;
      if (event.logCount != null) logCount = event.logCount!;
    }

    final normalizedPlatform = _normalizeReportPlatform(platform);
    return RunReportPlatformSummary(
      platform: normalizedPlatform,
      deviceName: deviceName,
      maskedDeviceId: maskedDeviceId,
      osVersion: osVersion,
      connectionKind: connectionKind,
      actionsAllowed: actionsAllowed,
      logCount: logCount < 0 ? 0 : logCount,
      hint: _platformReportHint(normalizedPlatform, logCount),
    );
  }

  // 输出脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'platform': platform,
      'deviceName': deviceName,
      'maskedDeviceId': maskedDeviceId,
      'osVersion': osVersion,
      'connectionKind': connectionKind,
      'actionsAllowed': actionsAllowed,
      'logCount': logCount,
      'hint': hint,
    };
  }
}

// 便捷获取本地报告，供 Monitor、导出和 AI 工具共用。
extension RunDetailReportExtension on RunDetail {
  RunLocalReport get report => RunLocalReport.fromDetail(this);
}

// 从详情中提取视觉判断条目。
List<RunReportVisualCheck> _visualChecksFromDetail(RunDetail detail) {
  return detail.visualEvidenceEvents
      .map(RunReportVisualCheck.fromEvent)
      .toList(growable: false);
}

// 判断事件是否属于警告。
bool _eventLooksLikeWarning(RunEvidenceEvent event) {
  final normalized = '${event.type} ${event.status}'.toLowerCase();
  return normalized.contains('warning') || normalized.contains('warn');
}

// 判断事件是否属于错误。
bool _eventLooksLikeError(RunEvidenceEvent event) {
  final normalized = '${event.type} ${event.status} ${event.error ?? ''}'
      .toLowerCase();
  return normalized.contains('error') ||
      normalized.contains('failed') ||
      normalized.contains('exception');
}

// 脱敏可空报告文本。
String? _sanitizeNullableReportText(String? value) {
  if (value == null) return null;
  final sanitized = _sanitizeReportText(value);
  return sanitized.isEmpty ? null : sanitized;
}

// 脱敏报告文本，避免路径、设备号和长 session 进入报告 JSON。
String _sanitizeReportText(String value) {
  return value
      .replaceAll(RegExp(r'/Users/[^ \n\r\t]+'), '[path]')
      .replaceAll(RegExp(r'file://[^ \n\r\t]+'), '[path]')
      .replaceAll(
        RegExp(r'http://127\.0\.0\.1:\d+[^ \n\r\t]*'),
        '[local-driver]',
      )
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{8,}-[0-9A-Fa-f]{8,}\b'), '[device]')
      .replaceAll(RegExp(r'\b[0-9a-fA-F]{32,}\b'), '[id]')
      .trim();
}

// 规范化报告平台字段，避免 UI 和 AI 面对多个大小写变体。
String _normalizeReportPlatform(String? platform) {
  final value = platform?.trim().toLowerCase();
  if (value == 'ios') return 'ios';
  if (value == 'android') return 'android';
  return 'unknown';
}

// 根据平台生成短排障提示，不暴露底层 endpoint 或命令。
String _platformReportHint(String platform, int logCount) {
  switch (platform) {
    case 'ios':
      return 'iOS 重点看会话、信任、截图和 WDA 相关状态。';
    case 'android':
      if (logCount > 0) {
        return 'Android 已带日志摘要，可结合界面截图和 logcat 方向排查。';
      }
      return 'Android 暂无日志摘要，优先确认调试授权和 UiAutomator2 会话。';
    default:
      return '旧记录未写入平台字段，只能按通用运行证据复盘。';
  }
}
