part of '../studio_runtime.dart';

// V4AcceptanceSummaryReader 读取最新 V4 终验摘要。
// Flutter UI 不直接扫文件，统一从 Runtime snapshot 消费结果。
abstract interface class V4AcceptanceSummaryReader {
  // 读取最新终验摘要；无报告时返回 empty。
  Future<V4AcceptanceSummary> readLatest();
}

// NoopV4AcceptanceSummaryReader 用于无项目目录和测试默认状态。
final class NoopV4AcceptanceSummaryReader implements V4AcceptanceSummaryReader {
  // 创建空终验摘要 reader。
  const NoopV4AcceptanceSummaryReader();

  @override
  Future<V4AcceptanceSummary> readLatest() async => V4AcceptanceSummary.empty;
}

// LocalV4AcceptanceSummaryReader 从本地 recordings/v4-smoke/acceptance 读取摘要。
// 它只解析稳定 JSON 字段，不把文件路径、stdout 或 stderr 带入 UI。
final class LocalV4AcceptanceSummaryReader
    implements V4AcceptanceSummaryReader {
  // 创建本地终验摘要 reader。
  const LocalV4AcceptanceSummaryReader({required this.directory});

  final Directory directory;

  @override
  Future<V4AcceptanceSummary> readLatest() async {
    if (!directory.existsSync()) return V4AcceptanceSummary.empty;
    final files =
        directory.listSync(followLinks: false).whereType<File>().where((file) {
          final name = _fileName(file);
          return name.startsWith('FINAL_ACCEPTANCE_') && name.endsWith('.json');
        }).toList()..sort((a, b) => _fileName(b).compareTo(_fileName(a)));
    for (final file in files) {
      final summary = _tryReadAcceptanceSummary(file);
      if (summary != null) return summary;
    }
    return V4AcceptanceSummary.empty;
  }

  // 读取并解析单个终验 JSON，坏文件返回 null。
  V4AcceptanceSummary? _tryReadAcceptanceSummary(File file) {
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?>) return null;
      return _acceptanceSummaryFromJson(decoded);
    } on Object {
      return null;
    }
  }
}

// 把终验 JSON 转为脱敏摘要。
V4AcceptanceSummary _acceptanceSummaryFromJson(Map<String, Object?> json) {
  final completion = _acceptanceMapAt(json, 'completion');
  final evidence = _acceptanceMapAt(json, 'evidence');
  final readiness = _acceptanceMapAt(evidence, 'readiness');
  final archive = _acceptanceMapAt(evidence, 'archive');
  final localState = _acceptanceMapAt(readiness, 'localState');
  final androidDevice = _acceptanceMapAt(localState, 'androidDevice');
  final counts = _acceptanceMapAt(archive, 'counts');
  final latestFullSmoke = _acceptanceMapAt(archive, 'latestFullSmoke');
  final timestamp = _stringAt(json, 'timestamp');
  final checkedAt = timestamp == null ? null : DateTime.tryParse(timestamp);
  return V4AcceptanceSummary(
    hasReport: true,
    auditOk: _boolAt(completion, 'auditOk') ?? false,
    complete: _boolAt(completion, 'complete') ?? false,
    statusLabel: _stringAt(completion, 'label') ?? '终验未知',
    checkedAt: checkedAt,
    gitRevision: _shortGitRevision(_stringAt(json, 'git')),
    androidStatus: _stringAt(androidDevice, 'status') ?? '未知',
    androidDetail: _stringAt(androidDevice, 'detail') ?? '无安卓状态。',
    screenshots: _intAt(counts, 'screenshots'),
    iosRuns: _intAt(counts, 'iosRuns'),
    androidRuns: _intAt(counts, 'androidRuns'),
    fullSmokeReports: _intAt(counts, 'fullSmokeReports'),
    latestFullSmokeLabel: _stringAt(latestFullSmoke, 'label') ?? '暂无',
    failures: _stringListAt(completion, 'failures'),
    nextSteps: _stringListAt(json, 'nextSteps'),
  );
}

// 获取文件名，避免 UI 或模型保存完整路径。
String _fileName(File file) {
  return file.uri.pathSegments.isEmpty ? file.path : file.uri.pathSegments.last;
}

// 安全读取 JSON 对象字段。
Map<String, Object?> _acceptanceMapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry('$key', value));
  }
  return const <String, Object?>{};
}

// 安全读取字符串字段。
String? _stringAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

// 安全读取 bool 字段。
bool? _boolAt(Map<String, Object?> json, String key) {
  final value = json[key];
  return value is bool ? value : null;
}

// 安全读取整数计数。
int _intAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

// 安全读取字符串列表，并限制长度。
List<String> _stringListAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .take(6)
      .toList(growable: false);
}

// Git 字段只保留短提交号，避免未来误写长来源字符串。
String? _shortGitRevision(String? value) {
  if (value == null || value.isEmpty) return null;
  return value.length <= 8 ? value : value.substring(0, 8);
}
