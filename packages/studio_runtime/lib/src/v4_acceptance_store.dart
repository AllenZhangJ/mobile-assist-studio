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
  final iosDevice = _acceptanceMapAt(localState, 'iosDevice');
  final androidDevice = _acceptanceMapAt(localState, 'androidDevice');
  final counts = _acceptanceMapAt(archive, 'counts');
  final latestFullSmoke = _acceptanceMapAt(archive, 'latestFullSmoke');
  final gitStatus = _acceptanceMapAt(json, 'gitStatus');
  final timestamp = _stringAt(json, 'timestamp');
  final checkedAt = timestamp == null ? null : DateTime.tryParse(timestamp);
  return V4AcceptanceSummary(
    hasReport: true,
    auditOk: _boolAt(completion, 'auditOk') ?? false,
    complete: _boolAt(completion, 'complete') ?? false,
    statusLabel: _safeAcceptanceTextAt(completion, 'label') ?? '终验未知',
    checkedAt: checkedAt,
    gitRevision: _shortGitRevision(
      _stringAt(gitStatus, 'revision') ?? _stringAt(json, 'git'),
    ),
    gitBranch: _safeGitBranch(_stringAt(gitStatus, 'branch')),
    gitDirty: _boolAt(gitStatus, 'dirty'),
    iosStatus: _safeAcceptanceTextAt(iosDevice, 'status') ?? '未知',
    iosDetail: _safeAcceptanceTextAt(iosDevice, 'detail') ?? '无 iOS 状态。',
    androidStatus: _safeAcceptanceTextAt(androidDevice, 'status') ?? '未知',
    androidDetail: _safeAcceptanceTextAt(androidDevice, 'detail') ?? '无安卓状态。',
    screenshots: _intAt(counts, 'screenshots'),
    iosRuns: _intAt(counts, 'iosRuns'),
    androidRuns: _intAt(counts, 'androidRuns'),
    fullSmokeReports: _intAt(counts, 'fullSmokeReports'),
    latestFullSmokeLabel:
        _safeAcceptanceTextAt(latestFullSmoke, 'label') ?? '暂无',
    failures: _safeAcceptanceTextListAt(completion, 'failures'),
    nextSteps: _safeAcceptanceTextListAt(json, 'nextSteps'),
    batches: _batchSummariesAt(readiness, 'batches'),
    gateGaps: _gateGapSummariesAt(json, 'gateGaps'),
    fieldChecklist: _fieldChecklistAt(json, 'fieldChecklist'),
  );
}

const _allowedV4AcceptanceCommands = <String>{
  'npm run v4:ios-smoke:full',
  'npm run v4:ios-smoke:full:password-prompt',
  'npm run v4:android-smoke:full',
  'npm run v4:smoke:full',
  'npm run v4:smoke:full:password-prompt',
  'npm run v4:smoke-readiness',
  'npm run v4:smoke-archive',
  'npm run v4:acceptance-audit',
  'npm run v4:acceptance-final',
};

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

// 安全读取用户可见文本，并复用连接详情脱敏规则。
String? _safeAcceptanceTextAt(Map<String, Object?> json, String key) {
  final value = _stringAt(json, key);
  return value == null ? null : _redactConnectionDetail(value);
}

// 安全读取可复制命令，只允许项目内 V4 smoke / 终验白名单。
String? _safeAcceptanceCommandAt(Map<String, Object?> json, String key) {
  final value = _stringAt(json, key);
  if (value == null) return null;
  return _allowedV4AcceptanceCommands.contains(value) ? value : null;
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
List<String> _safeAcceptanceTextListAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .map(_redactConnectionDetail)
      .take(6)
      .toList(growable: false);
}

// 读取结构化终验门禁，坏字段跳过并限制条数。
List<V4AcceptanceGateGap> _gateGapSummariesAt(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is! List) return const <V4AcceptanceGateGap>[];
  final gaps = <V4AcceptanceGateGap>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map = Map<String, Object?>.from(item);
    final title = _safeAcceptanceTextAt(map, 'title');
    final current = _safeAcceptanceTextAt(map, 'current');
    final requiredText = _safeAcceptanceTextAt(map, 'required');
    if (title == null || current == null || requiredText == null) continue;
    gaps.add(
      V4AcceptanceGateGap(
        title: title,
        current: current,
        requiredText: requiredText,
        command: _safeAcceptanceCommandAt(map, 'command'),
      ),
    );
    if (gaps.length >= 6) break;
  }
  return List<V4AcceptanceGateGap>.unmodifiable(gaps);
}

// 读取现场补验清单，命令走白名单，文字走脱敏。
List<V4AcceptanceChecklistItem> _fieldChecklistAt(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is! List) return const <V4AcceptanceChecklistItem>[];
  final items = <V4AcceptanceChecklistItem>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map = Map<String, Object?>.from(item);
    final title = _safeAcceptanceTextAt(map, 'title');
    final proof = _safeAcceptanceTextAt(map, 'proof');
    if (title == null || proof == null) continue;
    items.add(
      V4AcceptanceChecklistItem(
        order: _intAt(map, 'order'),
        title: title,
        proof: proof,
        command: _safeAcceptanceCommandAt(map, 'command'),
      ),
    );
    if (items.length >= 6) break;
  }
  items.sort((left, right) => left.order.compareTo(right.order));
  return List<V4AcceptanceChecklistItem>.unmodifiable(items);
}

// 安全读取 Batch 0-8 摘要列表，并对可见文本二次脱敏。
List<V4AcceptanceBatchSummary> _batchSummariesAt(
  Map<String, Object?> json,
  String key,
) {
  final value = json[key];
  if (value is! List) return const <V4AcceptanceBatchSummary>[];
  final batches = <V4AcceptanceBatchSummary>[];
  for (final item in value) {
    if (item is! Map) continue;
    final map = Map<String, Object?>.from(item);
    final name = _safeAcceptanceTextAt(map, 'name');
    final status = _safeAcceptanceTextAt(map, 'status');
    if (name == null || status == null) continue;
    batches.add(
      V4AcceptanceBatchSummary(
        name: name,
        status: status,
        evidence: _safeAcceptanceTextAt(map, 'evidence') ?? '无',
      ),
    );
    if (batches.length >= 9) break;
  }
  return List<V4AcceptanceBatchSummary>.unmodifiable(batches);
}

// Git 字段只保留短提交号，避免未来误写长来源字符串。
String? _shortGitRevision(String? value) {
  if (value == null || value.isEmpty) return null;
  return value.length <= 8 ? value : value.substring(0, 8);
}

// Git 分支仅作为短版本线索展示，同样应用脱敏和长度限制。
String? _safeGitBranch(String? value) {
  if (value == null || value.isEmpty) return null;
  final safe = _redactConnectionDetail(value);
  if (safe.isEmpty) return null;
  return safe.length <= 48 ? safe : '${safe.substring(0, 48)}...';
}
