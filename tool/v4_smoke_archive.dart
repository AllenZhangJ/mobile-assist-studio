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

  final failures = _finalGateFailures(options, archive.summary);
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
  _ArchiveSummary summary,
) {
  return <String>[
    if (options.requireScreenshot && summary.screenshots == 0) '未发现截图留档。',
    if (options.requirePlatformRuns && summary.iosRuns == 0)
      '未发现 iOS 平台 smoke run。',
    if (options.requirePlatformRuns && summary.androidRuns == 0)
      '未发现 Android 平台 smoke run。',
    if (options.requireComplete && !summary.latestFullSmokeComplete)
      '最近 full smoke 尚未完整通过。',
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
  final summary = _ArchiveSummary.fromArtifacts(
    artifacts: artifacts,
    latestReadiness: latestReadiness,
    latestFullSmoke: latestFullSmoke,
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
  final file = File('${outDir.path}/${candidates.first.relativePath}');
  if (!await file.exists()) return null;
  try {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) return null;
    return _ReportJsonSummary.fromJson(Map<String, Object?>.from(decoded));
  } on Object {
    return null;
  }
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
    required this.timestamp,
    required this.complete,
    required this.label,
    required this.blockers,
    required this.stepCount,
  });

  final String kind;
  final String? timestamp;
  final bool complete;
  final String label;
  final List<String> blockers;
  final int stepCount;

  // 从报告 JSON 解析统一摘要。
  factory _ReportJsonSummary.fromJson(Map<String, Object?> json) {
    final completion = _jsonMapAt(json, 'completion');
    final preflight = _jsonMapAt(json, 'preflight');
    final steps = json['steps'];
    return _ReportJsonSummary(
      kind: _redactText(json['kind']?.toString() ?? 'unknown'),
      timestamp: json['timestamp']?.toString(),
      complete: completion['complete'] == true,
      label: _redactText(completion['label']?.toString() ?? '未知'),
      blockers: _jsonStringList(preflight['blockers']),
      stepCount: steps is Iterable ? steps.length : 0,
    );
  }

  // 转成脱敏 JSON。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'kind': kind,
      'timestamp': timestamp,
      'complete': complete,
      'label': label,
      'blockers': blockers,
      'stepCount': stepCount,
    };
  }

  String get markdownLabel {
    final parts = <String>[
      complete ? '完整通过' : label,
      if (blockers.isNotEmpty) '阻断 ${blockers.join('/')}',
      if (stepCount > 0) '步骤 $stepCount',
      if (timestamp != null) '时间 $timestamp',
    ];
    return parts.join('，');
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

  bool get latestFullSmokeComplete => latestFullSmoke?.complete ?? false;

  // 从 artifact 列表生成汇总。
  factory _ArchiveSummary.fromArtifacts({
    required List<_ArtifactEntry> artifacts,
    required _ReportJsonSummary? latestReadiness,
    required _ReportJsonSummary? latestFullSmoke,
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
      if (!summary.latestFullSmokeComplete) '最近 full smoke 尚未完整通过。',
    ];
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
  --require-complete        最近 full smoke 未完整通过时返回非 0
  --require-screenshot      未发现截图时返回非 0
  --require-platform-runs   未发现 iOS 或 Android 平台 run 时返回非 0
  --help                    查看帮助
''';
