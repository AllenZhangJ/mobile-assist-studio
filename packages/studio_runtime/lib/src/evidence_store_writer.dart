part of '../studio_runtime.dart';

// 本地证据写入分片，负责 metadata、events、screenshots 和 finish 文件。
extension LocalRunEvidenceStoreWriter on LocalRunEvidenceStore {
  // 创建运行目录并写入 metadata。
  Future<String> _startRun({
    required String workflowName,
    required int loops,
    required DateTime startedAt,
  }) async {
    await _rootDirectory.create(recursive: true);
    final runId = _runId(startedAt);
    final runDirectory = Directory('${_rootDirectory.path}/$runId');
    await runDirectory.create(recursive: true);
    await File('${runDirectory.path}/metadata.json').writeAsString(
      '${jsonEncode(<String, Object?>{'runId': runId, 'workflowName': workflowName, 'loops': loops, 'startedAt': startedAt.toUtc().toIso8601String()})}\n',
    );
    await _cleanup();
    return runId;
  }

  // 追加运行事件，事件时间统一使用 UTC。
  Future<void> _recordEvent(String runId, Map<String, Object?> event) async {
    final runDirectory = Directory('${_rootDirectory.path}/$runId');
    await runDirectory.create(recursive: true);
    final safeEvent = <String, Object?>{
      'at': DateTime.now().toUtc().toIso8601String(),
      ...event,
    };
    await File(
      '${runDirectory.path}/events.jsonl',
    ).writeAsString('${jsonEncode(safeEvent)}\n', mode: FileMode.append);
  }

  // 写入 PNG 截图，只返回相对 evidence 路径。
  Future<String?> _recordScreenshot(
    String runId, {
    required String fileName,
    required String base64Png,
  }) async {
    if (!_isSafeRunId(runId)) return null;
    final safeName = _safeEvidenceFileName(fileName);
    final runDirectory = Directory('${_rootDirectory.path}/$runId');
    final screenshotDirectory = Directory('${runDirectory.path}/screenshots');
    await screenshotDirectory.create(recursive: true);
    final bytes = base64Decode(base64Png);
    await File('${screenshotDirectory.path}/$safeName').writeAsBytes(bytes);
    return 'screenshots/$safeName';
  }

  // 写入运行结束文件并执行滚动清理。
  Future<void> _finishRun(
    String runId, {
    required String status,
    required int completedLoops,
    required DateTime finishedAt,
  }) async {
    final runDirectory = Directory('${_rootDirectory.path}/$runId');
    await runDirectory.create(recursive: true);
    await File('${runDirectory.path}/finished.json').writeAsString(
      '${jsonEncode(<String, Object?>{'runId': runId, 'status': status, 'completedLoops': completedLoops, 'finishedAt': finishedAt.toUtc().toIso8601String()})}\n',
    );
    await _cleanup();
  }

  // 基于开始时间生成稳定 run id。
  String _runId(DateTime startedAt) {
    final timestamp = startedAt.toUtc().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    return 'run-$timestamp';
  }
}
