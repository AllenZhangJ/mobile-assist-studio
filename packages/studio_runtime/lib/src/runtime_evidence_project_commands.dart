part of '../studio_runtime.dart';

// Runtime 证据项目命令，负责运行历史、详情和截图证据读取。
// 这些命令只读取本地 evidence 真源，不修改设备连接和执行状态。
extension StudioRuntimeEvidenceProjectCommands on StudioRuntimeController {
  // 刷新本地运行历史摘要，只读取 evidence 真源。
  // 读取失败只写事件，不破坏当前运行时状态。
  Future<void> refreshRunHistory({int limit = 10}) async {
    try {
      final summary = await _runHistoryReader.readSummary(limit: limit);
      _emit(_snapshot.copyWith(runHistory: summary));
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '运行记录刷新失败：$error')),
      );
    }
  }

  // 读取单次运行详情，供 Execute 和 Monitor 共用同一详情入口。
  // 读取失败返回 null，避免 UI 打开空详情时崩溃。
  Future<RunDetail?> readRunDetail(String runId) async {
    try {
      return await _runDetailReader.readDetail(runId);
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '运行详情读取失败：$error')),
      );
      return null;
    }
  }

  // 读取单次运行本地报告，供 Monitor、导出和 AI 解释复用。
  // 读取失败返回 null，避免报告入口影响主流程。
  Future<RunLocalReport?> readRunReport(String runId) async {
    try {
      return await _runReportReader.readReport(runId);
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '运行报告读取失败：$error')),
      );
      return null;
    }
  }

  // 导出单次运行本地报告 JSON，供 Monitor、Execute 和 AI 留档复用。
  // 导出失败返回 null，只写短事件，不影响设备连接和运行状态。
  Future<RunReportExportResult?> exportRunReport(String runId) async {
    try {
      return await _runReportExporter.exportReport(runId);
    } on Object catch (_) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '报告导出失败。')));
      return null;
    }
  }

  // 读取某次运行的本地截图证据，路径仍由 evidence 读者校验。
  // 读取失败返回 null，不把本机路径或底层异常暴露为状态真源。
  Future<List<int>?> readRunScreenshotEvidence(
    String runId,
    String relativePath,
  ) async {
    try {
      return await _runEvidenceAssetReader.readScreenshot(runId, relativePath);
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '截图证据读取失败：$error')),
      );
      return null;
    }
  }
}
