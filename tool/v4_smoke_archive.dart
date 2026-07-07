import 'dart:async';
import 'dart:convert';
import 'dart:io';

// V4 smoke archive 为本地 smoke 结果和截图生成脱敏索引。
// 它只扫描本地 evidence，不读取截图内容、不上传、不复制到仓库。
Future<void> main(List<String> args) async {
  final options = _ArchiveOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  final timestamp = DateTime.now().toUtc();
  final archive = await _buildArchive(options, timestamp);
  await options.archiveDir.create(recursive: true);
  final base =
      '${options.archiveDir.path}/SMOKE_ARCHIVE_${_safeTimestamp(timestamp)}';
  final jsonFile = File('$base.json');
  final markdownFile = File('$base.md');
  await jsonFile.writeAsString(archive.toJsonString(), flush: true);
  await markdownFile.writeAsString(archive.toMarkdown(), flush: true);

  stdout
    ..writeln('Smoke archive report: ${_redactText(markdownFile.path)}')
    ..writeln('Smoke archive json: ${_redactText(jsonFile.path)}');

  final failures = _finalGateFailures(
    options,
    archive.summary,
    currentGit: archive.git,
  );
  if (failures.isNotEmpty) {
    stderr.writeln('V4 smoke archive failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(2);
  }
}

// 根据严格参数生成最终验收缺口，避免一次只暴露一个问题。
List<String> _finalGateFailures(
  _ArchiveOptions options,
  _ArchiveSummary summary, {
  required String currentGit,
}) {
  return <String>[
    if (options.requireScreenshot && summary.screenshots == 0) '未发现截图留档。',
    if (options.requirePlatformRuns && summary.iosRuns == 0)
      '未发现 iOS 平台 smoke run。',
    if (options.requirePlatformRuns && summary.androidRuns == 0)
      '未发现 Android 平台 smoke run。',
    if (options.requirePlatformRuns &&
        options.requireComplete &&
        summary.iosRuns > 0 &&
        !summary.latestIosSmokeFullMatchesGit(currentGit))
      '最近 iOS 平台 smoke run 尚未在当前提交完整通过。',
    if (options.requirePlatformRuns &&
        options.requireComplete &&
        summary.androidRuns > 0 &&
        !summary.latestAndroidSmokeFullMatchesGit(currentGit))
      '最近 Android 平台 smoke run 尚未在当前提交完整通过。',
    if (options.requireComplete && !summary.latestFullSmokeComplete)
      '最近 full smoke 尚未完整通过。',
    if (options.requireComplete &&
        summary.latestFullSmokeComplete &&
        !summary.latestFullSmokeMatchesGit(currentGit))
      '最近 full smoke 不属于当前提交。',
  ];
}

// 构建 archive 报告，扫描前会排除 archive 输出目录，避免自我递增。
Future<_SmokeArchiveReport> _buildArchive(
  _ArchiveOptions options,
  DateTime timestamp,
) async {
  final git = await _currentGitCommit(options.timeout);
  final artifacts = await _scanArtifacts(
    outDir: options.outDir,
    archiveDir: options.archiveDir,
  );
  final latestReadiness = await _latestJsonSummary(
    outDir: options.outDir,
    artifacts: artifacts,
    kind: _ArtifactKind.readinessJson,
  );
  final latestFullSmoke = await _latestJsonSummary(
    outDir: options.outDir,
    artifacts: artifacts,
    kind: _ArtifactKind.fullSmokeJson,
  );
  final latestIosSmoke = await _latestPlatformRunSummary(options.outDir, 'ios');
  final latestAndroidSmoke = await _latestPlatformRunSummary(
    options.outDir,
    'android',
  );
  final summary = _ArchiveSummary.fromArtifacts(
    artifacts: artifacts,
    latestReadiness: latestReadiness,
    latestFullSmoke: latestFullSmoke,
    latestIosSmoke: latestIosSmoke,
    latestAndroidSmoke: latestAndroidSmoke,
  );
  return _SmokeArchiveReport(
    timestamp: timestamp,
    git: git,
    sourceDir: _redactText(options.outDir.path),
    summary: summary,
    artifacts: artifacts,
  );
}

// 扫描本地 smoke 目录，记录文件名、相对路径、大小和更新时间。
Future<List<_ArtifactEntry>> _scanArtifacts({
  required Directory outDir,
  required Directory archiveDir,
}) async {
  if (!await outDir.exists()) return const <_ArtifactEntry>[];
  final root = outDir.absolute;
  final archiveRoot = archiveDir.absolute;
  final entries = <_ArtifactEntry>[];

  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (_isInside(parent: archiveRoot, child: entity.absolute)) continue;
    final stat = await entity.stat();
    final relativePath = _relativePath(root: root, entity: entity);
    entries.add(
      _ArtifactEntry(
        kind: _classifyArtifact(relativePath),
        relativePath: _redactText(relativePath),
        bytes: stat.size,
        modifiedAt: stat.modified.toUtc(),
        platform: _platformFromPath(relativePath),
        runName: _runNameFromPath(relativePath),
      ),
    );
  }

  entries.sort(
    (left, right) => left.relativePath.compareTo(right.relativePath),
  );
  return entries;
}

