part of '../studio_runtime.dart';

// 本地运行详情分片，负责单次运行详情、事件和截图读取。
extension LocalRunEvidenceStoreDetail on LocalRunEvidenceStore {
  // 读取单次运行详情，并把 JSONL 事件转成强类型模型。
  Future<RunDetail?> _readDetail(String runId) async {
    if (!_isSafeRunId(runId)) return null;
    final directory = Directory('${_rootDirectory.path}/$runId');
    if (!await directory.exists()) return null;
    final entry = await _readRunDirectory(directory);
    if (entry == null) return null;
    final events = await _readRunEvents(File('${directory.path}/events.jsonl'));
    return RunDetail(entry: entry, events: List.unmodifiable(events));
  }

  // 按安全相对路径读取截图资产。
  Future<List<int>?> _readScreenshot(String runId, String relativePath) async {
    if (!_isSafeRunId(runId) || !_isSafeEvidenceRelativePath(relativePath)) {
      return null;
    }
    final file = File('${_rootDirectory.path}/$runId/$relativePath');
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  // 读取运行目录里的 metadata 和 finished 摘要。
  Future<RunHistoryEntry?> _readRunDirectory(Directory directory) async {
    final metadata = await _readJsonObject(
      File('${directory.path}/metadata.json'),
    );
    if (metadata == null) return null;
    final finished = await _readJsonObject(
      File('${directory.path}/finished.json'),
    );
    return RunHistoryEntry(
      runId: metadata['runId']?.toString() ?? directory.path.split('/').last,
      workflowName: metadata['workflowName']?.toString() ?? 'Workflow',
      status: finished?['status']?.toString() ?? 'running',
      loops: _optionalInt(metadata['loops']) ?? 0,
      completedLoops: _optionalInt(finished?['completedLoops']) ?? 0,
      startedAt: _optionalDateTime(metadata['startedAt']),
      finishedAt: _optionalDateTime(finished?['finishedAt']),
    );
  }

  // 读取运行事件 JSONL，坏行会被忽略。
  Future<List<RunEvidenceEvent>> _readRunEvents(File file) async {
    if (!await file.exists()) return const <RunEvidenceEvent>[];
    final lines = await file.readAsLines();
    final events = <RunEvidenceEvent>[];
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(line);
        if (decoded is Map<String, Object?>) {
          events.add(_eventFromJson(decoded));
        }
      } on Object {
        continue;
      }
    }
    return events;
  }

  // 把事件 JSON 映射为运行证据事件模型。
  RunEvidenceEvent _eventFromJson(Map<String, Object?> json) {
    return RunEvidenceEvent(
      type: json['type']?.toString() ?? 'event',
      status: json['status']?.toString(),
      nodeId: json['nodeId']?.toString(),
      nodeType: json['nodeType']?.toString(),
      label: json['label']?.toString(),
      loopIndex: _optionalInt(json['loopIndex']),
      error: json['error']?.toString(),
      screenshotPath: json['screenshotPath']?.toString(),
      at: _optionalDateTime(json['at']),
      visualEvidence: _visualEvidenceFromJson(json),
      inputCount: _optionalInt(json['inputCount']),
      inputNames: _stringListFromJson(json['inputNames']),
      platform: json['platform']?.toString(),
      deviceName: _deviceFieldFromJson(json['device'], 'name'),
      maskedDeviceId: _deviceFieldFromJson(json['device'], 'id'),
      osVersion: _deviceFieldFromJson(json['device'], 'version'),
      connectionKind: _deviceFieldFromJson(json['device'], 'connection'),
      actionsAllowed: _optionalBool(json['actionsAllowed']),
      logCount: _optionalInt(json['count']),
    );
  }

  // 从事件 JSON 提取轻量视觉证据链。
  RunVisualEvidence? _visualEvidenceFromJson(Map<String, Object?> json) {
    final rule = json['visualRule']?.toString();
    final action = json['visualAction']?.toString();
    final reason = json['visualReason']?.toString();
    if (rule == null || action == null || reason == null) return null;
    return RunVisualEvidence(
      rule: rule,
      screenshotAvailable: _optionalBool(json['screenshotAvailable']) ?? false,
      confidence: _optionalDouble(json['confidence']),
      confidenceThreshold: _optionalDouble(json['confidenceThreshold']),
      result: _optionalBool(json['result']),
      action: action,
      reason: reason,
      selectedNext: json['selectedNext']?.toString(),
    );
  }

  // 读取字符串列表字段，过滤非字符串值和空白字段名。
  List<String> _stringListFromJson(Object? value) {
    if (value is! List<Object?>) return const <String>[];
    final items = <String>[];
    for (final item in value) {
      final normalized = item?.toString().trim();
      if (normalized == null || normalized.isEmpty) continue;
      items.add(normalized);
    }
    return List<String>.unmodifiable(items);
  }

  // 从 smoke device 摘要中提取单个安全字段。
  String? _deviceFieldFromJson(Object? value, String key) {
    if (value is! Map<String, Object?>) return null;
    final field = value[key]?.toString().trim();
    return field == null || field.isEmpty ? null : field;
  }

  // 读取 JSON object，解析失败时返回 null。
  Future<Map<String, Object?>?> _readJsonObject(File file) async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) return decoded;
    } on Object {
      return null;
    }
    return null;
  }
}
