import 'dart:async';
import 'dart:convert';
import 'dart:io';

// V4 smoke artifact contract 使用临时 fixture 验证 readiness / full smoke 留档结构。
// 它不启动 Appium、不请求 sudo、不创建手机会话，也不执行任何设备动作。
Future<void> main() async {
  final tempDir = await Directory.systemTemp.createTemp(
    'ias-v4-smoke-contract-',
  );
  try {
    await _seedFullSmokeFixture(tempDir);
    final result = await _runReadiness(tempDir);
    if (result.exitCode != 0) {
      _fail('readiness 合同生成失败：${_shortText(result.stderr)}');
    }

    final artifacts = await _loadGeneratedArtifacts(tempDir);
    _assertReadinessJson(artifacts.json);
    _assertReadinessMarkdown(artifacts.markdown);
    _assertNoSensitiveText(artifacts.allText);
    stdout.writeln('V4 smoke artifact contract passed');
  } finally {
    await tempDir.delete(recursive: true);
  }
}

// 写入最小 full smoke fixture，用于验证 readiness 能索引最近编排报告。
Future<void> _seedFullSmokeFixture(Directory outDir) async {
  await outDir.create(recursive: true);
  final timestamp = DateTime.utc(2026);
  final base = '${outDir.path}/FULL_SMOKE_2026-01-01T00-00-00-000000Z';
  final payload = <String, Object?>{
    'schemaVersion': 1,
    'kind': 'v4FullSmoke',
    'timestamp': timestamp.toIso8601String(),
    'completion': <String, Object?>{
      'complete': false,
      'label': '前置检查阻断',
      'failedSteps': <String>[],
    },
    'preflight': <String, Object?>{
      'skipped': false,
      'status': '有阻断',
      'hasBlockers': true,
      'blockers': <String>['Appium', 'Android 手机'],
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'name': 'Appium',
          'ok': false,
          'detail': '不可达',
          'nextStep': '先连接设备。',
        },
        <String, Object?>{
          'name': 'Android 手机',
          'ok': false,
          'detail': '未就绪',
          'nextStep': '连接一台已授权手机。',
        },
      ],
    },
    'steps': <Object?>[],
  };
  const encoder = JsonEncoder.withIndent('  ');
  await File('$base.json').writeAsString('${encoder.convert(payload)}\n');
  await File('$base.md').writeAsString('# V4 Full Smoke\n\n- 前置检查：有阻断\n');
}

// 调用现有 readiness 工具端到端生成报告，保持合同覆盖真实 CLI 输出。
Future<_ProcessResult> _runReadiness(Directory outDir) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    <String>[
      'tool/v4_smoke_readiness.dart',
      '--out-dir',
      outDir.path,
      '--timeout',
      '1',
    ],
    environment: <String, String>{
      ...Platform.environment,
      'DART_SUPPRESS_ANALYTICS': 'true',
      'FLUTTER_SUPPRESS_ANALYTICS': 'true',
    },
  );
  final stdoutBuffer = StringBuffer();
  final stderrBuffer = StringBuffer();
  final stdoutDone = process.stdout
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(stdoutBuffer.write)
      .asFuture<void>();
  final stderrDone = process.stderr
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(stderrBuffer.write)
      .asFuture<void>();

  var exitCode = 0;
  try {
    exitCode = await process.exitCode.timeout(const Duration(seconds: 20));
  } on TimeoutException {
    process.kill(ProcessSignal.sigterm);
    exitCode = 124;
  }
  await _settleOutput(stdoutDone, stderrDone);
  return _ProcessResult(
    exitCode: exitCode,
    stdout: stdoutBuffer.toString(),
    stderr: stderrBuffer.toString(),
  );
}

// 等待子进程输出收尾，避免合同偶发丢失尾部错误。
Future<void> _settleOutput(
  Future<void> stdoutDone,
  Future<void> stderrDone,
) async {
  try {
    await Future.wait(<Future<void>>[
      stdoutDone,
      stderrDone,
    ]).timeout(const Duration(seconds: 2));
  } on Object {
    // 输出收尾失败时，合同仍以 exit code 和已收集文本为准。
  }
}

// 读取 readiness 生成的最新 JSON 和 Markdown。
Future<_ReadinessArtifacts> _loadGeneratedArtifacts(Directory outDir) async {
  final jsonFiles = await _matchingFiles(
    outDir,
    RegExp(r'^SMOKE_READINESS_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    outDir,
    RegExp(r'^SMOKE_READINESS_.*\.md$'),
  );
  _expect(
    jsonFiles.length == 1,
    'readiness JSON 数量应为 1，实际 ${jsonFiles.length}',
  );
  _expect(
    markdownFiles.length == 1,
    'readiness Markdown 数量应为 1，实际 ${markdownFiles.length}',
  );

  final jsonText = await jsonFiles.single.readAsString();
  final markdown = await markdownFiles.single.readAsString();
  final decoded = jsonDecode(jsonText);
  _expect(decoded is Map, 'readiness JSON 必须是对象。');
  return _ReadinessArtifacts(
    json: Map<String, Object?>.from(decoded as Map),
    markdown: markdown,
    allText: '$jsonText\n$markdown',
  );
}

// 列出目录下文件名匹配的文件，并按文件名排序。
Future<List<File>> _matchingFiles(Directory dir, RegExp pattern) async {
  final files = <File>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (pattern.hasMatch(name)) files.add(entity);
  }
  files.sort(
    (left, right) =>
        left.uri.pathSegments.last.compareTo(right.uri.pathSegments.last),
  );
  return files;
}