// 判断 child 是否位于 parent 目录下。
bool _isInside({required Directory parent, required FileSystemEntity child}) {
  final parentPath = _normalizePath(parent.path);
  final childPath = _normalizePath(child.path);
  return childPath == parentPath || childPath.startsWith('$parentPath/');
}

// 计算相对路径；无法相对时返回脱敏绝对路径。
String _relativePath({
  required Directory root,
  required FileSystemEntity entity,
}) {
  final rootPath = _normalizePath(root.path);
  final entityPath = _normalizePath(entity.path);
  if (entityPath == rootPath) return '.';
  if (entityPath.startsWith('$rootPath/')) {
    return entityPath.substring(rootPath.length + 1);
  }
  return _redactText(entityPath);
}

// 归一化路径分隔符和尾部斜线。
String _normalizePath(String value) {
  var result = value.replaceAll('\\', '/');
  while (result.length > 1 && result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

// 根据相对路径分类 artifact。
_ArtifactKind _classifyArtifact(String relativePath) {
  final name = relativePath.split('/').last;
  if (RegExp(r'^SMOKE_READINESS_.*\.json$').hasMatch(name)) {
    return _ArtifactKind.readinessJson;
  }
  if (RegExp(r'^SMOKE_READINESS_.*\.md$').hasMatch(name)) {
    return _ArtifactKind.readinessMarkdown;
  }
  if (RegExp(r'^FULL_SMOKE_.*\.json$').hasMatch(name)) {
    return _ArtifactKind.fullSmokeJson;
  }
  if (RegExp(r'^FULL_SMOKE_.*\.md$').hasMatch(name)) {
    return _ArtifactKind.fullSmokeMarkdown;
  }
  if (name == 'metadata.json') return _ArtifactKind.runMetadata;
  if (name == 'events.jsonl') return _ArtifactKind.runEvents;
  if (name == 'finished.json') return _ArtifactKind.runFinished;
  if (RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false).hasMatch(name)) {
    return _ArtifactKind.screenshot;
  }
  return _ArtifactKind.other;
}

// 从路径中识别平台目录。
String? _platformFromPath(String relativePath) {
  if (relativePath.startsWith('ios/')) return 'ios';
  if (relativePath.startsWith('android/')) return 'android';
  return null;
}

// 从路径中识别 run 目录名。
String? _runNameFromPath(String relativePath) {
  for (final part in relativePath.split('/')) {
    if (part.startsWith('run-')) return _redactText(part);
  }
  return null;
}

// 只接受短 hash 或 unknown，避免 archive 报告吸入长命令输出。
String? _shortGitRevision(Object? value) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) return null;
  if (raw == 'unknown') return raw;
  return RegExp(r'^[0-9a-fA-F]{7,12}$').hasMatch(raw) ? raw : null;
}

// 读取最新 JSON 摘要，只读取结构化报告，不读取截图或事件隐私内容。
Future<_ReportJsonSummary?> _latestJsonSummary({
  required Directory outDir,
  required List<_ArtifactEntry> artifacts,
  required _ArtifactKind kind,
}) async {
  final candidates =
      artifacts.where((entry) => entry.kind == kind).toList(growable: false)
        ..sort(
          (left, right) => right.relativePath.compareTo(left.relativePath),
        );
  if (candidates.isEmpty) return null;
  for (final candidate in candidates) {
    final file = File('${outDir.path}/${candidate.relativePath}');
    if (!await file.exists()) continue;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) continue;
      return _ReportJsonSummary.fromJson(Map<String, Object?>.from(decoded));
    } on Object {
      continue;
    }
  }
  return null;
}

