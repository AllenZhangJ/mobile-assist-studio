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
  final reportBase =
      '${options.outDir.path}/SMOKE_READINESS_${_safeTimestamp(timestamp)}';
  final markdownFile = File('$reportBase.md');
  final jsonFile = File('$reportBase.json');
  await markdownFile.writeAsString(report.toMarkdown(), flush: true);
  await jsonFile.writeAsString(report.toJsonString(), flush: true);
  stdout
    ..writeln('Smoke readiness report: ${_redactText(markdownFile.path)}')
    ..writeln('Smoke readiness json: ${_redactText(jsonFile.path)}');
  if (options.requireComplete && !report.isComplete) {
    stderr.writeln('V4 smoke completion audit failed: 双平台完整 smoke 尚未成功留档。');
    exit(2);
  }
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
  final iosDir = Directory('${outDir.path}/ios');
  final androidDir = Directory('${outDir.path}/android');
  final iosRuns = await _countRunDirs(iosDir);
  final androidRuns = await _countRunDirs(androidDir);
  final androidPreflightReports = await _countMatchingFiles(
    androidDir,
    RegExp(r'^ANDROID_SMOKE_PREFLIGHT_.*\.json$'),
  );
  final markdownReports = await _countMatchingFiles(outDir, RegExp(r'\.md$'));
  final jsonReports = await _countMatchingFiles(
    outDir,
    RegExp(r'^SMOKE_READINESS_.*\.json$'),
  );
  final fullSmokeReports = await _countMatchingFiles(
    outDir,
    RegExp(r'^FULL_SMOKE_.*\.json$'),
  );
  final latestIos = await _probeLatestSmokeRun(iosDir);
  final latestAndroid = await _probeLatestSmokeRun(androidDir);
  final latestAndroidPreflight = await _probeLatestAndroidPreflightReport(
    androidDir,
  );
  final latestFullSmoke = await _probeLatestFullSmokeReport(outDir);
  return _ArtifactProbe(
    uiScreenshots: uiScreenshots,
    iosRuns: iosRuns,
    androidRuns: androidRuns,
    androidPreflightReports: androidPreflightReports,
    markdownReports: markdownReports,
    jsonReports: jsonReports,
    fullSmokeReports: fullSmokeReports,
    latestIos: latestIos,
    latestAndroid: latestAndroid,
    latestAndroidPreflight: latestAndroidPreflight,
    latestFullSmoke: latestFullSmoke,
  );
}

// 统计目录下匹配文件数量；不存在时视为 0。
Future<int> _countMatchingFiles(Directory dir, RegExp pattern) async {
  if (!await dir.exists()) return 0;
  var count = 0;
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is File && pattern.hasMatch(entity.uri.pathSegments.last)) {
      count += 1;
    }
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

// 读取最近一次 smoke 运行摘要，只读取结构化元数据和事件类型。
Future<_SmokeRunSummary?> _probeLatestSmokeRun(Directory dir) async {
  if (!await dir.exists()) return null;
  final runs = <Directory>[];
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is Directory && entity.path.split('/').last.startsWith('run-')) {
      runs.add(entity);
    }
  }
  if (runs.isEmpty) return null;
  runs.sort((left, right) => right.path.compareTo(left.path));
  return _readSmokeRunSummary(runs.first);
}

// 读取最近一次 full smoke JSON，只读取结构化摘要。
Future<_FullSmokeReportSummary?> _probeLatestFullSmokeReport(
  Directory dir,
) async {
  if (!await dir.exists()) return null;
  final reports = <File>[];
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (RegExp(r'^FULL_SMOKE_.*\.json$').hasMatch(name)) {
      reports.add(entity);
    }
  }
  if (reports.isEmpty) return null;
  reports.sort((left, right) {
    return right.uri.pathSegments.last.compareTo(left.uri.pathSegments.last);
  });
  final file = reports.first;
  final decoded = await _readJsonObject(file);
  if (decoded == null || decoded['kind'] != 'v4FullSmoke') return null;
  return _FullSmokeReportSummary.fromJson(
    reportName: _redactText(file.uri.pathSegments.last),
    json: decoded,
  );
}

