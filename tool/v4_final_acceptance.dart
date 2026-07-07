import 'dart:async';
import 'dart:convert';
import 'dart:io';

// V4 final acceptance 串联 readiness、archive 和最终门禁，并生成本地审计报告。
// 它不执行真实 Tap / Swipe / Input，只复用现有只读验收工具做最终状态判定。
Future<void> main(List<String> args) async {
  final options = _AcceptanceOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  final timestamp = DateTime.now().toUtc();
  await options.reportDir.create(recursive: true);
  final results = <_AcceptanceStepResult>[];
  for (final step in _buildSteps(options)) {
    stdout.writeln('\n== ${step.name} ==');
    final result = await _runStep(step, options.stepTimeout);
    stdout.writeln('${step.name}：${result.statusLabel}');
    results.add(result);
  }

  final report = _AcceptanceReport(
    timestamp: timestamp,
    git: await _currentGitCommit(options.probeTimeout),
    requireComplete: options.requireComplete,
    outDir: _redactText(options.outDir.path),
    evidence: await _AcceptanceEvidenceSummary.load(
      outDir: options.outDir,
      archiveDir: options.archiveDir,
    ),
    results: results,
  );
  final base =
      '${options.reportDir.path}/FINAL_ACCEPTANCE_${_safeTimestamp(timestamp)}';
  final jsonFile = File('$base.json');
  final markdownFile = File('$base.md');
  await jsonFile.writeAsString(report.toJsonString(), flush: true);
  await markdownFile.writeAsString(report.toMarkdown(), flush: true);
  stdout
    ..writeln('\nFinal acceptance report: ${_redactText(markdownFile.path)}')
    ..writeln('Final acceptance json: ${_redactText(jsonFile.path)}');

  if (!report.auditOk) {
    stderr.writeln('V4 final acceptance audit failed: 基础审计工具未能成功生成。');
    exit(1);
  }
  if (options.requireComplete && !report.complete) {
    stderr.writeln('V4 final acceptance failed: 最终验收尚未通过。');
    for (final failure in report.finalFailures) {
      stderr.writeln('- $failure');
    }
    exit(2);
  }
}

// 生成固定顺序的最终验收步骤；后续步骤即使前一步失败也会继续留档。
List<_AcceptanceStep> _buildSteps(_AcceptanceOptions options) {
  return <_AcceptanceStep>[
    _AcceptanceStep(
      name: '生成 readiness',
      arguments: <String>[
        'tool/v4_smoke_readiness.dart',
        '--out-dir',
        options.outDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
      ],
      requiredForAudit: true,
    ),
    _AcceptanceStep(
      name: '生成 archive',
      arguments: <String>[
        'tool/v4_smoke_archive.dart',
        '--out-dir',
        options.outDir.path,
        '--archive-dir',
        options.archiveDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
      ],
      requiredForAudit: true,
    ),
    _AcceptanceStep(
      name: '完成审计',
      arguments: <String>[
        'tool/v4_smoke_readiness.dart',
        '--out-dir',
        options.outDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
        '--require-complete',
      ],
    ),
    _AcceptanceStep(
      name: '归档终验',
      arguments: <String>[
        'tool/v4_smoke_archive.dart',
        '--out-dir',
        options.outDir.path,
        '--archive-dir',
        options.archiveDir.path,
        '--timeout',
        '${options.probeTimeout.inSeconds}',
        '--require-complete',
        '--require-screenshot',
        '--require-platform-runs',
      ],
    ),
  ];
}