// 读取最近平台 smoke run 的结构化摘要，只读取元数据和事件类型。
Future<_PlatformRunSummary?> _latestPlatformRunSummary(
  Directory outDir,
  String platform,
) async {
  final dir = Directory('${outDir.path}/$platform');
  if (!await dir.exists()) return null;
  final runs = <Directory>[];
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is Directory && _entityName(entity).startsWith('run-')) {
      runs.add(entity);
    }
  }
  if (runs.isEmpty) return null;
  runs.sort((left, right) {
    return _entityName(right).compareTo(_entityName(left));
  });
  return _readPlatformRunSummary(runs.first, platform);
}

// 解析单个平台 run，避免 archive final 只靠目录数量误判通过。
Future<_PlatformRunSummary> _readPlatformRunSummary(
  Directory dir,
  String platform,
) async {
  final metadata = await _readJsonObject(File('${dir.path}/metadata.json'));
  final finished = await _readJsonObject(File('${dir.path}/finished.json'));
  final events = await _readEventObjects(File('${dir.path}/events.jsonl'));
  final eventTypes = events
      .map((event) => event['type']?.toString() ?? '')
      .where((type) => type.isNotEmpty)
      .toSet();
  final screenshotFileCount = await _countPlatformRunScreenshots(dir);
  return _PlatformRunSummary(
    platform: platform,
    runName: _redactText(_entityName(dir)),
    git: _shortGitRevision(
      metadata?['git'] ??
          finished?['git'] ??
          _firstEventField(events, 'smokeStart', 'git'),
    ),
    status: finished?['status']?.toString() ?? 'running',
    actionsAllowed: _eventBool(events, 'smokeStart', 'actionsAllowed'),
    hasScreenshot: eventTypes.contains('smokeScreenshot'),
    screenshotFileCount: screenshotFileCount,
    workflowExecuted: eventTypes.contains('smokeWorkflowStart'),
    actionNames: _smokeActionNames(events),
    logsCollected: eventTypes.contains('smokeLogs'),
  );
}

// 统计同一平台 run 目录下的截图文件，避免全局旧截图替代本次证据。
Future<int> _countPlatformRunScreenshots(Directory runDir) async {
  final dir = Directory('${runDir.path}/screenshots');
  if (!await dir.exists()) return 0;
  var count = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final name = _entityName(entity);
    if (!RegExp(r'\.(png|jpg|jpeg)$', caseSensitive: false).hasMatch(name)) {
      continue;
    }
    final stat = await entity.stat();
    if (stat.size > 0) count += 1;
  }
  return count;
}

// 读取文件或目录名，兼容 Directory URI 尾斜线。
String _entityName(FileSystemEntity entity) {
  return _normalizePath(entity.path).split('/').last;
}

// 安全读取 JSON object，坏文件按缺失处理。
Future<Map<String, Object?>?> _readJsonObject(File file) async {
  if (!await file.exists()) return null;
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
  } on Object {
    return null;
  }
  return null;
}

// 读取 JSONL 事件；坏行跳过，避免一条损坏影响 archive。
Future<List<Map<String, Object?>>> _readEventObjects(File file) async {
  if (!await file.exists()) return const <Map<String, Object?>>[];
  final events = <Map<String, Object?>>[];
  try {
    final lines = await file.readAsLines();
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, Object?>) {
        events.add(decoded);
      } else if (decoded is Map) {
        events.add(Map<String, Object?>.from(decoded));
      }
    }
  } on Object {
    return events;
  }
  return events;
}

// 读取第一条指定事件字段。
Object? _firstEventField(
  List<Map<String, Object?>> events,
  String type,
  String field,
) {
  for (final event in events) {
    if (event['type'] == type && event.containsKey(field)) return event[field];
  }
  return null;
}

// 从指定事件读取布尔字段。
bool? _eventBool(List<Map<String, Object?>> events, String type, String field) {
  for (final event in events) {
    if (event['type'] != type) continue;
    final value = event[field];
    if (value is bool) return value;
  }
  return null;
}

// 提取真实交互动作，用于判断平台 smoke 是否完整。
Set<String> _smokeActionNames(List<Map<String, Object?>> events) {
  final actions = <String>{};
  for (final event in events) {
    final type = event['type']?.toString();
    if (type == 'smokeAction') {
      _addSmokeAction(actions, event['action']);
      continue;
    }
    if (type == 'smokeWorkflowStep') {
      _addSmokeAction(actions, event['nodeType']);
      _addSmokeAction(actions, event['action']);
    }
  }
  return actions;
}

