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
      if (!_acceptanceJsonLooksStructurallyValid(decoded)) return null;
      return _acceptanceSummaryFromJson(decoded);
    } on Object {
      return null;
    }
  }
}

// 判断终验 JSON 是否具备最小稳定结构，避免半写入 JSON 覆盖旧有效报告。
bool _acceptanceJsonLooksStructurallyValid(Map<String, Object?> json) {
  if (_stringAt(json, 'kind') != 'v4FinalAcceptance') return false;
  final timestamp = _stringAt(json, 'timestamp');
  if (timestamp == null || DateTime.tryParse(timestamp) == null) return false;
  final completion = _acceptanceMapAt(json, 'completion');
  if (_boolAt(completion, 'auditOk') == null) return false;
  if (_boolAt(completion, 'complete') == null) return false;
  final gitStatus = _acceptanceMapAt(json, 'gitStatus');
  if (!_gitStatusLooksValid(gitStatus)) return false;
  final evidence = _acceptanceMapAt(json, 'evidence');
  final readiness = _acceptanceMapAt(evidence, 'readiness');
  final archive = _acceptanceMapAt(evidence, 'archive');
  if (readiness.isEmpty || archive.isEmpty) return false;
  final localState = _acceptanceMapAt(readiness, 'localState');
  final counts = _acceptanceMapAt(archive, 'counts');
  final iosDevice = _acceptanceMapAt(localState, 'iosDevice');
  final androidDevice = _acceptanceMapAt(localState, 'androidDevice');
  return _deviceStateLooksValid(iosDevice) &&
      _deviceStateLooksValid(androidDevice) &&
      _archiveCountsLookValid(counts) &&
      _batchRowsLookValid(readiness);
}

// 判断代码状态摘要是否足以支撑终验卡，不接受路径或非提交指纹。
bool _gitStatusLooksValid(Map<String, Object?> gitStatus) {
  return _safeGitRevision(_stringAt(gitStatus, 'revision')) != null &&
      _stringAt(gitStatus, 'branch') != null &&
      _boolAt(gitStatus, 'dirty') != null &&
      _boolAt(gitStatus, 'synced') != null &&
      _nullableIntAt(gitStatus, 'ahead') != null &&
      _nullableIntAt(gitStatus, 'behind') != null;
}

// 判断本机设备摘要是否足以支撑 UI 展示，不让空壳状态进入快照。
bool _deviceStateLooksValid(Map<String, Object?> device) {
  return _stringAt(device, 'status') != null &&
      _stringAt(device, 'detail') != null;
}

// 判断归档计数是否包含终验卡需要的四个非负计数字段。
bool _archiveCountsLookValid(Map<String, Object?> counts) {
  return _nullableIntAt(counts, 'screenshots') != null &&
      _nullableIntAt(counts, 'iosRuns') != null &&
      _nullableIntAt(counts, 'androidRuns') != null &&
      _nullableIntAt(counts, 'fullSmokeReports') != null;
}

// 判断 Batch 0-8 摘要是否存在，避免旧报告或半报告误导批次进度。
bool _batchRowsLookValid(Map<String, Object?> readiness) {
  final value = readiness['batches'];
  if (value is! List || value.length < _expectedV4BatchNames.length) {
    return false;
  }
  for (var index = 0; index < _expectedV4BatchNames.length; index += 1) {
    final item = value[index];
    if (item is! Map) return false;
    final map = Map<String, Object?>.from(item);
    if (_stringAt(map, 'name') != _expectedV4BatchNames[index]) return false;
    if (_stringAt(map, 'status') == null) return false;
    if (_stringAt(map, 'evidence') == null) return false;
  }
  return true;
}

const _expectedV4BatchNames = <String>[
  'Batch 0 真源治理',
  'Batch 1 Runtime 基座',
  'Batch 2 双平台 smoke',
  'Batch 3 Inspector',
  'Batch 4 Target / Recorder',
  'Batch 5 Vision Core',
  'Batch 6 Workflow Canvas',
  'Batch 7 Evidence / Report',
  'Batch 8 AI / MCP Core',
];

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
    gitRevision: _safeGitRevision(
      _stringAt(gitStatus, 'revision') ?? _stringAt(json, 'git'),
    ),
    gitBranch: _safeGitBranch(_stringAt(gitStatus, 'branch')),
    gitDirty: _boolAt(gitStatus, 'dirty'),
    gitRemoteSynced: _boolAt(gitStatus, 'synced'),
    gitAhead: _nullableIntAt(gitStatus, 'ahead'),
    gitBehind: _nullableIntAt(gitStatus, 'behind'),
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
  return value == null ? null : _safeAcceptanceVisibleText(value);
}

// 安全读取可复制命令，只允许项目内 V4 smoke / 终验白名单。
String? _safeAcceptanceCommandAt(Map<String, Object?> json, String key) {
  final value = _stringAt(json, key);
  if (value == null) return null;
  return _allowedV4AcceptanceCommands.contains(value) ? value : null;
}

// 清洗终验报告里的用户可见文本，反引号命令只保留白名单。
String _safeAcceptanceVisibleText(String value) {
  final commandSafe = value.replaceAllMapped(RegExp(r'`([^`]+)`'), (match) {
    final command = match.group(1)?.trim();
    if (command != null && _allowedV4AcceptanceCommands.contains(command)) {
      return '`$command`';
    }
    return '`[命令已过滤]`';
  });
  return _redactConnectionDetail(commandSafe);
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

// 安全读取可选整数，未知或负数保持 null。
int? _nullableIntAt(Map<String, Object?> json, String key) {
  final value = json[key];
  final int? number;
  if (value is int) {
    number = value;
  } else if (value is num && value.isFinite && value % 1 == 0) {
    number = value.toInt();
  } else {
    number = null;
  }
  if (number == null || number < 0) return null;
  return number;
}

// 安全读取字符串列表，并限制长度。
List<String> _safeAcceptanceTextListAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) return const <String>[];
  return value
      .whereType<String>()
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .map(_safeAcceptanceVisibleText)
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

// Git 字段只接受提交指纹并保留短值，避免未来误写路径或来源字符串。
String? _safeGitRevision(String? value) {
  if (value == null || value.isEmpty) return null;
  final normalized = value.trim();
  if (!RegExp(r'^[0-9a-fA-F]{7,40}$').hasMatch(normalized)) return null;
  return normalized.length <= 8 ? normalized : normalized.substring(0, 8);
}

// Git 分支仅作为短版本线索展示，同样应用脱敏和长度限制。
String? _safeGitBranch(String? value) {
  if (value == null || value.isEmpty) return null;
  final safe = _safeAcceptanceVisibleText(value);
  if (safe.isEmpty) return null;
  return safe.length <= 48 ? safe : '${safe.substring(0, 48)}...';
}