// 执行单个验收步骤并捕获脱敏输出。
Future<_AcceptanceStepResult> _runStep(
  _AcceptanceStep step,
  Duration timeout,
) async {
  final startedAt = DateTime.now().toUtc();
  try {
    final process = await Process.start(
      Platform.resolvedExecutable,
      step.arguments,
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
    var timedOut = false;
    try {
      exitCode = await process.exitCode.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      exitCode = 124;
      process.kill(ProcessSignal.sigterm);
      try {
        await process.exitCode.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        process.kill(ProcessSignal.sigkill);
      }
    }
    await _settleOutput(stdoutDone, stderrDone);
    return _AcceptanceStepResult(
      step: step,
      exitCode: exitCode,
      timedOut: timedOut,
      startedAt: startedAt,
      finishedAt: DateTime.now().toUtc(),
      stdoutText: _redactText(stdoutBuffer.toString()),
      stderrText: _redactText(stderrBuffer.toString()),
    );
  } on ProcessException catch (error) {
    return _AcceptanceStepResult(
      step: step,
      exitCode: 127,
      timedOut: false,
      startedAt: startedAt,
      finishedAt: DateTime.now().toUtc(),
      stdoutText: '',
      stderrText: _redactText(error.message),
    );
  }
}

// 等待子进程输出收尾，避免报告漏掉最后一行失败信息。
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
    // 输出收尾失败不覆盖主退出码，报告保留已收集内容。
  }
}

// 当前 git commit 只保留短 hash。
Future<String> _currentGitCommit(Duration timeout) async {
  try {
    final result = await Process.run('git', const <String>[
      'rev-parse',
      '--short',
      'HEAD',
    ]).timeout(timeout);
    if (result.exitCode != 0) return 'unknown';
    final value = _redactText('${result.stdout}').trim();
    return value.isEmpty ? 'unknown' : value;
  } on Object {
    return 'unknown';
  }
}

// 裁剪长输出，保留首尾上下文。
String _shortBlock(String value, {int limit = 1800}) {
  final trimmed = value.trim();
  if (trimmed.length <= limit) return trimmed;
  final head = trimmed.substring(0, limit ~/ 2);
  final tail = trimmed.substring(trimmed.length - (limit ~/ 2));
  return '$head\n...\n$tail';
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

// 脱敏任意 JSON 值，保留结构以便最终报告嵌入上游报告摘要。
Object? _redactJsonValue(Object? value) {
  if (value is String) return _redactText(value);
  if (value is num || value is bool || value == null) return value;
  if (value is List) {
    return value.map(_redactJsonValue).toList(growable: false);
  }
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): _redactJsonValue(entry.value),
    };
  }
  return _redactText(value.toString());
}

// 验收参数。
final class _AcceptanceOptions {
  const _AcceptanceOptions({
    required this.outDir,
    required this.archiveDir,
    required this.reportDir,
    required this.probeTimeout,
    required this.stepTimeout,
    required this.requireComplete,
    required this.help,
  });

  final Directory outDir;
  final Directory archiveDir;
  final Directory reportDir;
  final Duration probeTimeout;
  final Duration stepTimeout;
  final bool requireComplete;
  final bool help;

  // 解析命令行参数。
  static _AcceptanceOptions parse(List<String> args) {
    var outDir = Directory('recordings/v4-smoke');
    Directory? archiveDir;
    Directory? reportDir;
    var probeTimeoutSeconds = 4;
    var stepTimeoutSeconds = 60;
    var requireComplete = false;
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
        case '--report-dir':
          reportDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--probe-timeout':
          probeTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--step-timeout':
          stepTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--require-complete':
          requireComplete = true;
        default:
          throw ArgumentError('未知参数：$arg');
      }
    }

    return _AcceptanceOptions(
      outDir: outDir,
      archiveDir: archiveDir ?? Directory('${outDir.path}/archives'),
      reportDir: reportDir ?? Directory('${outDir.path}/acceptance'),
      probeTimeout: Duration(seconds: probeTimeoutSeconds),
      stepTimeout: Duration(seconds: stepTimeoutSeconds),
      requireComplete: requireComplete,
      help: help,
    );
  }
}

// 参数读取 helper。
String _nextValue(List<String> args, int index, String name) {
  if (index + 1 >= args.length) {
    throw ArgumentError('$name 缺少参数值。');
  }
  return args[index + 1];
}

// 验收步骤定义。
final class _AcceptanceStep {
  const _AcceptanceStep({
    required this.name,
    required this.arguments,
    this.requiredForAudit = false,
  });

  final String name;
  final List<String> arguments;
  final bool requiredForAudit;

  String get commandLine {
    return _redactText('${Platform.resolvedExecutable} ${arguments.join(' ')}');
  }

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'name': name,
      'command': commandLine,
      'requiredForAudit': requiredForAudit,
    };
  }
}

