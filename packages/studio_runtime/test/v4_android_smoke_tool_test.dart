import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

// V4 Android smoke CLI 回归。
// 测试使用 fake adb 和空 Appium 端口，不连接真实手机。
void main() {
  test('writes preflight report when Appium is unavailable', () async {
    final temp = await Directory.systemTemp.createTemp(
      'ias-android-smoke-tool-',
    );
    try {
      final binDir = Directory('${temp.path}/bin');
      await binDir.create(recursive: true);
      final adb = File('${binDir.path}/adb');
      await adb.writeAsString('''
#!/bin/sh
if [ "\$1" = "devices" ]; then
  echo "List of devices attached"
  echo "ZY22ABCDEF device product:oriole model:Pixel_9 release:15 transport_id:1"
  exit 0
fi
exit 1
''');
      await Process.run('chmod', ['+x', adb.path]);

      final outDir = Directory('${temp.path}/out');
      final port = await _unusedLocalPort();
      final result = await Process.run(
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

      expect(result.exitCode, 1);
      expect(result.stdout, contains('诊断：'));
      expect(result.stdout, contains('摘要：'));
      expect(result.stderr, contains('Android 冒烟前置检查未通过：驱动'));

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
          jsonDecode(await jsonFiles.single.readAsString())
              as Map<String, Object?>;
      final completion = json['completion'] as Map<String, Object?>;
      final checks = (json['checks'] as List).cast<Map<String, Object?>>();
      final android = checks.singleWhere((check) => check['name'] == '安卓手机');

      expect(json['kind'], 'v4AndroidSmokePreflight');
      expect(completion['ready'], isFalse);
      expect(completion['blockers'], contains('驱动'));
      expect(android['ok'], isTrue);
      expect(android['ready'], 1);

      final markdown = await markdownFiles.single.readAsString();
      expect(markdown, contains('# V4 Android Smoke Preflight'));
      expect(markdown, contains('| 驱动 | 阻断 |'));
      expect(markdown, contains('| 安卓手机 | 通过 |'));
    } finally {
      await temp.delete(recursive: true);
    }
  });
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