// 归一化动作名，保持和 readiness 的完整冒烟标准一致。
void _addSmokeAction(Set<String> actions, Object? raw) {
  final normalized = _normalizeSmokeAction(raw);
  if (normalized != null) actions.add(normalized);
}

// 将 Appium / workflow 事件动作名收敛为 tap / swipe / input。
String? _normalizeSmokeAction(Object? raw) {
  final value = raw?.toString().trim().toLowerCase();
  return switch (value) {
    'tap' || 'click' || 'press' => 'tap',
    'swipe' || 'drag' => 'swipe',
    'input' || 'text' || 'sendkeys' || 'send_keys' => 'input',
    _ => null,
  };
}

// 当前 git commit 只保留短 hash，失败时返回 unknown。
Future<String> _currentGitCommit(Duration timeout) async {
  final result = await _runProcess('git', const [
    'rev-parse',
    '--short',
    'HEAD',
  ], timeout: timeout);
  if (result.exitCode != 0) return 'unknown';
  final value = result.stdout.trim();
  return value.isEmpty ? 'unknown' : value;
}

// 执行短命令，避免 archive 卡住。
Future<_ProcessProbe> _runProcess(
  String executable,
  List<String> arguments, {
  required Duration timeout,
}) async {
  try {
    final result = await Process.run(
      executable,
      arguments,
      environment: {
        ...Platform.environment,
        'DART_SUPPRESS_ANALYTICS': 'true',
        'FLUTTER_SUPPRESS_ANALYTICS': 'true',
      },
    ).timeout(timeout);
    return _ProcessProbe(
      exitCode: result.exitCode,
      stdout: _redactText('${result.stdout}'),
      stderr: _redactText('${result.stderr}'),
    );
  } on TimeoutException {
    return const _ProcessProbe(exitCode: 124, stderr: 'timeout');
  } on Object catch (error) {
    return _ProcessProbe(exitCode: 1, stderr: _redactText('$error'));
  }
}

// 安全读取嵌套 Map。
Map<String, Object?> _jsonMapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

// 安全读取字符串列表。
List<String> _jsonStringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => _redactText(item?.toString() ?? ''))
      .where((item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

// 合并自动准备与前置检查阻断项，保持顺序并去重。
List<String> _combinedBlockers(
  Map<String, Object?> preparation,
  Map<String, Object?> preflight,
) {
  final seen = <String>{};
  return <String>[
    ..._jsonStringList(preparation['blockers']),
    ..._jsonStringList(preflight['blockers']),
  ].where(seen.add).toList(growable: false);
}

// 生成文件名安全时间戳。
String _safeTimestamp(DateTime value) {
  return value.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
}

// 脱敏本机路径、长设备号和 UUID。
String _redactText(String value) {
  return value
      .replaceAll(RegExp(r'/Users/[^/\s]+'), '<home>')
      .replaceAll(RegExp(r'/private/tmp/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/tmp/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/var/folders/[^\s`)]+'), '<tmp>')
      .replaceAll(RegExp(r'/private/var/folders/[^\s`)]+'), '<tmp>')
      .replaceAll(
        RegExp(
          r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',
        ),
        '<device-id>',
      )
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{24,}\b'), '<device-id>');
}

// 命令行参数。
final class _ArchiveOptions {
  const _ArchiveOptions({
    required this.outDir,
    required this.archiveDir,
    required this.timeout,
    required this.requireComplete,
    required this.requireScreenshot,
    required this.requirePlatformRuns,
    required this.help,
  });

  final Directory outDir;
  final Directory archiveDir;
  final Duration timeout;
  final bool requireComplete;
  final bool requireScreenshot;
  final bool requirePlatformRuns;
  final bool help;

  // 解析命令行参数。
  static _ArchiveOptions parse(List<String> args) {
    var outDir = Directory('recordings/v4-smoke');
    Directory? archiveDir;
    var timeoutSeconds = 4;
    var requireComplete = false;
    var requireScreenshot = false;
    var requirePlatformRuns = false;
    var help = false;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--help':
        case '-h':
          help = true;
        case '--out-dir':
          outDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--archive-dir':
          archiveDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--timeout':
          timeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--require-complete':
          requireComplete = true;
        case '--require-screenshot':
          requireScreenshot = true;
        case '--require-platform-runs':
          requirePlatformRuns = true;
        default:
          throw ArgumentError('未知参数：$arg');
      }
    }

    return _ArchiveOptions(
      outDir: outDir,
      archiveDir: archiveDir ?? Directory('${outDir.path}/archives'),
      timeout: Duration(seconds: timeoutSeconds),
      requireComplete: requireComplete,
      requireScreenshot: requireScreenshot,
      requirePlatformRuns: requirePlatformRuns,
      help: help,
    );
  }
}

