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

    await _seedArchiveFixture(tempDir);
    final archiveResult = await _runArchive(tempDir);
    if (archiveResult.exitCode != 0) {
      _fail('archive 合同生成失败：${_shortText(archiveResult.stderr)}');
    }
    final archive = await _loadArchiveArtifacts(tempDir);
    _assertArchiveJson(archive.json);
    _assertArchiveMarkdown(archive.markdown);
    _assertNoSensitiveText(archive.allText);

    final finalArchive = await _runArchiveFinal(tempDir);
    _expect(
      finalArchive.exitCode == 2,
      'archive final 在 fixture 未完整时必须返回 2，实际 ${finalArchive.exitCode}。',
    );
    _expect(
      finalArchive.stderr.contains('iOS 平台') &&
          finalArchive.stderr.contains('Android 平台') &&
          finalArchive.stderr.contains('full smoke'),
      'archive final 必须一次性提示平台 run 和 full smoke 缺口。',
    );

    final acceptance = await _runFinalAcceptance(tempDir);
    _expect(
      acceptance.exitCode == 0,
      'acceptance audit 在 fixture 下应成功留档，实际 ${acceptance.exitCode}。',
    );
    final acceptanceArtifacts = await _loadAcceptanceArtifacts(tempDir);
    _assertAcceptanceJson(acceptanceArtifacts.json);
    _assertAcceptanceMarkdown(acceptanceArtifacts.markdown);
    _assertNoSensitiveText(acceptanceArtifacts.allText);
    await _assertPackageSmokeScripts();

    final finalAcceptance = await _runFinalAcceptance(
      tempDir,
      requireComplete: true,
    );
    _expect(
      finalAcceptance.exitCode == 2,
      'acceptance final 在 fixture 未完整时必须返回 2，实际 ${finalAcceptance.exitCode}。',
    );
    _expect(
      finalAcceptance.stderr.contains('最终验收尚未通过') &&
          finalAcceptance.stderr.contains('完成审计') &&
          finalAcceptance.stderr.contains('归档终验'),
      'acceptance final 必须提示最终验收缺口。',
    );
    stdout.writeln('V4 smoke artifact contract passed');
  } finally {
    await tempDir.delete(recursive: true);
  }
}

// 断言 npm 单平台 full smoke 入口复用 full smoke 编排器，保留自动准备能力。
Future<void> _assertPackageSmokeScripts() async {
  final packageFile = File('package.json');
  _expect(await packageFile.exists(), '必须存在 package.json。');
  final decoded = jsonDecode(await packageFile.readAsString());
  _expect(decoded is Map, 'package.json 必须是 JSON 对象。');
  final packageJson = Map<String, Object?>.from(decoded as Map);
  final scripts = _mapAt(packageJson, 'scripts');
  final devDependencies = _mapAt(packageJson, 'devDependencies');
  _expect(
    devDependencies['appium-xcuitest-driver'] is String,
    'package.json 必须固定 Appium XCUITest driver。',
  );
  _expect(
    devDependencies['appium-uiautomator2-driver'] is String,
    'package.json 必须固定 Appium UiAutomator2 driver。',
  );
  await _assertFullSmokeDriverProbe();
  _assertFullSmokeScript(
    scripts,
    name: 'v4:ios-smoke:full',
    requiredSkipFlag: '--skip-android',
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:ios-smoke:full:password-prompt',
    requiredSkipFlag: '--skip-android',
    requiresPasswordPrompt: true,
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:ios-smoke:full:password-stdin',
    requiredSkipFlag: '--skip-android',
    requiresPasswordStdin: true,
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:android-smoke:full',
    requiredSkipFlag: '--skip-ios',
  );
  _assertFullSmokeScript(
    scripts,
    name: 'v4:smoke:full:password-prompt',
    requiredSkipFlag: '',
    requiresPasswordPrompt: true,
  );
}