// 读取最近一次 Android smoke 前置诊断，不把诊断计作真实 smoke run。
Future<_AndroidSmokePreflightSummary?> _probeLatestAndroidPreflightReport(
  Directory dir,
) async {
  if (!await dir.exists()) return null;
  final reports = <File>[];
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (RegExp(r'^ANDROID_SMOKE_PREFLIGHT_.*\.json$').hasMatch(name)) {
      reports.add(entity);
    }
  }
  if (reports.isEmpty) return null;
  reports.sort((left, right) {
    return right.uri.pathSegments.last.compareTo(left.uri.pathSegments.last);
  });
  final file = reports.first;
  final decoded = await _readJsonObject(file);
  if (decoded == null || decoded['kind'] != 'v4AndroidSmokePreflight') {
    return null;
  }
  return _AndroidSmokePreflightSummary.fromJson(
    reportName: _redactText(file.uri.pathSegments.last),
    json: decoded,
  );
}

// 从单个运行目录解析状态、动作、流程、截图和失败摘要。
Future<_SmokeRunSummary> _readSmokeRunSummary(Directory dir) async {
  final metadata = await _readJsonObject(File('${dir.path}/metadata.json'));
  final finished = await _readJsonObject(File('${dir.path}/finished.json'));
  final events = await _readEventObjects(File('${dir.path}/events.jsonl'));
  final eventTypes = events
      .map((event) => event['type']?.toString() ?? '')
      .where((type) => type.isNotEmpty)
      .toSet();
  final actionNames = _smokeActionNames(events);
  final failure = events
      .where((event) => event['type'] == 'smokeFailure')
      .map((event) => event['message']?.toString() ?? '')
      .where((message) => message.trim().isNotEmpty)
      .lastOrNull;
  return _SmokeRunSummary(
    runName: _redactText(dir.path.split('/').last),
    workflowName: _redactText(
      metadata?['workflowName']?.toString() ?? 'V4 Smoke',
    ),
    status: finished?['status']?.toString() ?? 'running',
    startedAt: _parseDate(metadata?['startedAt']),
    finishedAt: _parseDate(finished?['finishedAt']),
    actionsAllowed: _eventBool(events, 'smokeStart', 'actionsAllowed'),
    hasScreenshot: eventTypes.contains('smokeScreenshot'),
    actionsExecuted: actionNames.isNotEmpty,
    actionNames: actionNames,
    workflowExecuted: eventTypes.contains('smokeWorkflowStart'),
    logsCollected: eventTypes.contains('smokeLogs'),
    failureSummary: failure == null ? null : _shortText(_redactText(failure)),
  );
}

// 从 smoke 事件里提取已执行的关键动作，用于判断是否完整冒烟。
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

// 只归一化 V4 基础冒烟必须覆盖的真实交互动作。
void _addSmokeAction(Set<String> actions, Object? raw) {
  final normalized = _normalizeSmokeAction(raw);
  if (normalized != null) actions.add(normalized);
}

// 将 Appium / workflow 事件中的动作名归一成稳定集合。
String? _normalizeSmokeAction(Object? raw) {
  final value = raw?.toString().trim().toLowerCase();
  return switch (value) {
    'tap' || 'click' || 'press' => 'tap',
    'swipe' || 'drag' => 'swipe',
    'input' || 'text' || 'sendkeys' || 'send_keys' => 'input',
    _ => null,
  };
}

// 读取 JSON object，失败时返回 null。
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

// 读取 JSONL 事件，坏行直接跳过，避免单条损坏影响 readiness。
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

// 从指定事件读取布尔字段。
bool? _eventBool(List<Map<String, Object?>> events, String type, String field) {
  for (final event in events) {
    if (event['type'] != type) continue;
    final value = event[field];
    if (value is bool) return value;
  }
  return null;
}

// 解析 ISO 时间，失败时返回 null。
DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

// 裁剪短摘要，避免报告泄露长 payload 或堆栈。
String _shortText(String value, {int limit = 120}) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= limit) return compact;
  return '${compact.substring(0, limit)}...';
}

// 读取嵌套 Map 字段，类型不对时返回空 Map。
Map<String, Object?> _jsonMapAt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  if (value is Map) return Map<String, Object?>.from(value);
  return const <String, Object?>{};
}