// 命令行参数读取 helper。
String _nextValue(List<String> args, int index, String name) {
  if (index + 1 >= args.length) {
    throw ArgumentError('$name 缺少参数值。');
  }
  return args[index + 1];
}

// artifact 类型。
enum _ArtifactKind {
  readinessJson,
  readinessMarkdown,
  fullSmokeJson,
  fullSmokeMarkdown,
  screenshot,
  runMetadata,
  runEvents,
  runFinished,
  other;

  String get label {
    return switch (this) {
      _ArtifactKind.readinessJson => 'readiness-json',
      _ArtifactKind.readinessMarkdown => 'readiness-md',
      _ArtifactKind.fullSmokeJson => 'full-smoke-json',
      _ArtifactKind.fullSmokeMarkdown => 'full-smoke-md',
      _ArtifactKind.screenshot => 'screenshot',
      _ArtifactKind.runMetadata => 'run-metadata',
      _ArtifactKind.runEvents => 'run-events',
      _ArtifactKind.runFinished => 'run-finished',
      _ArtifactKind.other => 'other',
    };
  }
}

// 单个本地 artifact 条目。
final class _ArtifactEntry {
  const _ArtifactEntry({
    required this.kind,
    required this.relativePath,
    required this.bytes,
    required this.modifiedAt,
    this.platform,
    this.runName,
  });

  final _ArtifactKind kind;
  final String relativePath;
  final int bytes;
  final DateTime modifiedAt;
  final String? platform;
  final String? runName;

  // 转成脱敏 JSON。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'kind': kind.label,
      'relativePath': relativePath,
      'bytes': bytes,
      'modifiedAt': modifiedAt.toIso8601String(),
      'platform': platform,
      'runName': runName,
    };
  }
}

// readiness / full smoke JSON 摘要。
final class _ReportJsonSummary {
  const _ReportJsonSummary({
    required this.kind,
    required this.git,
    required this.timestamp,
    required this.rawComplete,
    required this.complete,
    required this.label,
    required this.blockers,
    required this.stepCount,
    required this.iosStepPassed,
    required this.androidStepPassed,
  });

  final String kind;
  final String? git;
  final String? timestamp;
  final bool rawComplete;
  final bool complete;
  final String label;
  final List<String> blockers;
  final int stepCount;
  final bool iosStepPassed;
  final bool androidStepPassed;

  // 从报告 JSON 解析统一摘要。
  factory _ReportJsonSummary.fromJson(Map<String, Object?> json) {
    final completion = _jsonMapAt(json, 'completion');
    final preparation = _jsonMapAt(json, 'preparation');
    final preflight = _jsonMapAt(json, 'preflight');
    final steps = json['steps'];
    final stepList = steps is Iterable ? steps.toList(growable: false) : [];
    final kind = _redactText(json['kind']?.toString() ?? 'unknown');
    final rawComplete = completion['complete'] == true;
    final iosStepPassed = _fullSmokeStepPassed(stepList, 'iOS smoke');
    final androidStepPassed = _fullSmokeStepPassed(stepList, 'Android smoke');
    final fullSmokeStepsPassed =
        kind != 'v4FullSmoke' || (iosStepPassed && androidStepPassed);
    return _ReportJsonSummary(
      kind: kind,
      git: _shortGitRevision(json['git']),
      timestamp: json['timestamp']?.toString(),
      rawComplete: rawComplete,
      complete: rawComplete && fullSmokeStepsPassed,
      label: _redactText(completion['label']?.toString() ?? '未知'),
      blockers: _combinedBlockers(preparation, preflight),
      stepCount: stepList.length,
      iosStepPassed: iosStepPassed,
      androidStepPassed: androidStepPassed,
    );
  }