// 验收步骤结果。
final class _AcceptanceStepResult {
  const _AcceptanceStepResult({
    required this.step,
    required this.exitCode,
    required this.timedOut,
    required this.startedAt,
    required this.finishedAt,
    required this.stdoutText,
    required this.stderrText,
  });

  final _AcceptanceStep step;
  final int exitCode;
  final bool timedOut;
  final DateTime startedAt;
  final DateTime finishedAt;
  final String stdoutText;
  final String stderrText;

  bool get passed => exitCode == 0 && !timedOut;

  Duration get duration => finishedAt.difference(startedAt);

  String get statusLabel {
    if (timedOut) return '超时';
    return passed ? '通过' : '未通过';
  }

  String get failureLabel {
    final issue = stderrText.trim().isEmpty ? stdoutText : stderrText;
    final shortIssue = _shortBlock(
      issue,
      limit: 260,
    ).replaceAll('\n', ' ').trim();
    if (shortIssue.isEmpty) return '${step.name}：$statusLabel';
    return '${step.name}：$statusLabel，$shortIssue';
  }

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'step': step.toJsonObject(),
      'status': statusLabel,
      'passed': passed,
      'exitCode': exitCode,
      'timedOut': timedOut,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'durationSeconds': duration.inSeconds,
      'stdoutPreview': _shortBlock(stdoutText),
      'stderrPreview': _shortBlock(stderrText),
    };
  }
}

// 最终验收报告。
final class _AcceptanceReport {
  const _AcceptanceReport({
    required this.timestamp,
    required this.git,
    required this.requireComplete,
    required this.outDir,
    required this.evidence,
    required this.results,
  });

  final DateTime timestamp;
  final String git;
  final bool requireComplete;
  final String outDir;
  final _AcceptanceEvidenceSummary evidence;
  final List<_AcceptanceStepResult> results;

  bool get auditOk {
    return results
        .where((result) => result.step.requiredForAudit)
        .every((result) => result.passed);
  }

  bool get complete => results.every((result) => result.passed);

  List<String> get finalFailures {
    return results
        .where((result) => !result.passed)
        .map((result) => result.failureLabel)
        .toList(growable: false);
  }

  // 根据最终失败摘要生成可执行下一步，不读取本机隐私信息。
  List<String> get nextSteps {
    if (finalFailures.isEmpty) {
      return const <String>['保留本次报告，进入交付复核。'];
    }
    return _nextStepsForFailures(
      failures: finalFailures,
      auditOk: auditOk,
      evidence: evidence,
    );
  }

  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJsonObject())}\n';
  }

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'v4FinalAcceptance',
      'timestamp': timestamp.toIso8601String(),
      'git': git,
      'requireComplete': requireComplete,
      'outDir': outDir,
      'completion': <String, Object?>{
        'auditOk': auditOk,
        'complete': complete,
        'label': complete
            ? '最终验收通过'
            : auditOk
            ? '最终验收未完成'
            : '基础审计失败',
        'failures': finalFailures,
      },
      'evidence': evidence.toJsonObject(),
      'nextSteps': nextSteps,
      'steps': results.map((result) => result.toJsonObject()).toList(),
    };
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# V4 Final Acceptance')
      ..writeln()
      ..writeln('- 时间：${timestamp.toIso8601String()}')
      ..writeln('- 提交：$git')
      ..writeln('- 来源：`$outDir`')
      ..writeln('- 完成：${complete ? '通过' : '未完成'}')
      ..writeln('- 基础审计：${auditOk ? '通过' : '失败'}')
      ..writeln()
      ..writeln('## 步骤')
      ..writeln()
      ..writeln('| 步骤 | 结果 | 退出码 | 耗时 |')
      ..writeln('|---|---|---:|---:|');
    for (final result in results) {
      buffer.writeln(
        '| ${result.step.name} | ${result.statusLabel} | ${result.exitCode} | ${result.duration.inSeconds}s |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## 结论')
      ..writeln();
    if (finalFailures.isEmpty) {
      buffer.writeln('- 最终验收通过。');
    } else {
      for (final failure in finalFailures) {
        buffer.writeln('- $failure');
      }
    }
    buffer.write(evidence.toMarkdown());
    buffer
      ..writeln()
      ..writeln('## 下一步')
      ..writeln();
    for (final step in nextSteps) {
      buffer.writeln('- $step');
    }
    return buffer.toString();
  }
}