// 断言单条 full smoke 脚本包含自动准备、动作确认和单平台跳过参数。
void _assertFullSmokeScript(
  Map<String, Object?> scripts, {
  required String name,
  required String requiredSkipFlag,
  bool requiresPasswordStdin = false,
  bool requiresPasswordPrompt = false,
}) {
  final command = scripts[name]?.toString() ?? '';
  _expect(
    command.contains('tool/v4_full_smoke.dart'),
    '$name 必须使用 full smoke 编排器。',
  );
  _expect(command.contains('--confirm-actions'), '$name 必须显式确认真实动作。');
  _expect(command.contains('--auto-prepare'), '$name 必须自动准备本机环境。');
  if (requiredSkipFlag.isNotEmpty) {
    _expect(
      command.contains(requiredSkipFlag),
      '$name 必须包含 $requiredSkipFlag。',
    );
  }
  if (requiresPasswordStdin) {
    _expect(
      command.contains('--admin-password-stdin'),
      '$name 必须通过 stdin 一次性读取本机密码。',
    );
  }
  if (requiresPasswordPrompt) {
    _expect(
      command.contains('--admin-password-prompt'),
      '$name 必须通过终端提示读取本机密码。',
    );
  }
}

// 断言平台 driver 探测同时解析 stdout / stderr，兼容 Appium CLI 的实际输出流。
Future<void> _assertFullSmokeDriverProbe() async {
  final sourceFile = File('tool/v4_full_smoke.dart');
  _expect(await sourceFile.exists(), '必须存在 full smoke 编排器。');
  final source = await sourceFile.readAsString();
  _expect(
    source.contains(r'${result.stdout}\n${result.stderr}'),
    '平台 driver 探测必须同时解析 stdout 和 stderr。',
  );
  _expect(
    source.contains('_readAdminPasswordFromPrompt') &&
        source.contains(
          '--admin-password-prompt 和 --admin-password-stdin 不能同时使用',
        ),
    'full smoke 必须支持隐藏输入密码，并阻止 prompt / stdin 同时启用。',
  );
  _expect(
    source.contains('ANDROID_SMOKE_PREFLIGHT_') &&
        source.contains("'source': 'full-smoke'"),
    'full smoke 的 Android 前置阻断必须同步生成 Android preflight 留档。',
  );
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
    'preparation': <String, Object?>{
      'skipped': false,
      'status': '有阻断',
      'hasBlockers': true,
      'blockers': <String>['自动准备', 'iOS 隧道', 'Android 准备'],
      'items': <Map<String, Object?>>[
        <String, Object?>{
          'name': '自动准备',
          'ok': false,
          'detail': '缺少密码',
          'nextStep': '输入密码后重试。',
        },
        <String, Object?>{
          'name': 'iOS 隧道',
          'ok': false,
          'detail': '缺少密码',
          'nextStep': '通过终端提示一次性传入密码后重试。',
        },
        <String, Object?>{
          'name': 'Android 准备',
          'ok': false,
          'detail': '未授权',
          'nextStep': '允许 USB 调试后重试。',
        },
      ],
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
  final androidDir = Directory('${outDir.path}/android');
  await androidDir.create(recursive: true);
  final preflightPayload = <String, Object?>{
    'schemaVersion': 1,
    'kind': 'v4AndroidSmokePreflight',
    'timestamp': timestamp.toIso8601String(),
    'completion': <String, Object?>{
      'ready': false,
      'label': '有阻断',
      'blockers': <String>['驱动'],
    },
    'request': <String, Object?>{'allowActions': true, 'workflowBasic': true},
    'checks': <Map<String, Object?>>[
      <String, Object?>{
        'name': '驱动',
        'ok': false,
        'status': '阻断',
        'detail': '不可达',
        'nextStep': '先连接设备。',
      },
      <String, Object?>{
        'name': '安卓手机',
        'ok': true,
        'status': '通过',
        'detail': 'Pixel 9 ZY22...CDEF',
        'nextStep': '-',
        'ready': 1,
        'unauthorized': 0,
        'offline': 0,
      },
    ],
    'nextSteps': <String>['先连接设备。'],
  };
  await File(
    '${androidDir.path}/ANDROID_SMOKE_PREFLIGHT_2026-01-01T00-00-00-000000Z.json',
  ).writeAsString('${encoder.convert(preflightPayload)}\n');
}

// 写入 archive fixture，只放虚拟截图文件，不读取或生成真实隐私图片。
Future<void> _seedArchiveFixture(Directory outDir) async {
  await File(
    '${outDir.path}/studio-ui-fixture.png',
  ).writeAsBytes(<int>[0x89, 0x50, 0x4E, 0x47]);
}

// 调用现有 readiness 工具端到端生成报告，保持合同覆盖真实 CLI 输出。
Future<_ProcessResult> _runReadiness(Directory outDir) async {
  return _runDartTool(<String>[
    'tool/v4_smoke_readiness.dart',
    '--out-dir',
    outDir.path,
    '--timeout',
    '1',
  ]);
}

// 调用现有 archive 工具端到端生成本地索引。
Future<_ProcessResult> _runArchive(Directory outDir) async {
  return _runDartTool(<String>[
    'tool/v4_smoke_archive.dart',
    '--out-dir',
    outDir.path,
    '--archive-dir',
    '${outDir.path}/archives',
    '--timeout',
    '1',
  ]);
}

// 调用 archive final 严格门禁，验证未完整 fixture 不会误通过。
Future<_ProcessResult> _runArchiveFinal(Directory outDir) async {
  return _runDartTool(<String>[
    'tool/v4_smoke_archive.dart',
    '--out-dir',
    outDir.path,
    '--archive-dir',
    '${outDir.path}/archives-final',
    '--timeout',
    '1',
    '--require-complete',
    '--require-screenshot',
    '--require-platform-runs',
  ]);
}

// 调用最终验收工具，验证统一审计报告和严格门禁。
Future<_ProcessResult> _runFinalAcceptance(
  Directory outDir, {
  bool requireComplete = false,
}) async {
  return _runDartTool(<String>[
    'tool/v4_final_acceptance.dart',
    '--out-dir',
    outDir.path,
    '--archive-dir',
    '${outDir.path}/archives',
    '--report-dir',
    '${outDir.path}/acceptance',
    '--probe-timeout',
    '1',
    '--step-timeout',
    '20',
    if (requireComplete) '--require-complete',
  ]);
}

// 启动 Dart 工具并设置统一超时，合同不依赖真实设备。
Future<_ProcessResult> _runDartTool(List<String> arguments) async {
  final process = await Process.start(
    Platform.resolvedExecutable,
    arguments,
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

// 读取 archive 生成的最新 JSON 和 Markdown。
Future<_ArchiveArtifacts> _loadArchiveArtifacts(Directory outDir) async {
  final archiveDir = Directory('${outDir.path}/archives');
  final jsonFiles = await _matchingFiles(
    archiveDir,
    RegExp(r'^SMOKE_ARCHIVE_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    archiveDir,
    RegExp(r'^SMOKE_ARCHIVE_.*\.md$'),
  );
  _expect(jsonFiles.length == 1, 'archive JSON 数量应为 1，实际 ${jsonFiles.length}');
  _expect(
    markdownFiles.length == 1,
    'archive Markdown 数量应为 1，实际 ${markdownFiles.length}',
  );

  final jsonText = await jsonFiles.single.readAsString();
  final markdown = await markdownFiles.single.readAsString();
  final decoded = jsonDecode(jsonText);
  _expect(decoded is Map, 'archive JSON 必须是对象。');
  return _ArchiveArtifacts(
    json: Map<String, Object?>.from(decoded as Map),
    markdown: markdown,
    allText: '$jsonText\n$markdown',
  );
}

// 读取 final acceptance 生成的最新 JSON 和 Markdown。
Future<_AcceptanceArtifacts> _loadAcceptanceArtifacts(Directory outDir) async {
  final acceptanceDir = Directory('${outDir.path}/acceptance');
  final jsonFiles = await _matchingFiles(
    acceptanceDir,
    RegExp(r'^FINAL_ACCEPTANCE_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    acceptanceDir,
    RegExp(r'^FINAL_ACCEPTANCE_.*\.md$'),
  );
  _expect(
    jsonFiles.length == 1,
    'acceptance JSON 数量应为 1，实际 ${jsonFiles.length}',
  );
  _expect(
    markdownFiles.length == 1,
    'acceptance Markdown 数量应为 1，实际 ${markdownFiles.length}',
  );

  final jsonText = await jsonFiles.single.readAsString();
  final markdown = await markdownFiles.single.readAsString();
  final decoded = jsonDecode(jsonText);
  _expect(decoded is Map, 'acceptance JSON 必须是对象。');
  return _AcceptanceArtifacts(
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
  _expect(
    artifacts['androidPreflightReports'] == 1,
    'androidPreflightReports 必须索引 Android 前置诊断。',
  );
  final latestAndroidPreflight = _mapAt(artifacts, 'latestAndroidPreflight');
  _expect(
    latestAndroidPreflight['label'] == '有阻断',
    'latestAndroidPreflight.label 必须保留阻断状态。',
  );
  _expect(
    _stringList(latestAndroidPreflight['blockers']).contains('驱动'),
    'latestAndroidPreflight.blockers 必须包含驱动。',
  );
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
  _expect(blockers.contains('自动准备'), 'latestFullSmoke.blockers 必须包含自动准备。');
  _expect(blockers.contains('iOS 隧道'), 'latestFullSmoke.blockers 必须包含 iOS 隧道。');
  _expect(
    blockers.contains('Android 准备'),
    'latestFullSmoke.blockers 必须包含 Android 准备。',
  );
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
    'Android 前置诊断',
    'Full smoke 报告',
    '## 批次验收索引',
    '## 下一步',
  ]) {
    _expect(markdown.contains(text), 'Markdown 必须包含：$text');
  }
}

// 断言 archive JSON 的稳定合同字段，覆盖截图、报告和自排除。
void _assertArchiveJson(Map<String, Object?> json) {
  _expect(json['schemaVersion'] == 1, 'archive schemaVersion 必须为 1。');
  _expect(json['kind'] == 'v4SmokeArchive', 'archive kind 必须正确。');

  final summary = _mapAt(json, 'summary');
  _expect(summary['readinessReports'] == 1, 'archive 必须索引 readiness JSON。');
  _expect(summary['fullSmokeReports'] == 1, 'archive 必须索引 full smoke JSON。');
  _expect(summary['screenshots'] == 1, 'archive 必须索引截图。');
  _expect(summary['iosRuns'] == 0, 'fixture 下 iOS run 必须为 0。');
  _expect(summary['androidRuns'] == 0, 'fixture 下 Android run 必须为 0。');

  final latestFullSmoke = _mapAt(summary, 'latestFullSmoke');
  _expect(
    latestFullSmoke['label'] == '前置检查阻断',
    'archive latestFullSmoke.label 必须保留阻断状态。',
  );
  final blockers = _stringList(latestFullSmoke['blockers']);
  _expect(blockers.contains('自动准备'), 'archive blockers 必须包含自动准备。');
  _expect(blockers.contains('iOS 隧道'), 'archive blockers 必须包含 iOS 隧道。');
  _expect(blockers.contains('Android 准备'), 'archive blockers 必须包含 Android 准备。');
  _expect(blockers.contains('Appium'), 'archive blockers 必须包含 Appium。');

  final warnings = _stringList(json['warnings']);
  _expect(warnings.isNotEmpty, 'archive 必须保留当前缺口提醒。');
  _expect(
    warnings.any((warning) => warning.contains('iOS 平台')) &&
        warnings.any((warning) => warning.contains('Android 平台')),
    'archive 必须提示缺少双平台 run。',
  );

  final artifacts = _listAt(json, 'artifacts');
  _expect(artifacts.length >= 5, 'archive 必须索引 fixture 文件。');
  _expect(
    artifacts.every((item) {
      final path = _mapFrom(item)['relativePath']?.toString() ?? '';
      return !path.startsWith('archives/');
    }),
    'archive 不得把自身输出目录纳入索引。',
  );
}

// 断言 archive Markdown 包含最终人工复盘需要的区域。
void _assertArchiveMarkdown(String markdown) {
  for (final text in <String>[
    '# V4 Smoke Archive',
    '## 汇总',
    '## 最近报告',
    '## 截图索引',
    '## 提醒',
  ]) {
    _expect(markdown.contains(text), 'Archive Markdown 必须包含：$text');
  }
}

// 断言 final acceptance JSON 覆盖统一验收步骤和失败摘要。
void _assertAcceptanceJson(Map<String, Object?> json) {
  _expect(json['schemaVersion'] == 1, 'acceptance schemaVersion 必须为 1。');
  _expect(json['kind'] == 'v4FinalAcceptance', 'acceptance kind 必须正确。');

  final completion = _mapAt(json, 'completion');
  _expect(completion['auditOk'] == true, 'acceptance auditOk 必须为 true。');
  _expect(
    completion['complete'] == false,
    'fixture 下 acceptance complete 必须为 false。',
  );
  final failures = _stringList(completion['failures']);
  _expect(
    failures.any((failure) => failure.contains('完成审计')) &&
        failures.any((failure) => failure.contains('归档终验')),
    'acceptance 必须保留两个最终门禁失败摘要。',
  );
  final nextSteps = _stringList(json['nextSteps']);
  _expect(
    nextSteps.any((step) => step.contains('v4:ios-smoke:full')) &&
        nextSteps.any(
          (step) => step.contains('v4:ios-smoke:full:password-prompt'),
        ) &&
        nextSteps.any((step) => step.contains('v4:android-smoke:full')) &&
        nextSteps.any((step) => step.contains('v4:smoke:full')) &&
        nextSteps.any((step) => step.contains('v4:acceptance-final')),
    'acceptance nextSteps 必须给出 iOS 隧道、Android、full smoke 和终验命令。',
  );

  final evidence = _mapAt(json, 'evidence');
  final readiness = _mapAt(evidence, 'readiness');
  final localState = _mapAt(readiness, 'localState');
  _expect(
    localState['androidDevice'] is Map,
    'acceptance evidence 必须嵌入 Android 本机状态。',
  );
  final batches = _listAt(readiness, 'batches');
  _expect(batches.length == 9, 'acceptance evidence 必须嵌入 Batch 0-8。');
  _expect(
    batches.any((item) => _mapFrom(item)['name'] == 'Batch 0 真源治理') &&
        batches.any(
          (item) => _mapFrom(item)['name'] == 'Batch 8 AI / MCP Core',
        ),
    'acceptance evidence 必须嵌入首尾批次。',
  );
  final readinessArtifacts = _mapAt(readiness, 'artifacts');
  _expect(
    readinessArtifacts['androidPreflightReports'] == 1,
    'acceptance evidence 必须嵌入 Android 前置诊断数量。',
  );
  _expect(
    _mapAt(readinessArtifacts, 'latestAndroidPreflight')['label'] == '有阻断',
    'acceptance evidence 必须嵌入最近 Android 前置诊断。',
  );
  final archive = _mapAt(evidence, 'archive');
  final counts = _mapAt(archive, 'counts');
  _expect(counts['screenshots'] == 1, 'acceptance evidence 必须嵌入截图数量。');
  _expect(counts['androidRuns'] == 0, 'fixture 下 Android 运行数量必须为 0。');

  final steps = _listAt(json, 'steps');
  _expect(steps.length == 4, 'acceptance 必须包含 4 个固定步骤。');
}

// 断言 final acceptance Markdown 包含人工复盘区域。
void _assertAcceptanceMarkdown(String markdown) {
  for (final text in <String>[
    '# V4 Final Acceptance',
    '## 步骤',
    '## 结论',
    '## 现场摘要',
    '### 批次验收',
    'Batch 0 真源治理',
    'Batch 8 AI / MCP Core',
    'Android 手机',
    'Android smoke 前置诊断',
    '最近完整冒烟',
    '留档数量',
    '## 下一步',
    '完成审计',
    '归档终验',
    'v4:ios-smoke:full',
    'v4:ios-smoke:full:password-prompt',
    'v4:android-smoke:full',
    'v4:smoke:full',
    'v4:acceptance-final',
  ]) {
    _expect(markdown.contains(text), 'Acceptance Markdown 必须包含：$text');
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

// archive 生成物集合。
final class _ArchiveArtifacts {
  const _ArchiveArtifacts({
    required this.json,
    required this.markdown,
    required this.allText,
  });

  final Map<String, Object?> json;
  final String markdown;
  final String allText;
}

// final acceptance 生成物集合。
final class _AcceptanceArtifacts {
  const _AcceptanceArtifacts({
    required this.json,
    required this.markdown,
    required this.allText,
  });

  final Map<String, Object?> json;
  final String markdown;
  final String allText;
}
