part of '../studio_runtime.dart';

// 本地报告导出分片，负责把 Runtime 报告写为脱敏 JSON 文件。
extension LocalRunEvidenceStoreReportExport on LocalRunEvidenceStore {
  // 导出单次运行报告；缺少详情时返回空结果。
  Future<RunReportExportResult?> _exportReport(String runId) async {
    if (!_isSafeRunId(runId)) return null;
    final detail = await _readDetail(runId);
    if (detail == null) return null;
    final report = detail.report;
    final exportedAt = DateTime.now().toUtc();
    final fileName = _safeRunReportFileName(runId);
    final directory = Directory('${_rootDirectory.path}/$runId/exports');
    await directory.create(recursive: true);
    final file = File('${directory.path}/$fileName');
    await file.writeAsString('${_runReportExportJson(report)}\n');
    return RunReportExportResult(
      runId: _sanitizeReportText(runId),
      fileName: fileName,
      relativePath: 'exports/$fileName',
      exportedAt: exportedAt,
    );
  }

  // 生成稳定且安全的报告文件名。
  String _safeRunReportFileName(String runId) {
    final sanitized = runId.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final stem = sanitized.isEmpty ? 'run-report' : sanitized;
    return '$stem-report.json';
  }

  // 把报告序列化为缩进 JSON，便于人工阅读和归档。
  String _runReportExportJson(RunLocalReport report) {
    return const JsonEncoder.withIndent('  ').convert(report.toJson());
  }
}
