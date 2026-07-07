part of '../studio_runtime.dart';

// 本地证据安全与解析 helper 分片，只承载文件名、路径和轻量字段解析。
// 聚合统计已迁入 evidence_store_aggregations.dart，避免职责混杂。

// 校验 run id，避免截图读取逃逸到运行目录之外。
bool _isSafeRunId(String runId) {
  return RegExp(r'^run-[A-Za-z0-9TZ+\-]+$').hasMatch(runId);
}

// 校验证据相对路径，只允许 screenshots 下的安全文件名。
bool _isSafeEvidenceRelativePath(String relativePath) {
  if (!relativePath.startsWith('screenshots/')) return false;
  final name = relativePath.substring('screenshots/'.length);
  return name.isNotEmpty && name == _safeEvidenceFileName(name);
}

// 清洗证据文件名，只保留本地 PNG 资产需要的安全字符。
String _safeEvidenceFileName(String fileName) {
  final sanitized = fileName.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
    return 'evidence.png';
  }
  return sanitized.endsWith('.png') ? sanitized : '$sanitized.png';
}

// 尝试读取可空时间。
DateTime? _optionalDateTime(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
