import 'dart:async';
import 'dart:io';

// V4 full smoke 编排 iOS 与 Android 完整真机冒烟，并始终生成汇总留档。
// 它只调用既有 Dart smoke 入口，不引入 Node 中间层，也不直接操作设备。
Future<void> main(List<String> args) async {
  final options = _FullSmokeOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }
  if (options.skipIos && options.skipAndroid) {
    _fail('至少需要保留一个平台 smoke。');
  }
  if (!options.dryRun && !options.confirmActions) {
    _fail('完整冒烟会真实 Tap / Swipe / Input；请加 --confirm-actions 确认。');
  }

  final timestamp = DateTime.now().toUtc();
  final steps = _buildSteps(options);
  if (options.dryRun) {
    _printDryRun(steps);
    return;
  }

  await options.outDir.create(recursive: true);
  final results = <_FullSmokeResult>[];
  for (final step in steps) {
    results.add(await _runStep(step, options.stepTimeout));
  }

  final report = File(
    '${options.outDir.path}/FULL_SMOKE_${_safeTimestamp(timestamp)}.md',
  );
  await report.writeAsString(
    _summaryMarkdown(timestamp: timestamp, results: results),
    flush: true,
  );
  stdout.writeln('\nFull smoke report: ${report.path}');

  final failed = results.where((result) => result.exitCode != 0).toList();
  if (failed.isNotEmpty) {
    _fail(
      'V4 full smoke 未完成：${failed.map((item) => item.step.name).join('、')}。',
    );
  }
}

// 根据选项生成稳定的执行步骤，两个平台失败互不阻断，最后仍跑完成审计。
List<_FullSmokeStep> _buildSteps(_FullSmokeOptions options) {
  final steps = <_FullSmokeStep>[
    if (!options.skipIos)
      _FullSmokeStep(
        name: 'iOS 完整冒烟',
        executable: 'fvm',
        arguments: [
          'dart',
          'run',
          'tool/v4_ios_smoke.dart',
          '--out-dir',
          _platformOutDir(options.outDir, 'ios'),
          '--workflow-basic',
          '--allow-actions',
        ],
        workingDirectory: 'packages/studio_runtime',
      ),
    if (!options.skipAndroid)
      _FullSmokeStep(
        name: 'Android 完整冒烟',
        executable: 'fvm',
        arguments: [
          'dart',
          'run',
          'tool/v4_android_smoke.dart',
          '--out-dir',
          _platformOutDir(options.outDir, 'android'),
          '--workflow-basic',
          '--allow-actions',
        ],
        workingDirectory: 'packages/studio_runtime',
      ),
    _FullSmokeStep(
      name: '完整门禁审计',
      executable: 'fvm',
      arguments: [
        'dart',
        'run',
        'tool/v4_smoke_readiness.dart',
        '--out-dir',
        options.outDir.path,
        '--require-complete',
      ],
    ),
  ];
  return steps;
}

// 子 smoke 工具从 packages/studio_runtime 运行，默认输出目录需要相对回到根目录。
String _platformOutDir(Directory outDir, String platform) {
  final base = _trimTrailingSlash(outDir.path);
  if (base.startsWith('/')) return '$base/$platform';
  return '../../$base/$platform';
}