// 读取 JSON 字符串列表，坏值直接过滤。
List<String> _jsonStringList(Object? value) {
  if (value is! Iterable) return const <String>[];
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .map(_redactText)
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
    required this.requireComplete,
    required this.help,
  });

  final Directory outDir;
  final String host;
  final int appiumPort;
  final int tunnelPort;
  final Duration timeout;
  final bool requireComplete;
  final bool help;

  // 解析命令行参数。
  static _SmokeReadinessOptions parse(List<String> args) {
    var outDir = Directory('recordings/v4-smoke');
    var host = '127.0.0.1';
    var appiumPort = 4723;
    var tunnelPort = 42314;
    var timeoutSeconds = 4;
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
        case '--require-complete':
          requireComplete = true;
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
      requireComplete: requireComplete,
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

  // 转成机器可读状态，不暴露本机 endpoint。
  Map<String, Object?> toJsonObject({required String detail}) {
    return <String, Object?>{
      'reachable': reachable,
      'status': statusLabel,
      'detail': detail,
      'ready': ready,
      'count': count,
    };
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

  // 转成机器可读状态，不写设备标识。
  Map<String, Object?> toJsonObject({required String detail}) {
    return <String, Object?>{
      'available': available,
      'status': available ? '可用' : '未就绪',
      'detail': detail,
      'connected': connected,
      'unavailable': unavailable,
    };
  }
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

  // 转成机器可读状态，不写 Android serial。
  Map<String, Object?> toJsonObject({required String detail}) {
    return <String, Object?>{
      'available': available,
      'status': available ? '可用' : '未就绪',
      'detail': detail,
      'ready': ready,
      'unauthorized': unauthorized,
      'offline': offline,
    };
  }
}

// 本地 smoke 产物统计。
final class _ArtifactProbe {
  const _ArtifactProbe({
    required this.uiScreenshots,
    required this.iosRuns,
    required this.androidRuns,
    required this.androidPreflightReports,
    required this.markdownReports,
    required this.jsonReports,
    required this.fullSmokeReports,
    this.latestIos,
    this.latestAndroid,
    this.latestAndroidPreflight,
    this.latestFullSmoke,
  });

  final int uiScreenshots;
  final int iosRuns;
  final int androidRuns;
  final int androidPreflightReports;
  final int markdownReports;
  final int jsonReports;
  final int fullSmokeReports;
  final _SmokeRunSummary? latestIos;
  final _SmokeRunSummary? latestAndroid;
  final _AndroidSmokePreflightSummary? latestAndroidPreflight;
  final _FullSmokeReportSummary? latestFullSmoke;

  // 转成机器可读且脱敏的证据计数。
  Map<String, Object?> toJsonObject({
    int markdownReportIncrement = 0,
    int jsonReportIncrement = 0,
  }) {
    return <String, Object?>{
      'uiScreenshots': uiScreenshots,
      'iosRuns': iosRuns,
      'androidRuns': androidRuns,
      'androidPreflightReports': androidPreflightReports,
      'markdownReports': markdownReports + markdownReportIncrement,
      'jsonReports': jsonReports + jsonReportIncrement,
      'fullSmokeReports': fullSmokeReports,
      'latestIos': latestIos?.toJsonObject(),
      'latestAndroid': latestAndroid?.toJsonObject(),
      'latestAndroidPreflight': latestAndroidPreflight?.toJsonObject(),
      'latestFullSmoke': latestFullSmoke?.toJsonObject(),
    };
  }
}

// 最近一次 Android smoke 前置诊断摘要。
final class _AndroidSmokePreflightSummary {
  const _AndroidSmokePreflightSummary({
    required this.reportName,
    required this.timestamp,
    required this.ready,
    required this.label,
    required this.blockers,
    required this.nextSteps,
  });

  final String reportName;
  final DateTime? timestamp;
  final bool ready;
  final String label;
  final List<String> blockers;
  final List<String> nextSteps;

  // 从 Android smoke preflight JSON 解析最小摘要，坏字段按未知降级。
  factory _AndroidSmokePreflightSummary.fromJson({
    required String reportName,
    required Map<String, Object?> json,
  }) {
    final completion = _jsonMapAt(json, 'completion');
    return _AndroidSmokePreflightSummary(
      reportName: reportName,
      timestamp: _parseDate(json['timestamp']),
      ready: completion['ready'] == true,
      label: _redactText(completion['label']?.toString() ?? '未知'),
      blockers: _jsonStringList(completion['blockers']),
      nextSteps: _jsonStringList(json['nextSteps']),
    );
  }

  String get summaryLabel {
    final parts = <String>[
      ready ? '可运行' : label,
      if (blockers.isNotEmpty) '阻断 ${blockers.join('/')}',
      if (nextSteps.isNotEmpty) '下一步 ${nextSteps.first}',
    ];
    if (timestamp case final value?) {
      parts.add('时间 ${value.toUtc().toIso8601String()}');
    }
    return parts.join('，');
  }

  // 转成机器可读摘要，不包含报告路径。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'reportName': reportName,
      'timestamp': timestamp?.toUtc().toIso8601String(),
      'ready': ready,
      'label': label,
      'blockers': blockers,
      'nextSteps': nextSteps,
      'summary': summaryLabel,
    };
  }
}

