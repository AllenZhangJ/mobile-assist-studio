part of '../studio_runtime.dart';

// 运行事件模型分片，负责本地证据事件和视觉判断证据。

// RunEvidenceEvent 表示运行证据事件。
// 它只记录节点、状态和证据引用，不保存原始 WebDriver payload。
final class RunEvidenceEvent {
  // 创建运行证据事件。
  const RunEvidenceEvent({
    required this.type,
    required this.status,
    required this.nodeId,
    required this.nodeType,
    required this.label,
    required this.loopIndex,
    required this.error,
    required this.screenshotPath,
    required this.at,
    this.visualEvidence,
    this.inputCount,
    this.inputNames = const <String>[],
    this.platform,
    this.deviceName,
    this.maskedDeviceId,
    this.osVersion,
    this.connectionKind,
    this.actionsAllowed,
    this.logCount,
  });

  final String type;
  final String? status;
  final String? nodeId;
  final String? nodeType;
  final String? label;
  final int? loopIndex;
  final String? error;
  final String? screenshotPath;
  final DateTime? at;
  final RunVisualEvidence? visualEvidence;
  // 子流程传参只保留数量和字段名，避免证据里泄露真实参数值。
  final int? inputCount;
  final List<String> inputNames;
  final String? platform;
  final String? deviceName;
  final String? maskedDeviceId;
  final String? osVersion;
  final String? connectionKind;
  final bool? actionsAllowed;
  final int? logCount;

  // 判断事件是否带有可展示的子流程传参摘要。
  bool get hasInputSummary {
    return inputCount != null || inputNames.isNotEmpty;
  }
}

// RunVisualEvidence 表示一次视觉判断的轻量证据链。
// 它描述规则、置信度和动作，不保存完整 page source。
final class RunVisualEvidence {
  // 创建视觉判断证据。
  const RunVisualEvidence({
    required this.rule,
    required this.screenshotAvailable,
    required this.confidence,
    required this.confidenceThreshold,
    required this.result,
    required this.action,
    required this.reason,
    required this.selectedNext,
  });

  final String rule;
  final bool screenshotAvailable;
  final double? confidence;
  final double? confidenceThreshold;
  final bool? result;
  final String action;
  final String reason;
  final String? selectedNext;
}
