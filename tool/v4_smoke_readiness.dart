import 'dart:async';
import 'dart:convert';
import 'dart:io';

// V4 smoke readiness 只读采集本机状态，并写入脱敏 Markdown 留档。
// 它不启动驱动、不请求 sudo、不连接 session、不执行设备动作。
Future<void> main(List<String> args) async {
  final options = _SmokeReadinessOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  final timestamp = DateTime.now().toUtc();
  final report = await _collectReadiness(options, timestamp);
  await options.outDir.create(recursive: true);
  final file = File(
    '${options.outDir.path}/SMOKE_READINESS_${_safeTimestamp(timestamp)}.md',
  );
  await file.writeAsString(report.toMarkdown(), flush: true);
  stdout.writeln('Smoke readiness report: ${file.path}');
}

// 收集 Appium、iOS、Android、隧道和本地证据状态。
Future<_SmokeReadinessReport> _collectReadiness(
  _SmokeReadinessOptions options,
  DateTime timestamp,
) async {
  final git = await _currentGitCommit(options.timeout);
  final appium = await _probeHttpJson(
    Uri(
      scheme: 'http',
      host: options.host,
      port: options.appiumPort,
      path: '/status',
    ),
    timeout: options.timeout,
  );
  final tunnel = await _probeHttpJson(
    Uri(
      scheme: 'http',
      host: options.host,
      port: options.tunnelPort,
      path: '/remotexpc/tunnels',
    ),
    timeout: options.timeout,
  );
  final ios = await _probeIosDevices(options.timeout);
  final android = await _probeAndroidDevices(options.timeout);
  final artifacts = await _probeArtifacts(options.outDir);

  return _SmokeReadinessReport(
    timestamp: timestamp,
    git: git,
    appium: appium,
    tunnel: tunnel,
    ios: ios,
    android: android,
    artifacts: artifacts,
  );
}

// 当前 git commit 只保留短 hash，失败时返回未知。
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

// 探测 HTTP JSON 端点，保持短超时，避免 readiness 卡住。
Future<_HttpProbe> _probeHttpJson(Uri uri, {required Duration timeout}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri).timeout(timeout);
    final response = await request.close().timeout(timeout);
    final body = await utf8.decodeStream(response).timeout(timeout);
    final decoded = _safeJsonDecode(body);
    return _HttpProbe(
      reachable: true,
      statusCode: response.statusCode,
      ready: _jsonLooksReady(decoded),
      count: _jsonTunnelCount(decoded),
    );
  } on Object {
    return const _HttpProbe(reachable: false);
  } finally {
    client.close(force: true);
  }
}

// 探测当前 iOS 设备数量，只保留状态统计，不写设备标识。
Future<_IosProbe> _probeIosDevices(Duration timeout) async {
  final result = await _runProcess('xcrun', const [
    'devicectl',
    'list',
    'devices',
  ], timeout: timeout);
  if (result.exitCode != 0) {
    return _IosProbe(available: false, detail: _shortProcessIssue(result));
  }
  final lines = result.stdout
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  final deviceLines = lines
      .where((line) => line.contains('iPhone') || line.contains('iPad'))
      .toList(growable: false);
  final connected = deviceLines
      .where(
        (line) => line.contains(' connected ') || line.contains(' available '),
      )
      .length;
  final unavailable = deviceLines.length - connected;
  return _IosProbe(
    available: connected > 0,
    connected: connected,
    unavailable: unavailable < 0 ? 0 : unavailable,
  );
}

// 探测当前 Android 设备数量，只保留状态统计，不写 serial。
Future<_AndroidProbe> _probeAndroidDevices(Duration timeout) async {
  final result = await _runProcess('adb', const ['devices'], timeout: timeout);
  if (result.exitCode != 0) {
    return _AndroidProbe(available: false, detail: _shortProcessIssue(result));
  }
  var ready = 0;
  var unauthorized = 0;
  var offline = 0;
  for (final line in result.stdout.split('\n').skip(1)) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) continue;
    switch (parts[1]) {
      case 'device':
        ready += 1;
      case 'unauthorized':
        unauthorized += 1;
      case 'offline':
        offline += 1;
    }
  }
  return _AndroidProbe(
    available: ready > 0,
    ready: ready,
    unauthorized: unauthorized,
    offline: offline,
  );
}