// AcceptanceEvidenceSummary 汇总刚生成的 readiness 和 archive 脱敏摘要。
final class _AcceptanceEvidenceSummary {
  const _AcceptanceEvidenceSummary({
    required this.readiness,
    required this.archive,
  });

  final Map<String, Object?>? readiness;
  final Map<String, Object?>? archive;

  // 从本地报告目录读取最新 readiness / archive JSON，只读结构化摘要。
  static Future<_AcceptanceEvidenceSummary> load({
    required Directory outDir,
    required Directory archiveDir,
  }) async {
    return _AcceptanceEvidenceSummary(
      readiness: await _loadLatestReadiness(outDir),
      archive: await _loadLatestArchive(archiveDir),
    );
  }

  // 转为机器可读摘要，缺失报告时显式为 null。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{'readiness': readiness, 'archive': archive};
  }

  // 转为 Markdown 现场摘要，便于最终报告直接复盘。
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln()
      ..writeln('## 现场摘要')
      ..writeln();
    if (readiness == null && archive == null) {
      buffer.writeln('- 未读取到 readiness 或 archive 摘要。');
      return buffer.toString();
    }
    if (readiness != null) {
      final localState = _jsonMapAt(readiness!, 'localState');
      buffer
        ..writeln('### 本机状态')
        ..writeln()
        ..writeln('| 项目 | 摘要 |')
        ..writeln('|---|---|');
      for (final entry in <String, String>{
        'Appium': 'appium',
        'iOS 隧道': 'iosTunnel',
        'iOS 手机': 'iosDevice',
        'Android 手机': 'androidDevice',
      }.entries) {
        buffer.writeln(
          '| ${entry.key} | ${_localStateLabel(localState[entry.value])} |',
        );
      }
      buffer.writeln();
      final artifacts = _jsonMapAt(readiness!, 'artifacts');
      final androidPreflight = _jsonMapAt(artifacts, 'latestAndroidPreflight');
      final batches = _jsonMapList(readiness!['batches']);
      if (batches.isNotEmpty) {
        buffer
          ..writeln('### 批次验收')
          ..writeln()
          ..writeln('| 批次 | 判定 | 证据 |')
          ..writeln('|---|---|---|');
        for (final batch in batches) {
          buffer.writeln(
            '| ${_plainText(batch['name']?.toString() ?? '未知批次')} | '
            '${_plainText(batch['status']?.toString() ?? '未知')} | '
            '${_plainText(batch['evidence']?.toString() ?? '无')} |',
          );
        }
        buffer.writeln();
      }
      if (androidPreflight.isNotEmpty) {
        buffer
          ..writeln('### Android smoke 前置诊断')
          ..writeln()
          ..writeln(
            '- 最近：${_plainText(androidPreflight['summary']?.toString() ?? '无摘要')}',
          );
        final blockers = _jsonStringList(androidPreflight['blockers']);
        if (blockers.isNotEmpty) {
          buffer.writeln('- 阻断：${blockers.join('、')}');
        }
        buffer.writeln();
      }
    }
    if (archive != null) {
      final latestFullSmoke = _jsonMapAt(archive!, 'latestFullSmoke');
      if (latestFullSmoke.isNotEmpty) {
        buffer
          ..writeln('### 最近完整冒烟')
          ..writeln()
          ..writeln('- 最近：${_latestFullSmokeLine(latestFullSmoke)}');
        final blockers = _jsonStringList(latestFullSmoke['blockers']);
        if (blockers.isNotEmpty) {
          buffer.writeln('- 阻断：${blockers.join('、')}');
        }
        buffer.writeln();
      }
      final counts = _jsonMapAt(archive!, 'counts');
      buffer
        ..writeln('### 留档数量')
        ..writeln()
        ..writeln('| 项目 | 数量 |')
        ..writeln('|---|---:|')
        ..writeln('| 截图 | ${counts['screenshots'] ?? 0} |')
        ..writeln('| iOS 运行 | ${counts['iosRuns'] ?? 0} |')
        ..writeln('| Android 运行 | ${counts['androidRuns'] ?? 0} |')
        ..writeln('| Full smoke | ${counts['fullSmokeReports'] ?? 0} |')
        ..writeln();
    }
    return buffer.toString();
  }
}

