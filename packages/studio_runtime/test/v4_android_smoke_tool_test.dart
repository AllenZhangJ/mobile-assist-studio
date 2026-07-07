import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// V4 Android smoke CLI 回归。
// 测试使用 fake adb 和空 Appium 端口，不连接真实手机。
void main() {
  test('writes preflight report when Appium is unavailable', () async {
    final result = await _runSmokeWithFakeAdb('''
#!/bin/sh
if [ "\$1" = "devices" ]; then
  echo "List of devices attached"
  echo "ZY22ABCDEF device product:oriole model:Pixel_9 release:15 transport_id:1"
  exit 0
fi
exit 1
''');

    try {
      expect(result.process.exitCode, 1);
      expect(result.process.stdout, contains('诊断：'));
      expect(result.process.stdout, contains('摘要：'));
      expect(result.process.stderr, contains('Android 冒烟前置检查未通过：驱动'));

      final report = await _readPreflightReport(result.outDir);
      final completion = report.json['completion'] as Map<String, Object?>;
      final android = report.check('安卓手机');

      expect(report.json['kind'], 'v4AndroidSmokePreflight');
      expect(completion['ready'], isFalse);
      expect(completion['blockers'], contains('驱动'));
      expect(android['ok'], isTrue);
      expect(android['ready'], 1);

      expect(report.markdown, contains('# V4 Android Smoke Preflight'));
      expect(report.markdown, contains('| 驱动 | 阻断 |'));
      expect(report.markdown, contains('| 安卓手机 | 通过 |'));
    } finally {
      await result.temp.delete(recursive: true);
    }
  });

  test(
    'writes state-specific preflight report when Android is missing',
    () async {
      final result = await _runSmokeWithFakeAdb('''
#!/bin/sh
if [ "\$1" = "devices" ]; then
  echo "List of devices attached"
  exit 0
fi
exit 1
''');

      try {
        expect(result.process.exitCode, 1);
        expect(result.process.stderr, contains('Android 冒烟前置检查未通过：驱动、安卓手机'));

        final report = await _readPreflightReport(result.outDir);
        final android = report.check('安卓手机');
        final nextSteps = (report.json['nextSteps'] as List).cast<String>();

        expect(android['ok'], isFalse);
        expect(android['detail'], '可用 0，未授权 0，离线 0');
        expect(android['ready'], 0);
        expect(android['unauthorized'], 0);
        expect(android['offline'], 0);
        expect(android['nextStep'], '开启 USB 调试，插线并在手机上点允许。');
        expect(nextSteps, contains('开启 USB 调试，插线并在手机上点允许。'));
        expect(
          report.markdown,
          contains('| 安卓手机 | 阻断 | 可用 0，未授权 0，离线 0 | 开启 USB 调试，插线并在手机上点允许。 |'),
        );
      } finally {
        await result.temp.delete(recursive: true);
      }
    },
  );

  test(
    'writes state-specific preflight report when Android is unauthorized',
    () async {
      final result = await _runSmokeWithFakeAdb('''
#!/bin/sh
if [ "\$1" = "devices" ]; then
  echo "List of devices attached"
  echo "ZY22ABCDEF unauthorized product:oriole model:Pixel_9 release:15 transport_id:1"
  exit 0
fi
exit 1
''');

      try {
        expect(result.process.exitCode, 1);
        expect(result.process.stderr, contains('Android 冒烟前置检查未通过：驱动、安卓手机'));

        final report = await _readPreflightReport(result.outDir);
        final android = report.check('安卓手机');
        final nextSteps = (report.json['nextSteps'] as List).cast<String>();

        expect(android['ok'], isFalse);
        expect(android['detail'], '可用 0，未授权 1，离线 0');
        expect(android['ready'], 0);
        expect(android['unauthorized'], 1);
        expect(android['offline'], 0);
        expect(android['nextStep'], '在 Android 手机上允许 USB 调试后重试。');
        expect(nextSteps, contains('在 Android 手机上允许 USB 调试后重试。'));
        expect(
          report.markdown,
          contains(
            '| 安卓手机 | 阻断 | 可用 0，未授权 1，离线 0 | 在 Android 手机上允许 USB 调试后重试。 |',
          ),
        );
      } finally {
        await result.temp.delete(recursive: true);
      }
    },
  );
}

// 运行 Android smoke CLI，并用 fake adb 输出模拟本机设备状态。
Future<_SmokeRunResult> _runSmokeWithFakeAdb(String adbScript) async {
  final temp = await Directory.systemTemp.createTemp('ias-android-smoke-tool-');
  final binDir = Directory('${temp.path}/bin');
  await binDir.create(recursive: true);
  final adb = File('${binDir.path}/adb');
  await adb.writeAsString(adbScript);
  await Process.run('chmod', ['+x', adb.path]);

  final outDir = Directory('${temp.path}/out');
  final port = await _unusedLocalPort();
  final process = await Process.run(
    Platform.resolvedExecutable,
    [
      'run',
      'tool/v4_android_smoke.dart',
      '--host',
      '127.0.0.1',
      '--port',
      '$port',
      '--timeout',
      '1',
      '--out-dir',
      outDir.path,
    ],
    workingDirectory: Directory.current.path,
    environment: {
      ...Platform.environment,
      'PATH': '${binDir.path}:${Platform.environment['PATH'] ?? ''}',
      'DART_SUPPRESS_ANALYTICS': 'true',
      'FLUTTER_SUPPRESS_ANALYTICS': 'true',
    },
  ).timeout(const Duration(seconds: 30));

  return _SmokeRunResult(temp: temp, outDir: outDir, process: process);
}

// 读取 CLI 生成的 Android preflight JSON 和 Markdown。
Future<_PreflightReport> _readPreflightReport(Directory outDir) async {
  final jsonFiles = await _matchingFiles(
    outDir,
    RegExp(r'^ANDROID_SMOKE_PREFLIGHT_.*\.json$'),
  );
  final markdownFiles = await _matchingFiles(
    outDir,
    RegExp(r'^ANDROID_SMOKE_PREFLIGHT_.*\.md$'),
  );
  expect(jsonFiles, hasLength(1));
  expect(markdownFiles, hasLength(1));

  final json =
      jsonDecode(await jsonFiles.single.readAsString()) as Map<String, Object?>;
  final markdown = await markdownFiles.single.readAsString();
  return _PreflightReport(json: json, markdown: markdown);
}

// 保存一次 CLI 运行结果和临时目录，方便测试结束后清理。
final class _SmokeRunResult {
  const _SmokeRunResult({
    required this.temp,
    required this.outDir,
    required this.process,
  });

  final Directory temp;
  final Directory outDir;
  final ProcessResult process;
}

// 包装 Android preflight 留档，提供按检查项名称读取的 helper。
final class _PreflightReport {
  const _PreflightReport({required this.json, required this.markdown});

  final Map<String, Object?> json;
  final String markdown;

  Map<String, Object?> check(String name) {
    final checks = (json['checks'] as List).cast<Map<String, Object?>>();
    return checks.singleWhere((check) => check['name'] == name);
  }
}

// 找一个当前未监听的本机端口，用于稳定模拟 Appium 不可达。
Future<int> _unusedLocalPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

// 列出文件名匹配的文件，按名称排序便于断言。
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