// 最近一次 full smoke 编排报告的脱敏摘要。
final class _FullSmokeReportSummary {
  const _FullSmokeReportSummary({
    required this.reportName,
    required this.timestamp,
    required this.complete,
    required this.label,
    required this.preflightStatus,
    required this.blockers,
    required this.failedSteps,
    required this.stepCount,
    required this.stepStatuses,
  });

  final String reportName;
  final DateTime? timestamp;
  final bool complete;
  final String label;
  final String preflightStatus;
  final List<String> blockers;
  final List<String> failedSteps;
  final int stepCount;
  final List<String> stepStatuses;

  // 从 full smoke JSON 解析摘要，坏字段按未知降级。
  factory _FullSmokeReportSummary.fromJson({
    required String reportName,
    required Map<String, Object?> json,
  }) {
    final completion = _jsonMapAt(json, 'completion');
    final preparation = _jsonMapAt(json, 'preparation');
    final preflight = _jsonMapAt(json, 'preflight');
    final steps = json['steps'] is Iterable
        ? json['steps'] as Iterable
        : const [];
    final stepStatuses = <String>[];
    for (final step in steps) {
      if (step is! Map) continue;
      final stepMap = Map<String, Object?>.from(step);
      final stepName =
          _jsonMapAt(stepMap, 'step')['name']?.toString() ?? '未知步骤';
      final status = stepMap['status']?.toString() ?? '未知';
      stepStatuses.add('${_redactText(stepName)}：${_redactText(status)}');
    }
    return _FullSmokeReportSummary(
      reportName: reportName,
      timestamp: _parseDate(json['timestamp']),
      complete: completion['complete'] == true,
      label: _redactText(completion['label']?.toString() ?? '未知'),
      preflightStatus: _redactText(preflight['status']?.toString() ?? '未知'),
      blockers: _combinedBlockers(preparation, preflight),
      failedSteps: _jsonStringList(completion['failedSteps']),
      stepCount: stepStatuses.length,
      stepStatuses: stepStatuses,
    );
  }

  String get summaryLabel {
    final parts = <String>[
      complete ? '完整通过' : label,
      '前置 $preflightStatus',
      if (blockers.isNotEmpty) '阻断 ${blockers.join('/')}',
      if (failedSteps.isNotEmpty) '失败 ${failedSteps.join('/')}',
      '步骤 $stepCount',
    ];
    if (timestamp case final value?) {
      parts.add('时间 ${value.toUtc().toIso8601String()}');
    }
    return parts.join('，');
  }

  // 转成机器可读摘要，不包含报告文件路径。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'reportName': reportName,
      'timestamp': timestamp?.toUtc().toIso8601String(),
      'complete': complete,
      'label': label,
      'preflightStatus': preflightStatus,
      'blockers': blockers,
      'failedSteps': failedSteps,
      'stepCount': stepCount,
      'stepStatuses': stepStatuses,
      'summary': summaryLabel,
    };
  }
}

// 最近一次平台 smoke 的脱敏摘要。
final class _SmokeRunSummary {
  const _SmokeRunSummary({
    required this.runName,
    required this.workflowName,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.actionsAllowed,
    required this.hasScreenshot,
    required this.actionsExecuted,
    required this.actionNames,
    required this.workflowExecuted,
    required this.logsCollected,
    required this.failureSummary,
  });