// 格式化 archive 中最近 full smoke 的短摘要。
String _latestFullSmokeLine(Map<String, Object?> summary) {
  final label = _plainText(summary['label']?.toString() ?? '未知');
  final timestamp = _plainText(summary['timestamp']?.toString() ?? '无时间');
  return '$label，时间 $timestamp';
}

// 读取最新 readiness 报告的关键摘要。
Future<Map<String, Object?>?> _loadLatestReadiness(Directory outDir) async {
  final json = await _loadLatestJson(
    outDir,
    RegExp(r'^SMOKE_READINESS_.*\.json$'),
  );
  if (json == null) return null;
  return <String, Object?>{
    'completion': _redactJsonValue(_jsonMapAt(json, 'completion')),
    'localState': _redactJsonValue(_jsonMapAt(json, 'localState')),
    'batches': _redactJsonValue(json['batches']),
    'artifacts': <String, Object?>{
      'androidPreflightReports':
          _jsonMapAt(json, 'artifacts')['androidPreflightReports'] ?? 0,
      'latestIos': _redactJsonValue(_jsonMapAt(json, 'artifacts')['latestIos']),
      'latestAndroid': _redactJsonValue(
        _jsonMapAt(json, 'artifacts')['latestAndroid'],
      ),
      'latestAndroidPreflight': _redactJsonValue(
        _jsonMapAt(json, 'artifacts')['latestAndroidPreflight'],
      ),
    },
    'nextSteps': _redactJsonValue(json['nextSteps']),
  };
}

// 读取最新 archive 报告的关键摘要。
Future<Map<String, Object?>?> _loadLatestArchive(Directory archiveDir) async {
  final json = await _loadLatestJson(
    archiveDir,
    RegExp(r'^SMOKE_ARCHIVE_.*\.json$'),
  );
  if (json == null) return null;
  final summary = _jsonMapAt(json, 'summary');
  return <String, Object?>{
    'counts': <String, Object?>{
      'screenshots': summary['screenshots'] ?? 0,
      'iosRuns': summary['iosRuns'] ?? 0,
      'androidRuns': summary['androidRuns'] ?? 0,
      'fullSmokeReports': summary['fullSmokeReports'] ?? 0,
    },
    'latestFullSmoke': _redactJsonValue(summary['latestFullSmoke']),
    'warnings': _redactJsonValue(json['warnings']),
  };
}

// 读取目录下最新匹配 JSON，按文件名时间戳倒序挑选。
Future<Map<String, Object?>?> _loadLatestJson(
  Directory dir,
  RegExp namePattern,
) async {
  if (!await dir.exists()) return null;
  final files = <File>[];
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (namePattern.hasMatch(name)) files.add(entity);
  }
  if (files.isEmpty) return null;
  files.sort(
    (left, right) =>
        right.uri.pathSegments.last.compareTo(left.uri.pathSegments.last),
  );
  try {
    final decoded = jsonDecode(await files.first.readAsString());
    if (decoded is! Map) return null;
    return Map<String, Object?>.from(decoded);
  } on Object {
    return null;
  }
}

// 安全读取嵌套 Map。
Map<String, Object?> _jsonMapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

// 读取 JSON 对象列表，坏值过滤；用于嵌入 Batch 0-8 验收索引。
List<Map<String, Object?>> _jsonMapList(Object? value) {
  if (value is! Iterable) return const <Map<String, Object?>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, Object?>.from(item))
      .toList(growable: false);
}

// 读取 JSON 字符串列表，坏值直接过滤并脱敏。
List<String> _jsonStringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => _plainText(item?.toString() ?? ''))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

// 生成适合 Markdown 单行展示的脱敏文本。
String _plainText(String value) {
  return _redactText(value).replaceAll(RegExp(r'\s+'), ' ').trim();
}

