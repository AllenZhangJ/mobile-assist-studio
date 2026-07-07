part of '../studio_runtime.dart';

// 运行证据写入接口，供 Runtime 执行链记录本地证据。
abstract interface class RunEvidenceStore {
  Future<String> startRun({
    required String workflowName,
    required int loops,
    required DateTime startedAt,
  });

  Future<void> recordEvent(String runId, Map<String, Object?> event);

  Future<String?> recordScreenshot(
    String runId, {
    required String fileName,
    required String base64Png,
  });

  Future<void> finishRun(
    String runId, {
    required String status,
    required int completedLoops,
    required DateTime finishedAt,
  });
}

// 运行历史读取接口，供 Monitor 和 Dashboard 使用。
abstract interface class RunHistoryReader {
  Future<RunHistorySummary> readSummary({int limit = 10});
}

// 单次运行详情读取接口，供 Run Detail Drawer 使用。
abstract interface class RunDetailReader {
  Future<RunDetail?> readDetail(String runId);
}

// 单次运行报告读取接口，供 Monitor、导出和 AI 解释复用。
abstract interface class RunReportReader {
  Future<RunLocalReport?> readReport(String runId);
}

// 单次运行报告导出接口，供 UI 和 AI 留档复用。
abstract interface class RunReportExporter {
  Future<RunReportExportResult?> exportReport(String runId);
}

// 运行证据资产读取接口，供截图回放按需读取缩略图。
abstract interface class RunEvidenceAssetReader {
  Future<List<int>?> readScreenshot(String runId, String relativePath);
}

// 空证据存储，供测试和无本地证据环境降级使用。
final class NoopRunEvidenceStore
    implements
        RunEvidenceStore,
        RunHistoryReader,
        RunDetailReader,
        RunReportReader,
        RunReportExporter,
        RunEvidenceAssetReader {
  const NoopRunEvidenceStore();

  // 返回固定 noop run id，不写任何本地文件。
  @override
  Future<String> startRun({
    required String workflowName,
    required int loops,
    required DateTime startedAt,
  }) async {
    return 'noop';
  }

  // 忽略事件写入，保持调用链可运行。
  @override
  Future<void> recordEvent(String runId, Map<String, Object?> event) async {}

  // 忽略截图写入，返回空引用。
  @override
  Future<String?> recordScreenshot(
    String runId, {
    required String fileName,
    required String base64Png,
  }) async {
    return null;
  }

  // 忽略结束写入，保持调用链可运行。
  @override
  Future<void> finishRun(
    String runId, {
    required String status,
    required int completedLoops,
    required DateTime finishedAt,
  }) async {}

  // 返回空历史摘要。
  @override
  Future<RunHistorySummary> readSummary({int limit = 10}) async {
    return RunHistorySummary.empty;
  }

  // 返回空运行详情。
  @override
  Future<RunDetail?> readDetail(String runId) async {
    return null;
  }

  // 返回空运行报告。
  @override
  Future<RunLocalReport?> readReport(String runId) async {
    return null;
  }

  // 返回空导出结果。
  @override
  Future<RunReportExportResult?> exportReport(String runId) async {
    return null;
  }

  // 返回空截图资产。
  @override
  Future<List<int>?> readScreenshot(String runId, String relativePath) async {
    return null;
  }
}

// 本地运行证据存储，负责文件布局和对外接口委托。
final class LocalRunEvidenceStore
    implements
        RunEvidenceStore,
        RunHistoryReader,
        RunDetailReader,
        RunReportReader,
        RunReportExporter,
        RunEvidenceAssetReader {
  LocalRunEvidenceStore({
    required Directory rootDirectory,
    int maxRuns = 20,
    int maxAgeDays = 7,
  }) : _rootDirectory = rootDirectory,
       maxRuns = _clampEvidenceMaxRuns(maxRuns),
       maxAgeDays = _clampEvidenceMaxAgeDays(maxAgeDays);

  final Directory _rootDirectory;
  int maxRuns;
  int maxAgeDays;

  // 更新运行证据保留数量，并立即应用滚动清理。
  Future<void> updateMaxRuns(int value) async {
    maxRuns = _clampEvidenceMaxRuns(value);
    await _cleanup();
  }

  // 更新运行证据保留策略，并立即按条数和天数滚动清理。
  Future<void> updateRetention({
    required int maxRuns,
    required int maxAgeDays,
  }) async {
    this.maxRuns = _clampEvidenceMaxRuns(maxRuns);
    this.maxAgeDays = _clampEvidenceMaxAgeDays(maxAgeDays);
    await _cleanup();
  }

  // 创建本地运行目录和 metadata。
  @override
  Future<String> startRun({
    required String workflowName,
    required int loops,
    required DateTime startedAt,
  }) {
    return _startRun(
      workflowName: workflowName,
      loops: loops,
      startedAt: startedAt,
    );
  }

  // 追加一条本地 JSONL 运行事件。
  @override
  Future<void> recordEvent(String runId, Map<String, Object?> event) {
    return _recordEvent(runId, event);
  }

  // 写入一张截图证据，返回相对 evidence 路径。
  @override
  Future<String?> recordScreenshot(
    String runId, {
    required String fileName,
    required String base64Png,
  }) {
    return _recordScreenshot(runId, fileName: fileName, base64Png: base64Png);
  }

  // 写入运行结束摘要并触发滚动清理。
  @override
  Future<void> finishRun(
    String runId, {
    required String status,
    required int completedLoops,
    required DateTime finishedAt,
  }) {
    return _finishRun(
      runId,
      status: status,
      completedLoops: completedLoops,
      finishedAt: finishedAt,
    );
  }

  // 读取 Monitor 使用的本地运行摘要。
  @override
  Future<RunHistorySummary> readSummary({int limit = 10}) {
    return _readSummary(limit: limit);
  }

  // 读取单次运行详情。
  @override
  Future<RunDetail?> readDetail(String runId) {
    return _readDetail(runId);
  }

  // 读取单次运行本地报告。
  @override
  Future<RunLocalReport?> readReport(String runId) async {
    final detail = await _readDetail(runId);
    return detail?.report;
  }

  // 导出单次运行本地报告 JSON。
  @override
  Future<RunReportExportResult?> exportReport(String runId) {
    return _exportReport(runId);
  }

  // 按相对路径读取截图资产。
  @override
  Future<List<int>?> readScreenshot(String runId, String relativePath) {
    return _readScreenshot(runId, relativePath);
  }

  // 清理超过保留策略的旧运行目录，先按天数再按数量兜底。
  Future<void> _cleanup() async {
    if (maxRuns < 1 || !await _rootDirectory.exists()) return;
    final entries = await _rootDirectory
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    if (entries.isEmpty) return;
    final sortable = <({Directory directory, DateTime changed})>[];
    for (final directory in entries) {
      final stat = await directory.stat();
      final run = await _readRunDirectory(directory);
      sortable.add((
        directory: directory,
        changed: run?.finishedAt ?? run?.startedAt ?? stat.changed,
      ));
    }
    sortable.sort((a, b) => b.changed.compareTo(a.changed));
    final anchor = sortable.first.changed;
    final cutoff = anchor.subtract(Duration(days: maxAgeDays));
    final retained = <({Directory directory, DateTime changed})>[];
    for (final entry in sortable) {
      if (entry.changed.isBefore(cutoff)) {
        await entry.directory.delete(recursive: true);
      } else {
        retained.add(entry);
      }
    }
    for (final stale in retained.skip(maxRuns)) {
      await stale.directory.delete(recursive: true);
    }
  }
}