  // 转成脱敏 JSON。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'kind': kind,
      'git': git,
      'timestamp': timestamp,
      'rawComplete': rawComplete,
      'complete': complete,
      'label': label,
      'blockers': blockers,
      'stepCount': stepCount,
      if (kind == 'v4FullSmoke') 'iosStepPassed': iosStepPassed,
      if (kind == 'v4FullSmoke') 'androidStepPassed': androidStepPassed,
    };
  }

  String get markdownLabel {
    final parts = <String>[
      complete
          ? '完整通过'
          : rawComplete && kind == 'v4FullSmoke'
          ? '平台步骤未完整'
          : label,
      if (git != null) '提交 $git',
      if (blockers.isNotEmpty) '阻断 ${blockers.join('/')}',
      if (stepCount > 0) '步骤 $stepCount',
      if (kind == 'v4FullSmoke' && iosStepPassed) 'iOS 通过',
      if (kind == 'v4FullSmoke' && !iosStepPassed) 'iOS 未通过',
      if (kind == 'v4FullSmoke' && androidStepPassed) 'Android 通过',
      if (kind == 'v4FullSmoke' && !androidStepPassed) 'Android 未通过',
      if (timestamp != null) '时间 $timestamp',
    ];
    return parts.join('，');
  }
}

// 判断 full smoke 报告中指定平台步骤是否通过。
bool _fullSmokeStepPassed(List<Object?> steps, String expectedName) {
  for (final step in steps) {
    if (step is! Map) continue;
    final stepMap = Map<String, Object?>.from(step);
    final name = _jsonMapAt(stepMap, 'step')['name']?.toString();
    final status = stepMap['status']?.toString();
    if (name == expectedName && status == '通过') return true;
  }
  return false;
}

// 最近一次平台 smoke run 摘要，只保存结构化状态，不包含截图内容。
final class _PlatformRunSummary {
  const _PlatformRunSummary({
    required this.platform,
    required this.runName,
    required this.git,
    required this.status,
    required this.actionsAllowed,
    required this.hasScreenshot,
    required this.screenshotFileCount,
    required this.workflowExecuted,
    required this.actionNames,
    required this.logsCollected,
  });

  final String platform;
  final String runName;
  final String? git;
  final String status;
  final bool? actionsAllowed;
  final bool hasScreenshot;
  final int screenshotFileCount;
  final bool workflowExecuted;
  final Set<String> actionNames;
  final bool logsCollected;

  bool get passed => status == 'success';

  bool get hasScreenshotFile => screenshotFileCount > 0;

  bool get tapExecuted => actionNames.contains('tap');

  bool get swipeExecuted => actionNames.contains('swipe');

  bool get inputExecuted => actionNames.contains('input');

  bool get fullPassed =>
      passed &&
      actionsAllowed == true &&
      hasScreenshot &&
      hasScreenshotFile &&
      workflowExecuted &&
      tapExecuted &&
      swipeExecuted &&
      inputExecuted;

  bool matchesGit(String currentGit) {
    return currentGit != 'unknown' && git != null && git == currentGit;
  }

  String get markdownLabel {
    final actions = <String>[
      if (tapExecuted) 'tap',
      if (swipeExecuted) 'swipe',
      if (inputExecuted) 'input',
    ];
    final parts = <String>[
      fullPassed
          ? '完整通过'
          : passed
          ? '通过但未完整'
          : status == 'failed'
          ? '失败'
          : '运行中',
      if (git != null) '提交 $git',
      actionsAllowed == true ? '允许动作' : '动作未授权',
      actions.isEmpty ? '未执行动作' : '动作 ${actions.join('/')}',
      workflowExecuted ? '含流程' : '无流程',
      hasScreenshot
          ? hasScreenshotFile
                ? '有截图'
                : '截图缺文件'
          : '无截图',
      logsCollected ? '有日志' : '无日志',
    ];
    return parts.join('，');
  }

  // 转成脱敏 JSON 摘要。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'platform': platform,
      'runName': runName,
      'git': git,
      'status': status,
      'actionsAllowed': actionsAllowed,
      'hasScreenshot': hasScreenshot,
      'screenshotFileCount': screenshotFileCount,
      'workflowExecuted': workflowExecuted,
      'actions': actionNames.toList()..sort(),
      'logsCollected': logsCollected,
      'fullPassed': fullPassed,
      'summary': markdownLabel,
    };
  }
}

// archive 汇总。
final class _ArchiveSummary {
  const _ArchiveSummary({
    required this.totalFiles,
    required this.readinessReports,
    required this.fullSmokeReports,
    required this.screenshots,
    required this.iosRuns,
    required this.androidRuns,
    required this.totalBytes,
    required this.latestReadiness,
    required this.latestFullSmoke,
    required this.latestIosSmoke,
    required this.latestAndroidSmoke,
  });

  final int totalFiles;
  final int readinessReports;
  final int fullSmokeReports;
  final int screenshots;
  final int iosRuns;
  final int androidRuns;
  final int totalBytes;
  final _ReportJsonSummary? latestReadiness;
  final _ReportJsonSummary? latestFullSmoke;
  final _PlatformRunSummary? latestIosSmoke;
  final _PlatformRunSummary? latestAndroidSmoke;