// 去掉路径尾部斜线，保持命令展示和文件拼接稳定。
String _trimTrailingSlash(String value) {
  var result = value.trim();
  while (result.length > 1 && result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result.isEmpty ? '.' : result;
}

// 执行单个步骤并捕获输出，超时也会形成可写入报告的结果。
Future<_FullSmokeResult> _runStep(_FullSmokeStep step, Duration timeout) async {
  final startedAt = DateTime.now().toUtc();
  stdout.writeln('\n== ${step.name} ==');
  stdout.writeln(_redactText(step.commandLine));

  try {
    final process = await Process.run(
      step.executable,
      step.arguments,
      workingDirectory: step.workingDirectory,
      environment: {
        ...Platform.environment,
        'DART_SUPPRESS_ANALYTICS': 'true',
        'FLUTTER_SUPPRESS_ANALYTICS': 'true',
      },
    ).timeout(timeout);
    final finishedAt = DateTime.now().toUtc();
    final result = _FullSmokeResult(
      step: step,
      exitCode: process.exitCode,
      stdoutText: _redactText('${process.stdout}'),
      stderrText: _redactText('${process.stderr}'),
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
    stdout.writeln('${step.name}：${result.statusLabel}');
    return result;
  } on TimeoutException {
    final finishedAt = DateTime.now().toUtc();
    stdout.writeln('${step.name}：超时');
    return _FullSmokeResult(
      step: step,
      exitCode: 124,
      stdoutText: '',
      stderrText: 'step timeout after ${timeout.inSeconds}s',
      startedAt: startedAt,
      finishedAt: finishedAt,
      timedOut: true,
    );
  } on ProcessException catch (error) {
    final finishedAt = DateTime.now().toUtc();
    stdout.writeln('${step.name}：启动失败');
    return _FullSmokeResult(
      step: step,
      exitCode: 127,
      stdoutText: '',
      stderrText: _redactText(error.message),
      startedAt: startedAt,
      finishedAt: finishedAt,
    );
  }
}

// dry-run 只展示将要执行的命令，用于本地确认和 CI 语法检查。
void _printDryRun(List<_FullSmokeStep> steps) {
  stdout.writeln('V4 full smoke dry-run');
  for (final step in steps) {
    stdout.writeln('- ${step.name}: ${_redactText(step.commandLine)}');
  }
}

// 生成本地 Markdown 汇总，保留失败原因但脱敏路径、设备号和 session。
String _summaryMarkdown({
  required DateTime timestamp,
  required List<_FullSmokeResult> results,
}) {
  final buffer = StringBuffer()
    ..writeln('# V4 Full Smoke')
    ..writeln()
    ..writeln('- 时间：${timestamp.toIso8601String()}')
    ..writeln('- 动作：真实 Tap / Swipe / Input + 基础 Project DSL workflow')
    ..writeln()
    ..writeln('| 步骤 | 结果 | 退出码 | 耗时 |')
    ..writeln('|---|---|---:|---:|');
  for (final result in results) {
    buffer.writeln(
      '| ${result.step.name} | ${result.statusLabel} | ${result.exitCode} | ${result.duration.inSeconds}s |',
    );
  }
  buffer.writeln();

  for (final result in results) {
    buffer
      ..writeln('## ${result.step.name}')
      ..writeln()
      ..writeln('- 命令：`${_redactText(result.step.commandLine)}`')
      ..writeln('- 开始：${result.startedAt.toIso8601String()}')
      ..writeln('- 结束：${result.finishedAt.toIso8601String()}')
      ..writeln('- 结果：${result.statusLabel}')
      ..writeln();
    _writeOutputBlock(buffer, 'stdout', result.stdoutText);
    _writeOutputBlock(buffer, 'stderr', result.stderrText);
  }
  return buffer.toString();
}

// 写入裁剪后的输出块，避免报告被长日志淹没。
void _writeOutputBlock(StringBuffer buffer, String title, String value) {
  final trimmed = _shortBlock(value);
  if (trimmed.isEmpty) return;
  buffer
    ..writeln('### $title')
    ..writeln()
    ..writeln('```text')
    ..writeln(trimmed.replaceAll('```', '` ` `'))
    ..writeln('```')
    ..writeln();
}

// 裁剪长输出，保留开头和结尾，便于定位失败。
String _shortBlock(String value, {int limit = 2200}) {
  final trimmed = value.trim();
  if (trimmed.length <= limit) return trimmed;
  final head = trimmed.substring(0, limit ~/ 2);
  final tail = trimmed.substring(trimmed.length - (limit ~/ 2));
  return '$head\n...\n$tail';
}

// 脱敏本机路径、长设备号和 UUID。
String _redactText(String value) {
  return value
      .replaceAll(RegExp(r'/Users/[^/\s]+'), '<home>')
      .replaceAll(
        RegExp(
          r'[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}',
        ),
        '<device-id>',
      )
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{24,}\b'), '<device-id>');
}

// 生成文件名安全时间戳。
String _safeTimestamp(DateTime value) {
  return value.toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
}

// V4 full smoke 参数。
final class _FullSmokeOptions {
  const _FullSmokeOptions({
    required this.outDir,
    required this.stepTimeout,
    required this.confirmActions,
    required this.skipIos,
    required this.skipAndroid,
    required this.dryRun,
    required this.help,
  });

  final Directory outDir;
  final Duration stepTimeout;
  final bool confirmActions;
  final bool skipIos;
  final bool skipAndroid;
  final bool dryRun;
  final bool help;

  // 解析命令行参数。
  static _FullSmokeOptions parse(List<String> args) {
    var outDir = Directory('recordings/v4-smoke');
    var stepTimeoutSeconds = 300;
    var confirmActions = false;
    var skipIos = false;
    var skipAndroid = false;
    var dryRun = false;
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
        case '--step-timeout':
          stepTimeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--confirm-actions':
          confirmActions = true;
        case '--skip-ios':
          skipIos = true;
        case '--skip-android':
          skipAndroid = true;
        case '--dry-run':
          dryRun = true;
        default:
          throw ArgumentError('未知参数：$arg');
      }
    }

    return _FullSmokeOptions(
      outDir: outDir,
      stepTimeout: Duration(seconds: stepTimeoutSeconds),
      confirmActions: confirmActions,
      skipIos: skipIos,
      skipAndroid: skipAndroid,
      dryRun: dryRun,
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

// 单个 full smoke 执行步骤。
final class _FullSmokeStep {
  const _FullSmokeStep({
    required this.name,
    required this.executable,
    required this.arguments,
    this.workingDirectory,
  });

  final String name;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;

  String get commandLine {
    final command = [executable, ...arguments].join(' ');
    if (workingDirectory == null) return command;
    return 'cd $workingDirectory && $command';
  }
}

// 单个步骤的脱敏执行结果。
final class _FullSmokeResult {
  const _FullSmokeResult({
    required this.step,
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
    required this.startedAt,
    required this.finishedAt,
    this.timedOut = false,
  });

  final _FullSmokeStep step;
  final int exitCode;
  final String stdoutText;
  final String stderrText;
  final DateTime startedAt;
  final DateTime finishedAt;
  final bool timedOut;

  Duration get duration => finishedAt.difference(startedAt);

  String get statusLabel {
    if (timedOut) return '超时';
    return exitCode == 0 ? '通过' : '失败';
  }
}

// 统一失败出口，保证本机和 CI 中表现一致。
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

const _usage = '''
V4 full smoke

用法：
  fvm dart run tool/v4_full_smoke.dart --confirm-actions [选项]

选项：
  --out-dir <path>          结果目录，默认 recordings/v4-smoke
  --step-timeout <seconds>  单个平台 smoke 超时，默认 300
  --confirm-actions         确认执行真实 Tap / Swipe / Input
  --skip-ios                跳过 iOS 完整冒烟
  --skip-android            跳过 Android 完整冒烟
  --dry-run                 只展示命令，不执行
  --help                    查看帮助
''';