  final String runName;
  final String workflowName;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final bool? actionsAllowed;
  final bool hasScreenshot;
  final bool actionsExecuted;
  final Set<String> actionNames;
  final bool workflowExecuted;
  final bool logsCollected;
  final String? failureSummary;

  bool get passed => status == 'success';

  bool get tapExecuted => actionNames.contains('tap');

  bool get swipeExecuted => actionNames.contains('swipe');

  bool get inputExecuted => actionNames.contains('input');

  bool get fullPassed =>
      passed &&
      actionsAllowed == true &&
      hasScreenshot &&
      workflowExecuted &&
      tapExecuted &&
      swipeExecuted &&
      inputExecuted;

  String get actionSummary {
    if (!actionsExecuted) return '未执行动作';
    final ordered = [
      if (tapExecuted) 'tap',
      if (swipeExecuted) 'swipe',
      if (inputExecuted) 'input',
    ];
    return ordered.isEmpty ? '动作未知' : '动作 ${ordered.join('/')}';
  }

  String get summaryLabel {
    final parts = <String>[
      passed
          ? fullPassed
                ? '完整通过'
                : '通过但未完整'
          : status == 'failed'
          ? '失败'
          : '运行中',
      actionsAllowed == true ? '允许动作' : '动作未授权',
      actionSummary,
      workflowExecuted ? '含流程' : '无流程',
      hasScreenshot ? '有截图' : '无截图',
      logsCollected ? '有日志' : '无日志',
    ];
    if (finishedAt case final finished?) {
      parts.add('完成 ${finished.toUtc().toIso8601String()}');
    } else if (startedAt case final started?) {
      parts.add('开始 ${started.toUtc().toIso8601String()}');
    }
    if (failureSummary case final failure?) {
      parts.add('失败：$failure');
    }
    return parts.join('，');
  }