  bool get latestFullSmokeComplete => latestFullSmoke?.complete ?? false;

  // 完整 full smoke 必须和当前 archive 提交一致，避免误用旧留档。
  bool latestFullSmokeMatchesGit(String git) {
    final smokeGit = latestFullSmoke?.git;
    return git != 'unknown' && smokeGit != null && smokeGit == git;
  }

  bool latestIosSmokeFullMatchesGit(String git) {
    final latest = latestIosSmoke;
    return latest != null && latest.fullPassed && latest.matchesGit(git);
  }

  bool latestAndroidSmokeFullMatchesGit(String git) {
    final latest = latestAndroidSmoke;
    return latest != null && latest.fullPassed && latest.matchesGit(git);
  }

  // 从 artifact 列表生成汇总。
  factory _ArchiveSummary.fromArtifacts({
    required List<_ArtifactEntry> artifacts,
    required _ReportJsonSummary? latestReadiness,
    required _ReportJsonSummary? latestFullSmoke,
    required _PlatformRunSummary? latestIosSmoke,
    required _PlatformRunSummary? latestAndroidSmoke,
  }) {
    final iosRuns = artifacts
        .where((entry) => entry.platform == 'ios' && entry.runName != null)
        .map((entry) => entry.runName)
        .toSet()
        .length;
    final androidRuns = artifacts
        .where((entry) => entry.platform == 'android' && entry.runName != null)
        .map((entry) => entry.runName)
        .toSet()
        .length;
    return _ArchiveSummary(
      totalFiles: artifacts.length,
      readinessReports: artifacts
          .where((entry) => entry.kind == _ArtifactKind.readinessJson)
          .length,
      fullSmokeReports: artifacts
          .where((entry) => entry.kind == _ArtifactKind.fullSmokeJson)
          .length,
      screenshots: artifacts
          .where((entry) => entry.kind == _ArtifactKind.screenshot)
          .length,
      iosRuns: iosRuns,
      androidRuns: androidRuns,
      totalBytes: artifacts.fold<int>(0, (sum, entry) => sum + entry.bytes),
      latestReadiness: latestReadiness,
      latestFullSmoke: latestFullSmoke,
      latestIosSmoke: latestIosSmoke,
      latestAndroidSmoke: latestAndroidSmoke,
    );
  }

  // 转成脱敏 JSON。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'totalFiles': totalFiles,
      'readinessReports': readinessReports,
      'fullSmokeReports': fullSmokeReports,
      'screenshots': screenshots,
      'iosRuns': iosRuns,
      'androidRuns': androidRuns,
      'totalBytes': totalBytes,
      'latestReadiness': latestReadiness?.toJsonObject(),
      'latestFullSmoke': latestFullSmoke?.toJsonObject(),
      'latestIosSmoke': latestIosSmoke?.toJsonObject(),
      'latestAndroidSmoke': latestAndroidSmoke?.toJsonObject(),
    };
  }
}

// archive 报告。
final class _SmokeArchiveReport {
  const _SmokeArchiveReport({
    required this.timestamp,
    required this.git,
    required this.sourceDir,
    required this.summary,
    required this.artifacts,
  });

  final DateTime timestamp;
  final String git;
  final String sourceDir;
  final _ArchiveSummary summary;
  final List<_ArtifactEntry> artifacts;

