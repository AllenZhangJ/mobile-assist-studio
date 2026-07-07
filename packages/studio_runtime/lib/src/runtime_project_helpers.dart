part of '../studio_runtime.dart';

// 生成本机流程副本 ID，只使用流程 ID 和时间戳，不写入设备信息。
String _workflowCopyId(String sourceId, DateTime now) {
  final safeSource = sourceId
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-');
  final base = safeSource.isEmpty ? 'workflow' : safeSource;
  return '$base-copy-${now.toUtc().microsecondsSinceEpoch}';
}

// 生成用户可读的副本名称，保持短中文表达。
String _workflowCopyName(String sourceName) {
  final name = sourceName.trim();
  if (name.isEmpty) return '流程副本';
  if (name.endsWith('副本')) return '$name 2';
  return '$name 副本';
}

// 生成本机子流程副本 ID，避免覆盖主流程和已有子流程。
String _subWorkflowCopyId(String workflowId, DateTime now) {
  final stamp =
      '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  return '$workflowId-sub-$stamp';
}
