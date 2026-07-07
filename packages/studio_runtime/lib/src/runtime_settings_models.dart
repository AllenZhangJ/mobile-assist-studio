part of '../studio_runtime.dart';

// StudioSettings 承载本地工作站设置。
// 这里强制隐私开关始终开启，避免 UI 或 JSON 误关边界。
final class StudioSettings {
  // 创建设置对象，并归一化证据保留和收藏流程列表。
  factory StudioSettings({
    bool hideDeviceIdentifier = true,
    bool hideRawWebDriverPayload = true,
    bool revealScreenshotsByDefault = false,
    bool enablePythonVision = false,
    int evidenceMaxRuns = 20,
    int evidenceMaxAgeDays = 7,
    List<String> favoriteWorkflowIds = const <String>[],
  }) {
    return StudioSettings._(
      hideDeviceIdentifier: true,
      hideRawWebDriverPayload: true,
      revealScreenshotsByDefault: revealScreenshotsByDefault,
      enablePythonVision: enablePythonVision,
      evidenceMaxRuns: _clampEvidenceMaxRuns(evidenceMaxRuns),
      evidenceMaxAgeDays: _clampEvidenceMaxAgeDays(evidenceMaxAgeDays),
      favoriteWorkflowIds: _normalizeFavoriteWorkflowIds(favoriteWorkflowIds),
    );
  }

  const StudioSettings._({
    required this.hideDeviceIdentifier,
    required this.hideRawWebDriverPayload,
    required this.revealScreenshotsByDefault,
    required this.enablePythonVision,
    required this.evidenceMaxRuns,
    required this.evidenceMaxAgeDays,
    required this.favoriteWorkflowIds,
  });

  final bool hideDeviceIdentifier;
  final bool hideRawWebDriverPayload;
  final bool revealScreenshotsByDefault;
  final bool enablePythonVision;
  final int evidenceMaxRuns;
  final int evidenceMaxAgeDays;
  final List<String> favoriteWorkflowIds;

  // 生成新设置快照，隐私硬边界不会被调用方覆盖。
  StudioSettings copyWith({
    bool? hideDeviceIdentifier,
    bool? hideRawWebDriverPayload,
    bool? revealScreenshotsByDefault,
    bool? enablePythonVision,
    int? evidenceMaxRuns,
    int? evidenceMaxAgeDays,
    List<String>? favoriteWorkflowIds,
  }) {
    return StudioSettings(
      hideDeviceIdentifier: true,
      hideRawWebDriverPayload: true,
      revealScreenshotsByDefault:
          revealScreenshotsByDefault ?? this.revealScreenshotsByDefault,
      enablePythonVision: enablePythonVision ?? this.enablePythonVision,
      evidenceMaxRuns: evidenceMaxRuns == null
          ? this.evidenceMaxRuns
          : _clampEvidenceMaxRuns(evidenceMaxRuns),
      evidenceMaxAgeDays: evidenceMaxAgeDays == null
          ? this.evidenceMaxAgeDays
          : _clampEvidenceMaxAgeDays(evidenceMaxAgeDays),
      favoriteWorkflowIds: favoriteWorkflowIds ?? this.favoriteWorkflowIds,
    );
  }

  // 序列化为本地 JSON，供 settings store 持久化。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'hideDeviceIdentifier': hideDeviceIdentifier,
      'hideRawWebDriverPayload': hideRawWebDriverPayload,
      'revealScreenshotsByDefault': revealScreenshotsByDefault,
      'enablePythonVision': enablePythonVision,
      'evidenceMaxRuns': evidenceMaxRuns,
      'evidenceMaxAgeDays': evidenceMaxAgeDays,
      'favoriteWorkflowIds': favoriteWorkflowIds,
    };
  }

  // 从本地 JSON 恢复设置，并修正非法或缺失字段。
  static StudioSettings fromJson(Map<String, Object?> json) {
    return StudioSettings(
      hideDeviceIdentifier: true,
      hideRawWebDriverPayload: true,
      revealScreenshotsByDefault:
          _optionalBool(json['revealScreenshotsByDefault']) ?? false,
      enablePythonVision: _optionalBool(json['enablePythonVision']) ?? false,
      evidenceMaxRuns: _clampEvidenceMaxRuns(
        _optionalInt(json['evidenceMaxRuns']) ?? 20,
      ),
      evidenceMaxAgeDays: _clampEvidenceMaxAgeDays(
        _optionalInt(json['evidenceMaxAgeDays']) ?? 7,
      ),
      favoriteWorkflowIds: _optionalStringList(json['favoriteWorkflowIds']),
    );
  }

  static const defaults = StudioSettings._(
    hideDeviceIdentifier: true,
    hideRawWebDriverPayload: true,
    revealScreenshotsByDefault: false,
    enablePythonVision: false,
    evidenceMaxRuns: 20,
    evidenceMaxAgeDays: 7,
    favoriteWorkflowIds: <String>[],
  );
}

// 读取设置中的字符串列表，只接受合法字符串并交给归一化处理。
List<String> _optionalStringList(Object? value) {
  if (value is! List<Object?>) return const <String>[];
  return _normalizeFavoriteWorkflowIds(
    value.whereType<String>().toList(growable: false),
  );
}

// 归一化本机收藏流程 ID，去空、去重并限制数量。
List<String> _normalizeFavoriteWorkflowIds(List<String> value) {
  final ids = <String>[];
  final seen = <String>{};
  for (final raw in value) {
    final id = raw.trim();
    if (id.isEmpty || seen.contains(id)) continue;
    seen.add(id);
    ids.add(id);
    if (ids.length >= 50) break;
  }
  return List<String>.unmodifiable(ids);
}