  // 转成机器可读 JSON 字符串。
  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJsonObject())}\n';
  }

  // 转成脱敏 JSON。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'v4SmokeArchive',
      'timestamp': timestamp.toIso8601String(),
      'git': git,
      'sourceDir': sourceDir,
      'summary': summary.toJsonObject(),
      'warnings': _warnings(),
      'artifacts': artifacts.map((entry) => entry.toJsonObject()).toList(),
    };
  }

  // 转成可读 Markdown。
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# V4 Smoke Archive')
      ..writeln()
      ..writeln('- 时间：${timestamp.toIso8601String()}')
      ..writeln('- 提交：$git')
      ..writeln('- 来源：`$sourceDir`')
      ..writeln()
      ..writeln('## 汇总')
      ..writeln()
      ..writeln('| 项目 | 数量 |')
      ..writeln('|---|---:|')
      ..writeln('| 文件 | ${summary.totalFiles} |')
      ..writeln('| Readiness JSON | ${summary.readinessReports} |')
      ..writeln('| Full smoke JSON | ${summary.fullSmokeReports} |')
      ..writeln('| 截图 | ${summary.screenshots} |')
      ..writeln('| iOS 运行 | ${summary.iosRuns} |')
      ..writeln('| Android 运行 | ${summary.androidRuns} |')
      ..writeln('| 总大小 | ${summary.totalBytes} bytes |')
      ..writeln()
      ..writeln('## 最近报告')
      ..writeln()
      ..writeln(
        '- Readiness：${summary.latestReadiness?.markdownLabel ?? '无记录'}',
      )
      ..writeln(
        '- Full smoke：${summary.latestFullSmoke?.markdownLabel ?? '无记录'}',
      )
      ..writeln('- iOS smoke：${summary.latestIosSmoke?.markdownLabel ?? '无记录'}')
      ..writeln(
        '- Android smoke：${summary.latestAndroidSmoke?.markdownLabel ?? '无记录'}',
      )
      ..writeln()
      ..writeln('## 截图索引')
      ..writeln();

    final screenshots = artifacts
        .where((entry) => entry.kind == _ArtifactKind.screenshot)
        .toList(growable: false);
    if (screenshots.isEmpty) {
      buffer.writeln('- 无截图。');
    } else {
      for (final entry in screenshots.take(20)) {
        buffer.writeln('- `${entry.relativePath}` (${entry.bytes} bytes)');
      }
      if (screenshots.length > 20) {
        buffer.writeln('- 其余 ${screenshots.length - 20} 张见 JSON。');
      }
    }

    buffer
      ..writeln()
      ..writeln('## 提醒')
      ..writeln();
    final warnings = _warnings();
    if (warnings.isEmpty) {
      buffer.writeln('- 当前 archive 清单无结构性提醒。');
    } else {
      for (final warning in warnings) {
        buffer.writeln('- $warning');
      }
    }
    return buffer.toString();
  }

  // 生成面向最终验收的缺口提醒。
  List<String> _warnings() {
    return <String>[
      if (summary.readinessReports == 0)
        '缺少 readiness JSON。请先运行 `npm run v4:smoke-readiness`。',
      if (summary.fullSmokeReports == 0)
        '缺少 full smoke JSON。请运行 `npm run v4:smoke:full`。',
      if (summary.screenshots == 0) '缺少截图留档。请保留 Mac App 或设备 smoke 截图。',
      if (summary.iosRuns == 0) '缺少 iOS 平台 smoke run。',
      if (summary.androidRuns == 0) '缺少 Android 平台 smoke run。',
      if (summary.latestIosSmoke case final latest?
          when latest.hasScreenshot && !latest.hasScreenshotFile)
        '最近 iOS 平台 smoke run 有截图事件但缺少同 run 截图文件。',
      if (summary.latestAndroidSmoke case final latest?
          when latest.hasScreenshot && !latest.hasScreenshotFile)
        '最近 Android 平台 smoke run 有截图事件但缺少同 run 截图文件。',
      if (summary.iosRuns > 0 && !summary.latestIosSmokeFullMatchesGit(git))
        '最近 iOS 平台 smoke run 尚未在当前提交完整通过。',
      if (summary.androidRuns > 0 &&
          !summary.latestAndroidSmokeFullMatchesGit(git))
        '最近 Android 平台 smoke run 尚未在当前提交完整通过。',
      if (!summary.latestFullSmokeComplete) '最近 full smoke 尚未完整通过。',
      if (summary.latestFullSmokeComplete && !_latestFullSmokeMatchesGit())
        '最近 full smoke 不属于当前提交。请重新运行 `npm run v4:smoke:full`。',
    ];
  }

  // 完整 full smoke 必须和当前 archive 提交一致，避免误用旧留档。
  bool _latestFullSmokeMatchesGit() {
    return summary.latestFullSmokeMatchesGit(git);
  }
}

// 进程探测结果。
final class _ProcessProbe {
  const _ProcessProbe({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

const _usage = '''
V4 smoke archive

用法：
  fvm dart run tool/v4_smoke_archive.dart [选项]

选项：
  --out-dir <path>          smoke 结果目录，默认 recordings/v4-smoke
  --archive-dir <path>      archive 输出目录，默认 <out-dir>/archives
  --timeout <seconds>       git 探测超时，默认 4
  --require-complete        最近 full smoke 未完整通过或不属于当前提交时返回非 0
  --require-screenshot      未发现截图时返回非 0
  --require-platform-runs   未发现 iOS 或 Android 平台 run 时返回非 0
  --help                    查看帮助
''';