// 断言 readiness JSON 的稳定合同字段，覆盖批次、状态、证据和下一步。
void _assertReadinessJson(Map<String, Object?> json) {
  _expect(json['schemaVersion'] == 1, 'schemaVersion 必须为 1。');
  _expect(json['kind'] == 'v4SmokeReadiness', 'kind 必须为 v4SmokeReadiness。');

  final completion = _mapAt(json, 'completion');
  _expect(
    completion['complete'] == false,
    'fixture 下 completion.complete 必须为 false。',
  );
  _expect(
    completion['label'] is String && '${completion['label']}'.isNotEmpty,
    'completion.label 必须存在。',
  );

  final localState = _mapAt(json, 'localState');
  for (final key in <String>[
    'appium',
    'iosTunnel',
    'iosDevice',
    'androidDevice',
  ]) {
    _expect(localState[key] is Map, 'localState.$key 必须存在。');
  }

  final batches = _listAt(json, 'batches');
  _expect(batches.length == 9, 'batches 必须包含 Batch 0-8。');
  _expect(
    batches.any((item) => _mapFrom(item)['name'] == 'Batch 0 真源治理'),
    'batches 必须包含 Batch 0。',
  );
  _expect(
    batches.any((item) => _mapFrom(item)['name'] == 'Batch 8 AI / MCP Core'),
    'batches 必须包含 Batch 8。',
  );

  final artifacts = _mapAt(json, 'artifacts');
  _expect(artifacts['fullSmokeReports'] == 1, 'fullSmokeReports 必须索引 fixture。');
  final latestFullSmoke = _mapAt(artifacts, 'latestFullSmoke');
  _expect(
    latestFullSmoke['label'] == '前置检查阻断',
    'latestFullSmoke.label 必须保留阻断状态。',
  );
  _expect(
    latestFullSmoke['preflightStatus'] == '有阻断',
    'latestFullSmoke.preflightStatus 必须保留前置状态。',
  );
  _expect(latestFullSmoke['stepCount'] == 0, '前置阻断时 stepCount 必须为 0。');
  final blockers = _stringList(latestFullSmoke['blockers']);
  _expect(blockers.contains('Appium'), 'latestFullSmoke.blockers 必须包含 Appium。');
  _expect(
    blockers.contains('Android 手机'),
    'latestFullSmoke.blockers 必须包含 Android 手机。',
  );

  final nextSteps = _listAt(json, 'nextSteps');
  _expect(nextSteps.isNotEmpty, 'nextSteps 必须给出下一步。');
}

// 断言 Markdown 留档包含人类复盘需要的 full smoke 索引区。
void _assertReadinessMarkdown(String markdown) {
  for (final text in <String>[
    '# V4 Smoke Readiness',
    '最近 full smoke',
    'Full smoke 报告',
    '## 批次验收索引',
    '## 下一步',
  ]) {
    _expect(markdown.contains(text), 'Markdown 必须包含：$text');
  }
}

// 扫描生成文本，防止合同 fixture 或 readiness 输出泄露真实本机信息。
void _assertNoSensitiveText(String text) {
  final patterns = <RegExp>[
    RegExp(r'/Users/[^/\s]+'),
    RegExp(r'/private/tmp/[^\s`)]+'),
    RegExp(r'/tmp/[^\s`)]+'),
    RegExp(r'/var/folders/[^\s`)]+'),
    RegExp(r'/private/var/folders/[^\s`)]+'),
    RegExp(
      r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',
    ),
    RegExp(r'\b[0-9A-Fa-f]{24,}\b'),
  ];
  for (final pattern in patterns) {
    _expect(!pattern.hasMatch(text), '生成留档包含未脱敏内容：$pattern');
  }
}

// 从 Map 中读取嵌套对象，缺失时让合同失败。
Map<String, Object?> _mapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  _expect(value is Map, '$key 必须是对象。');
  return Map<String, Object?>.from(value as Map);
}

// 从 Map 中读取列表，缺失时让合同失败。
List<Object?> _listAt(Map<String, Object?> json, String key) {
  final value = json[key];
  _expect(value is List, '$key 必须是列表。');
  return List<Object?>.from(value as List);
}

// 将动态值转为对象；类型错误时返回空对象供断言失败定位。
Map<String, Object?> _mapFrom(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

// 将动态列表转为字符串列表，便于检查 blocker 等稳定字段。
List<String> _stringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  return value.map((item) => item?.toString() ?? '').toList(growable: false);
}

// 合同断言 helper，失败时用中文说明直接退出。
void _expect(bool condition, String message) {
  if (condition) return;
  _fail(message);
}

// 裁剪子进程错误，避免终端被长日志淹没。
String _shortText(String value, {int limit = 600}) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= limit) return compact;
  return '${compact.substring(0, limit)}...';
}

// 统一失败出口。
Never _fail(String message) {
  stderr.writeln('V4 smoke artifact contract failed: $message');
  exit(1);
}

// 子进程结果摘要。
final class _ProcessResult {
  const _ProcessResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

// readiness 生成物集合。
final class _ReadinessArtifacts {
  const _ReadinessArtifacts({
    required this.json,
    required this.markdown,
    required this.allText,
  });

  final Map<String, Object?> json;
  final String markdown;
  final String allText;
}