// 统计本地 smoke 产物，避免打开截图或读取隐私内容。
Future<_ArtifactProbe> _probeArtifacts(Directory outDir) async {
  final uiScreenshots = await _countMatchingFiles(outDir, RegExp(r'\.png$'));
  final iosRuns = await _countRunDirs(Directory('${outDir.path}/ios'));
  final androidRuns = await _countRunDirs(Directory('${outDir.path}/android'));
  final markdownReports = await _countMatchingFiles(outDir, RegExp(r'\.md$'));
  return _ArtifactProbe(
    uiScreenshots: uiScreenshots,
    iosRuns: iosRuns,
    androidRuns: androidRuns,
    markdownReports: markdownReports,
  );
}

// 统计目录下匹配文件数量；不存在时视为 0。
Future<int> _countMatchingFiles(Directory dir, RegExp pattern) async {
  if (!await dir.exists()) return 0;
  var count = 0;
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is File && pattern.hasMatch(entity.path)) count += 1;
  }
  return count;
}

// 统计 smoke run 目录数量；不存在时视为 0。
Future<int> _countRunDirs(Directory dir) async {
  if (!await dir.exists()) return 0;
  var count = 0;
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is Directory) count += 1;
  }
  return count;
}

// 执行短命令并裁剪输出。
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

// 安全 JSON 解析，失败时返回 null。
Object? _safeJsonDecode(String body) {
  try {
    return jsonDecode(body);
  } on Object {
    return null;
  }
}

// 判断 Appium status 是否 ready。
bool? _jsonLooksReady(Object? decoded) {
  if (decoded is! Map) return null;
  final value = decoded['value'];
  if (value is Map && value['ready'] is bool) return value['ready'] as bool;
  if (decoded['ready'] is bool) return decoded['ready'] as bool;
  return null;
}

// 读取 XCUITest tunnel registry 里的隧道数量。
int? _jsonTunnelCount(Object? decoded) {
  if (decoded is! Map) return null;
  final tunnels = decoded['tunnels'];
  if (tunnels is Map) return tunnels.length;
  return null;
}

// 裁剪进程问题说明，避免报告过长。
String _shortProcessIssue(_ProcessProbe result) {
  final raw = result.stderr.trim().isEmpty ? result.stdout : result.stderr;
  if (raw.trim().isEmpty) return 'exit ${result.exitCode}';
  final compact = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 120) return compact;
  return '${compact.substring(0, 120)}...';
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

// smoke readiness 参数。
final class _SmokeReadinessOptions {
  const _SmokeReadinessOptions({
    required this.outDir,
    required this.host,
    required this.appiumPort,
    required this.tunnelPort,
    required this.timeout,
    required this.help,
  });

  final Directory outDir;
  final String host;
  final int appiumPort;
  final int tunnelPort;
  final Duration timeout;
  final bool help;