// 生成本机状态短摘要，避免 Markdown 报告铺满底层字段。
String _localStateLabel(Object? value) {
  if (value is! Map) return '未知';
  final map = Map<String, Object?>.from(value);
  final status = map['status']?.toString();
  final detail = map['detail']?.toString();
  if ((status == null || status.isEmpty) &&
      (detail == null || detail.isEmpty)) {
    return '未知';
  }
  if (detail == null || detail.isEmpty) return status ?? '未知';
  if (status == null || status.isEmpty) return detail;
  return '$status，$detail';
}

// 从失败文本中提炼下一步命令，保证最终报告能直接指导现场补验。
List<String> _nextStepsForFailures({
  required List<String> failures,
  required bool auditOk,
  required _AcceptanceEvidenceSummary evidence,
}) {
  final joined = failures.join('\n');
  final steps = <String>[];
  final counts = _jsonMapAt(
    evidence.archive ?? const <String, Object?>{},
    'counts',
  );
  final readinessArtifacts = _jsonMapAt(
    evidence.readiness ?? const <String, Object?>{},
    'artifacts',
  );
  final latestFullSmoke = _jsonMapAt(
    evidence.archive ?? const <String, Object?>{},
    'latestFullSmoke',
  );
  final needsIosSmoke =
      joined.contains('iOS 平台') ||
      (counts.isNotEmpty && (counts['iosRuns'] ?? 0) == 0) ||
      _reportIsNotFullPassed(readinessArtifacts['latestIos']);
  final needsAndroidSmoke =
      joined.contains('Android 平台') ||
      (counts.isNotEmpty && (counts['androidRuns'] ?? 0) == 0) ||
      _reportIsNotFullPassed(readinessArtifacts['latestAndroid']);
  final needsFullSmoke =
      joined.contains('full smoke') ||
      joined.contains('双平台完整 smoke') ||
      (latestFullSmoke.isNotEmpty && latestFullSmoke['complete'] != true);
  final latestFullSmokeBlockers = _jsonStringList(latestFullSmoke['blockers']);
  final latestFullSmokeNeedsIosTunnel = latestFullSmokeBlockers.any(
    (blocker) => blocker.contains('iOS 隧道'),
  );
  if (!auditOk) {
    steps.add(
      '基础：先运行 `npm run v4:smoke-readiness` 和 `npm run v4:smoke-archive`。',
    );
  }
  if (needsIosSmoke) {
    if (latestFullSmokeNeedsIosTunnel) {
      steps.add(
        'iOS：先用 Mac App 点连接设备，或运行 `npm run v4:ios-smoke:full:password-stdin` 启动隧道后补验。',
      );
    } else {
      steps.add('iOS：连接并信任一台 iPhone，运行 `npm run v4:ios-smoke:full`。');
    }
  }
  if (needsAndroidSmoke) {
    steps.add('Android：连接一台已开启 USB 调试的手机，运行 `npm run v4:android-smoke:full`。');
  }
  if (joined.contains('截图') ||
      (counts.isNotEmpty && (counts['screenshots'] ?? 0) == 0)) {
    steps.add('截图：保留 Mac App 或设备 smoke 截图，再重新生成 archive。');
  }
  if (needsFullSmoke) {
    steps.add('双平台：iOS 和 Android 单平台 smoke 都通过后，运行 `npm run v4:smoke:full`。');
  }
  steps.add('终验：补齐留档后运行 `npm run v4:acceptance-final`。');
  return steps.toSet().toList(growable: false);
}

// 判断单平台 smoke 摘要是否存在但尚未完整通过。
bool _reportIsNotFullPassed(Object? value) {
  if (value == null) return false;
  if (value is Map<String, Object?>) return value['fullPassed'] != true;
  if (value is Map)
    return Map<String, Object?>.from(value)['fullPassed'] != true;
  return false;
}

const _usage = '''
V4 final acceptance

用法：
  fvm dart run tool/v4_final_acceptance.dart [选项]

选项：
  --out-dir <path>          smoke 结果目录，默认 recordings/v4-smoke
  --archive-dir <path>      archive 输出目录，默认 <out-dir>/archives
  --report-dir <path>       final acceptance 输出目录，默认 <out-dir>/acceptance
  --probe-timeout <seconds> readiness / archive 探测超时，默认 4
  --step-timeout <seconds>  单步骤超时，默认 60
  --require-complete        最终验收未通过时返回非 0
  --help                    查看帮助
''';