  // 转成机器可读摘要，不包含运行目录路径。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'runName': runName,
      'workflowName': workflowName,
      'status': status,
      'startedAt': startedAt?.toUtc().toIso8601String(),
      'finishedAt': finishedAt?.toUtc().toIso8601String(),
      'actionsAllowed': actionsAllowed,
      'hasScreenshot': hasScreenshot,
      'actionsExecuted': actionsExecuted,
      'actions': actionNames.toList()..sort(),
      'workflowExecuted': workflowExecuted,
      'logsCollected': logsCollected,
      'fullPassed': fullPassed,
      'summary': summaryLabel,
      'failureSummary': failureSummary,
    };
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

  bool get _latestIosFullPassed => artifacts.latestIos?.fullPassed ?? false;

  bool get _latestAndroidFullPassed =>
      artifacts.latestAndroid?.fullPassed ?? false;

  bool get isComplete => _latestIosFullPassed && _latestAndroidFullPassed;

  List<_BatchAcceptanceRow> get _batchRows => _batchAcceptanceRows(
    iosReady: iosFullSmokeReady,
    androidReady: androidFullSmokeReady,
    latestIos: artifacts.latestIos,
    latestAndroid: artifacts.latestAndroid,
    latestFullSmoke: artifacts.latestFullSmoke,
  );

  // 转成机器可读 JSON 字符串，供后续 AI / CI 审计使用。
  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJsonObject())}\n';
  }

  // 转成脱敏 JSON 对象，不包含本机路径、完整设备号或 endpoint。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'v4SmokeReadiness',
      'timestamp': timestamp.toIso8601String(),
      'git': git,
      'completion': <String, Object?>{
        'complete': isComplete,
        'label': _completionLabel(),
        'iosFullSmokeReady': iosFullSmokeReady,
        'androidFullSmokeReady': androidFullSmokeReady,
        'latestIosFullPassed': _latestIosFullPassed,
        'latestAndroidFullPassed': _latestAndroidFullPassed,
      },
      'localState': <String, Object?>{
        'appium': appium.toJsonObject(detail: _appiumDetail()),
        'iosTunnel': tunnel.toJsonObject(detail: _tunnelDetail()),
        'iosDevice': ios.toJsonObject(detail: _iosDetail()),
        'androidDevice': android.toJsonObject(detail: _androidDetail()),
      },
      'batches': _batchRows.map((row) => row.toJsonObject()).toList(),
      'artifacts': artifacts.toJsonObject(
        markdownReportIncrement: 1,
        jsonReportIncrement: 1,
      ),
      'nextSteps': _nextSteps(),
    };
  }

  // 转成可留档的脱敏 Markdown。
  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# V4 Smoke Readiness')
      ..writeln()
      ..writeln('- 时间：${timestamp.toIso8601String()}')
      ..writeln('- 提交：$git')
      ..writeln('- 完成判定：${_completionLabel()}')
      ..writeln('- iOS 完整冒烟：${iosFullSmokeReady ? '可运行' : '未就绪'}')
      ..writeln('- Android 完整冒烟：${androidFullSmokeReady ? '可运行' : '未就绪'}')
      ..writeln('- iOS 最近 smoke：${_latestSmokeLabel(artifacts.latestIos)}')
      ..writeln(
        '- Android 最近 smoke：${_latestSmokeLabel(artifacts.latestAndroid)}',
      )
      ..writeln(
        '- 最近 full smoke：${_latestFullSmokeLabel(artifacts.latestFullSmoke)}',
      )
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
      ..writeln('## 批次验收索引')
      ..writeln()
      ..writeln('来源：`docs/V4.0-Development-Roadmap.md`。')
      ..writeln()
      ..writeln('| 批次 | 当前判定 | 主要证据 |')
      ..writeln('|---|---|---|');
    for (final row in _batchRows) {
      buffer.writeln('| ${row.name} | ${row.status} | ${row.evidence} |');
    }
    buffer
      ..writeln()
      ..writeln('## 本地证据')
      ..writeln()
      ..writeln('- UI 截图：${artifacts.uiScreenshots}')
      ..writeln('- iOS smoke 记录：${artifacts.iosRuns}')
      ..writeln('  - 最近：${_latestSmokeDetail(artifacts.latestIos)}')
      ..writeln('- Android smoke 记录：${artifacts.androidRuns}')
      ..writeln('  - 最近：${_latestSmokeDetail(artifacts.latestAndroid)}')
      ..writeln('- Android 前置诊断：${artifacts.androidPreflightReports}')
      ..writeln(
        '  - 最近：${_latestAndroidPreflightDetail(artifacts.latestAndroidPreflight)}',
      )
      ..writeln('- Full smoke 报告：${artifacts.fullSmokeReports}')
      ..writeln('  - 最近：${_latestFullSmokeDetail(artifacts.latestFullSmoke)}')
      ..writeln('- Markdown 报告：${artifacts.markdownReports + 1}')
      ..writeln('- JSON 摘要：${artifacts.jsonReports + 1}')
      ..writeln()
      ..writeln('## 下一步')
      ..writeln();

    for (final step in _nextSteps()) {
      buffer.writeln('- $step');
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

  String _completionLabel() {
    if (isComplete) {
      return '最近双平台完整 smoke 已成功留档';
    }
    if (iosFullSmokeReady && androidFullSmokeReady) {
      return '待执行完整 smoke';
    }
    return '未完成，等待现场 smoke 条件';
  }

  String _latestSmokeLabel(_SmokeRunSummary? summary) {
    if (summary == null) return '无记录';
    return summary.fullPassed
        ? '完整通过'
        : summary.passed
        ? '通过但未完整'
        : summary.status == 'failed'
        ? '失败'
        : '运行中';
  }

  String _latestSmokeDetail(_SmokeRunSummary? summary) {
    if (summary == null) return '无记录';
    return '${summary.workflowName} / ${summary.summaryLabel}';
  }

  String _latestAndroidPreflightDetail(_AndroidSmokePreflightSummary? summary) {
    if (summary == null) return '无记录';
    return summary.summaryLabel;
  }

  String _latestFullSmokeLabel(_FullSmokeReportSummary? summary) {
    if (summary == null) return '无记录';
    return summary.complete ? '完整通过' : summary.label;
  }

  String _latestFullSmokeDetail(_FullSmokeReportSummary? summary) {
    if (summary == null) return '无记录';
    return summary.summaryLabel;
  }

  List<String> _nextSteps() {
    if (iosFullSmokeReady && androidFullSmokeReady) {
      return const <String>[
        '可继续运行 `npm run v4:ios-smoke` 和 `npm run v4:android-smoke`。',
      ];
    }
    return <String>[
      if (!iosFullSmokeReady) 'iOS：先打开 Mac App 点“连接设备”，输入 Mac 密码，并在手机点允许。',
      if (!androidFullSmokeReady)
        'Android：连接一台已开启 USB 调试的手机，再运行 Android smoke。',
    ];
  }
}