  // 解析命令行参数。
  static _SmokeReadinessOptions parse(List<String> args) {
    var outDir = Directory('recordings/v4-smoke');
    var host = '127.0.0.1';
    var appiumPort = 4723;
    var tunnelPort = 42314;
    var timeoutSeconds = 4;
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
        case '--host':
          host = _nextValue(args, index, arg);
          index += 1;
        case '--appium-port':
          appiumPort = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--tunnel-port':
          tunnelPort = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--timeout':
          timeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        default:
          throw ArgumentError('未知参数：$arg');
      }
    }

    return _SmokeReadinessOptions(
      outDir: outDir,
      host: host,
      appiumPort: appiumPort,
      tunnelPort: tunnelPort,
      timeout: Duration(seconds: timeoutSeconds),
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

// HTTP 探测结果。
final class _HttpProbe {
  const _HttpProbe({
    required this.reachable,
    this.statusCode,
    this.ready,
    this.count,
  });

  final bool reachable;
  final int? statusCode;
  final bool? ready;
  final int? count;

  String get statusLabel {
    if (!reachable) return '不可达';
    if (ready != null) return ready! ? '就绪' : '未就绪';
    if (count != null) return count! > 0 ? '有隧道' : '无隧道';
    return statusCode == null ? '未知' : 'HTTP $statusCode';
  }
}

// iOS 设备探测结果。
final class _IosProbe {
  const _IosProbe({
    required this.available,
    this.connected = 0,
    this.unavailable = 0,
    this.detail,
  });

  final bool available;
  final int connected;
  final int unavailable;
  final String? detail;
}

// Android 设备探测结果。
final class _AndroidProbe {
  const _AndroidProbe({
    required this.available,
    this.ready = 0,
    this.unauthorized = 0,
    this.offline = 0,
    this.detail,
  });

  final bool available;
  final int ready;
  final int unauthorized;
  final int offline;
  final String? detail;
}

// 本地 smoke 产物统计。
final class _ArtifactProbe {
  const _ArtifactProbe({
    required this.uiScreenshots,
    required this.iosRuns,
    required this.androidRuns,
    required this.markdownReports,
  });

  final int uiScreenshots;
  final int iosRuns;
  final int androidRuns;
  final int markdownReports;
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

// 汇总报告模型。
final class _SmokeReadinessReport {
  const _SmokeReadinessReport({
    required this.timestamp,
    required this.git,
    required this.appium,
    required this.tunnel,
    required this.ios,
    required this.android,
    required this.artifacts,
  });

  final DateTime timestamp;
  final String git;
  final _HttpProbe appium;
  final _HttpProbe tunnel;
  final _IosProbe ios;
  final _AndroidProbe android;
  final _ArtifactProbe artifacts;

  bool get iosFullSmokeReady =>
      appium.reachable && appium.ready == true && ios.available && _hasTunnel;

  bool get androidFullSmokeReady =>
      appium.reachable && appium.ready == true && android.available;

  bool get _hasTunnel => tunnel.reachable && (tunnel.count ?? 0) > 0;

  // 转成可留档的脱敏 Markdown。
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# V4 Smoke Readiness')
      ..writeln()
      ..writeln('- 时间：${timestamp.toIso8601String()}')
      ..writeln('- 提交：$git')
      ..writeln('- iOS 完整冒烟：${iosFullSmokeReady ? '可运行' : '未就绪'}')
      ..writeln('- Android 完整冒烟：${androidFullSmokeReady ? '可运行' : '未就绪'}')
      ..writeln()
      ..writeln('## 本机状态')
      ..writeln()
      ..writeln('| 项目 | 状态 | 说明 |')
      ..writeln('|---|---|---|')
      ..writeln('| Appium | ${appium.statusLabel} | ${_appiumDetail()} |')
      ..writeln('| iOS 隧道 | ${tunnel.statusLabel} | ${_tunnelDetail()} |')
      ..writeln(
        '| iOS 手机 | ${ios.available ? '可用' : '未就绪'} | ${_iosDetail()} |',
      )
      ..writeln(
        '| Android 手机 | ${android.available ? '可用' : '未就绪'} | ${_androidDetail()} |',
      )
      ..writeln()
      ..writeln('## 本地证据')
      ..writeln()
      ..writeln('- UI 截图：${artifacts.uiScreenshots}')
      ..writeln('- iOS smoke 记录：${artifacts.iosRuns}')
      ..writeln('- Android smoke 记录：${artifacts.androidRuns}')
      ..writeln('- Markdown 报告：${artifacts.markdownReports + 1}')
      ..writeln()
      ..writeln('## 下一步')
      ..writeln();

    if (!iosFullSmokeReady) {
      buffer.writeln('- iOS：先打开 Mac App 点“连接设备”，输入 Mac 密码，并在手机点允许。');
    }
    if (!androidFullSmokeReady) {
      buffer.writeln('- Android：连接一台已开启 USB 调试的手机，再运行 Android smoke。');
    }
    if (iosFullSmokeReady && androidFullSmokeReady) {
      buffer.writeln(
        '- 可继续运行 `npm run v4:ios-smoke` 和 `npm run v4:android-smoke`。',
      );
    }
    return buffer.toString();
  }

  String _appiumDetail() {
    if (!appium.reachable) return '未发现 4723 服务';
    return appium.ready == true ? '可接受连接' : '状态接口可达但未 ready';
  }

  String _tunnelDetail() {
    if (!tunnel.reachable) return '未发现 tunnel registry';
    return '隧道数量 ${tunnel.count ?? 0}';
  }

  String _iosDetail() {
    if (ios.detail != null) return ios.detail!;
    return '可用 ${ios.connected}，不可用 ${ios.unavailable}';
  }

  String _androidDetail() {
    if (android.detail != null) return android.detail!;
    return '可用 ${android.ready}，未授权 ${android.unauthorized}，离线 ${android.offline}';
  }
}

const _usage = '''
V4 smoke readiness

用法：
  fvm dart run tool/v4_smoke_readiness.dart [选项]

选项：
  --out-dir <path>       结果目录，默认 recordings/v4-smoke
  --host <host>          本机服务地址，默认 127.0.0.1
  --appium-port <port>   Appium 端口，默认 4723
  --tunnel-port <port>   XCUITest tunnel registry 端口，默认 42314
  --timeout <seconds>    单项探测超时，默认 4
  --help                 查看帮助
''';