// 生成 Batch 0-8 的验收索引。
// 表格只引用自动证据和现场条件，不替代 Roadmap 真源。
List<_BatchAcceptanceRow> _batchAcceptanceRows({
  required bool iosReady,
  required bool androidReady,
  required _SmokeRunSummary? latestIos,
  required _SmokeRunSummary? latestAndroid,
  required _FullSmokeReportSummary? latestFullSmoke,
}) {
  final latestFullPassed =
      (latestIos?.fullPassed ?? false) && (latestAndroid?.fullPassed ?? false);
  final smokeStatus = latestFullPassed
      ? '已完成完整 smoke 留档'
      : iosReady && androidReady
      ? '待完整 smoke'
      : '现场未就绪';
  final smokeEvidence =
      'iOS 最近 ${_batchSmokeLabel(latestIos)}，Android 最近 ${_batchSmokeLabel(latestAndroid)}，full smoke 最近 ${_batchFullSmokeLabel(latestFullSmoke)}，当前现场状态见上表';
  return <_BatchAcceptanceRow>[
    const _BatchAcceptanceRow(
      name: 'Batch 0 真源治理',
      status: '已落地',
      evidence: 'V4 文档、ADR、THIRD_PARTY_NOTICES、边界检查',
    ),
    const _BatchAcceptanceRow(
      name: 'Batch 1 Runtime 基座',
      status: '已落地',
      evidence: 'V4 边界检查、Runtime contracts、fake driver tests',
    ),
    _BatchAcceptanceRow(
      name: 'Batch 2 双平台 smoke',
      status: smokeStatus,
      evidence: smokeEvidence,
    ),
    const _BatchAcceptanceRow(
      name: 'Batch 3 Inspector',
      status: '已落地',
      evidence: 'Runtime Inspector tests、Device Inspector widget tests',
    ),
    const _BatchAcceptanceRow(
      name: 'Batch 4 Target / Recorder',
      status: '已落地',
      evidence: 'Target library、targetRef、Recorder promote tests',
    ),
    const _BatchAcceptanceRow(
      name: 'Batch 5 Vision Core',
      status: '已落地',
      evidence: 'Vision provider、低置信暂停、fixture / Python sidecar tests',
    ),
    const _BatchAcceptanceRow(
      name: 'Batch 6 Workflow Canvas',
      status: '已落地',
      evidence: 'Canvas / Source / Validate / Inspector widget tests',
    ),
    const _BatchAcceptanceRow(
      name: 'Batch 7 Evidence / Report',
      status: '已落地',
      evidence: 'RunLocalReport、导出脱敏、Monitor detail tests',
    ),
    const _BatchAcceptanceRow(
      name: 'Batch 8 AI / MCP Core',
      status: '已落地',
      evidence: 'AI permission gate、draft-only、audit log runtime tests',
    ),
  ];
}

// 批次表里使用的最近 smoke 短状态。
String _batchSmokeLabel(_SmokeRunSummary? summary) {
  if (summary == null) return '无记录';
  if (summary.fullPassed) return '完整通过';
  if (summary.passed) return '通过但未完整';
  if (summary.status == 'failed') return '失败';
  return '运行中';
}

// 批次表里使用的最近 full smoke 短状态。
String _batchFullSmokeLabel(_FullSmokeReportSummary? summary) {
  if (summary == null) return '无记录';
  if (summary.complete) return '完整通过';
  if (summary.blockers.isNotEmpty) return '阻断 ${summary.blockers.join('/')}';
  if (summary.failedSteps.isNotEmpty)
    return '失败 ${summary.failedSteps.join('/')}';
  return summary.label;
}

// 批次验收索引行。
final class _BatchAcceptanceRow {
  const _BatchAcceptanceRow({
    required this.name,
    required this.status,
    required this.evidence,
  });

  final String name;
  final String status;
  final String evidence;

  // 转成机器可读验收索引行。
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'name': name,
      'status': status,
      'evidence': evidence,
    };
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
  --require-complete     最近双平台完整 smoke 未成功留档时返回非 0
  --help                 查看帮助
''';
