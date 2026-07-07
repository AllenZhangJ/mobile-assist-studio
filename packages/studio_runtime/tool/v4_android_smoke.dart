import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';

// V4 Android 真机冒烟入口。
// 默认只做发现、会话、截图和日志；显式传 --allow-actions 才执行点按和输入。
Future<void> main(List<String> args) async {
  final options = _AndroidSmokeOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  final client = AppiumClient(
    config: AppiumServerConfig(
      host: options.host,
      port: options.port,
      timeout: options.timeout,
    ),
  );
  final adb = AdbAndroidDeviceDiscovery(timeout: options.timeout);

  try {
    await options.outDir.create(recursive: true);
    final preflight = await _runPreflight(
      client: client,
      adb: adb,
      options: options,
    );
    if (!preflight.ready) {
      final files = await preflight.write(options.outDir);
      stdout
        ..writeln('诊断：${_redactText(files.markdownFile.path)}')
        ..writeln('摘要：${_redactText(files.jsonFile.path)}');
      _fail(preflight.failureLine);
    }

    final discovery = preflight.discovery!;
    final device = preflight.device!;
    stdout.writeln('设备：${device.displayName} ${device.maskedSerial}');

    final driver = AndroidAppiumMobileDriver(
      discovery: _CachedAndroidDiscovery(discovery, adb),
      client: client,
    );
    final evidenceStore = LocalRunEvidenceStore(rootDirectory: options.outDir);
    final report =
        await MobileDriverSmokeRunner(
          driver: driver,
          evidenceStore: evidenceStore,
        ).run(
          MobileDriverSmokePlan(
            workflowName: 'V4 Android Smoke',
            allowActions: options.allowActions,
            inputText: options.inputText,
            useBasicWorkflow: options.useBasicWorkflow,
          ),
        );

    if (!report.actionsExecuted) {
      stdout.writeln('动作：已跳过。需要真实点按时加 --allow-actions。');
    }
    stdout.writeln('会话：${report.platform.name}');
    stdout.writeln('截图：${report.screenshotRef ?? '未保存'}');
    stdout.writeln('日志：${report.logs.length} 行');
    stdout.writeln('结果：${options.outDir.path}/${report.runId}');
  } on Object catch (error) {
    _fail('Android 冒烟失败：$error');
  } finally {
    client.close(force: true);
  }
}

// 执行 Android smoke 前置检查，同时收集 Appium 与 ADB 状态。
Future<_AndroidSmokePreflight> _runPreflight({
  required AppiumClient client,
  required AdbAndroidDeviceDiscovery adb,
  required _AndroidSmokeOptions options,
}) async {
  final appium = await _checkAppium(client);
  final android = await _checkAndroid(adb);
  return _AndroidSmokePreflight(
    timestamp: DateTime.now().toUtc(),
    appium: appium,
    android: android,
    allowActions: options.allowActions,
    useBasicWorkflow: options.useBasicWorkflow,
    discovery: android.discovery,
    device: android.device,
  );
}

// 检查 Appium /status，失败时只返回用户可处理的短诊断。
Future<_AndroidSmokeCheck> _checkAppium(AppiumClient client) async {
  try {
    final status = await client.status();
    if (status.ready) {
      return const _AndroidSmokeCheck(
        name: '驱动',
        ok: true,
        detail: '已就绪',
        nextStep: '-',
      );
    }
    return _AndroidSmokeCheck(
      name: '驱动',
      ok: false,
      detail: _shortText('未就绪：${status.message}'),
      nextStep: '先打开 Mac App 点“连接设备”，或运行 full smoke 自动准备驱动。',
    );
  } on AppiumClientException catch (error) {
    return _AndroidSmokeCheck(
      name: '驱动',
      ok: false,
      detail: _shortText(error.message),
      nextStep: '先打开 Mac App 点“连接设备”，或运行 full smoke 自动准备驱动。',
    );
  } on Object catch (error) {
    return _AndroidSmokeCheck(
      name: '驱动',
      ok: false,
      detail: _shortText(error.toString()),
      nextStep: '确认本机 Appium 可用后重试。',
    );
  }
}

// 检查 ADB 可见的唯一 Android 手机，并保留可复用发现结果。
Future<_AndroidSmokeDeviceCheck> _checkAndroid(
  AdbAndroidDeviceDiscovery adb,
) async {
  try {
    final discovery = await adb.discover();
    final device = discovery.requireSingleReadyDevice();
    return _AndroidSmokeDeviceCheck(
      name: '安卓手机',
      ok: true,
      detail: '${device.displayName} ${device.maskedSerial}',
      nextStep: '-',
      ready: _androidStateCount(discovery, AndroidAdbDeviceState.ready),
      unauthorized: _androidStateCount(
        discovery,
        AndroidAdbDeviceState.unauthorized,
      ),
      offline: _androidStateCount(discovery, AndroidAdbDeviceState.offline),
      discovery: discovery,
      device: device,
    );
  } on AndroidDeviceDiscoveryException catch (error) {
    return _AndroidSmokeDeviceCheck(
      name: '安卓手机',
      ok: false,
      detail: _shortText(error.toString()),
      nextStep: error.nextStep,
    );
  } on Object catch (error) {
    return _AndroidSmokeDeviceCheck(
      name: '安卓手机',
      ok: false,
      detail: _shortText(error.toString()),
      nextStep: '确认 ADB 可用，并连接一台已开启 USB 调试的手机。',
    );
  }
}

// 统计一次 ADB 发现中的指定状态数量。
int _androidStateCount(
  AndroidAdbDiscovery discovery,
  AndroidAdbDeviceState state,
) {
  return discovery.devices.where((device) => device.state == state).length;
}

// Android smoke 参数。
final class _AndroidSmokeOptions {
  const _AndroidSmokeOptions({
    required this.host,
    required this.port,
    required this.timeout,
    required this.outDir,
    required this.allowActions,
    required this.useBasicWorkflow,
    required this.inputText,
    required this.help,
  });

  final String host;
  final int port;
  final Duration timeout;
  final Directory outDir;
  final bool allowActions;
  final bool useBasicWorkflow;
  final String inputText;
  final bool help;

  // 从命令行参数解析 smoke 配置。
  static _AndroidSmokeOptions parse(List<String> args) {
    var host = '127.0.0.1';
    var port = 4723;
    var timeoutSeconds = 8;
    var outDir = Directory('../../recordings/v4-smoke/android');
    var allowActions = false;
    var useBasicWorkflow = false;
    var inputText = 'ios-assist-smoke';
    var help = false;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--help':
        case '-h':
          help = true;
        case '--host':
          host = _nextValue(args, index, arg);
          index += 1;
        case '--port':
          port = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--timeout':
          timeoutSeconds = int.parse(_nextValue(args, index, arg));
          index += 1;
        case '--out-dir':
          outDir = Directory(_nextValue(args, index, arg));
          index += 1;
        case '--allow-actions':
          allowActions = true;
        case '--workflow-basic':
          useBasicWorkflow = true;
        case '--input-text':
          inputText = _nextValue(args, index, arg);
          index += 1;
        default:
          throw ArgumentError('未知参数：$arg');
      }
    }

    return _AndroidSmokeOptions(
      host: host,
      port: port,
      timeout: Duration(seconds: timeoutSeconds),
      outDir: outDir,
      allowActions: allowActions,
      useBasicWorkflow: useBasicWorkflow,
      inputText: inputText,
      help: help,
    );
  }
}

// 缓存发现结果，避免 driver connect 时设备列表发生短暂抖动。
final class _CachedAndroidDiscovery implements AndroidDeviceDiscovery {
  const _CachedAndroidDiscovery(this.discovery, this.delegate);

  final AndroidAdbDiscovery discovery;
  final AndroidDeviceDiscovery delegate;

  @override
  Future<List<String>> collectLogcat({
    required String serial,
    int maxLines = 120,
  }) {
    return delegate.collectLogcat(serial: serial, maxLines: maxLines);
  }

  @override
  Future<AndroidAdbDiscovery> discover() async {
    return discovery;
  }
}

// Android smoke 前置检查报告。
final class _AndroidSmokePreflight {
  const _AndroidSmokePreflight({
    required this.timestamp,
    required this.appium,
    required this.android,
    required this.allowActions,
    required this.useBasicWorkflow,
    required this.discovery,
    required this.device,
  });

  final DateTime timestamp;
  final _AndroidSmokeCheck appium;
  final _AndroidSmokeDeviceCheck android;
  final bool allowActions;
  final bool useBasicWorkflow;
  final AndroidAdbDiscovery? discovery;
  final AndroidAdbDevice? device;

  bool get ready =>
      appium.ok && android.ok && discovery != null && device != null;

  String get label => ready ? '可运行' : '有阻断';

  String get failureLine {
    final blockers = checks
        .where((check) => !check.ok)
        .map((check) => check.name)
        .join('、');
    final nextSteps = this.nextSteps.join(' ');
    return 'Android 冒烟前置检查未通过：$blockers。$nextSteps';
  }

  List<_AndroidSmokeCheck> get checks => <_AndroidSmokeCheck>[appium, android];

  List<String> get nextSteps {
    final steps = checks
        .where((check) => !check.ok && check.nextStep != '-')
        .map((check) => check.nextStep)
        .toSet()
        .toList(growable: false);
    if (steps.isEmpty) return const <String>['继续运行 Android smoke。'];
    return steps;
  }

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'schemaVersion': 1,
      'kind': 'v4AndroidSmokePreflight',
      'timestamp': timestamp.toIso8601String(),
      'completion': <String, Object?>{
        'ready': ready,
        'label': label,
        'blockers': checks
            .where((check) => !check.ok)
            .map((check) => check.name)
            .toList(growable: false),
      },
      'request': <String, Object?>{
        'allowActions': allowActions,
        'workflowBasic': useBasicWorkflow,
      },
      'checks': checks.map((check) => check.toJsonObject()).toList(),
      'nextSteps': nextSteps,
    };
  }

  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return '${encoder.convert(toJsonObject())}\n';
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# V4 Android Smoke Preflight')
      ..writeln()
      ..writeln('- 时间：${timestamp.toIso8601String()}')
      ..writeln('- 结果：$label')
      ..writeln('- 动作：${allowActions ? '允许' : '未允许'}')
      ..writeln('- 流程：${useBasicWorkflow ? '基础流程' : '仅会话截图'}')
      ..writeln()
      ..writeln('## 检查')
      ..writeln()
      ..writeln('| 项目 | 状态 | 说明 | 下一步 |')
      ..writeln('|---|---|---|---|');
    for (final check in checks) {
      buffer.writeln(
        '| ${check.name} | ${check.ok ? '通过' : '阻断'} | ${check.detail} | ${check.nextStep} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## 下一步')
      ..writeln();
    for (final step in nextSteps) {
      buffer.writeln('- $step');
    }
    return buffer.toString();
  }

  Future<_AndroidSmokePreflightFiles> write(Directory outDir) async {
    await outDir.create(recursive: true);
    final base =
        '${outDir.path}/ANDROID_SMOKE_PREFLIGHT_${_safeTimestamp(timestamp)}';
    final markdownFile = File('$base.md');
    final jsonFile = File('$base.json');
    await markdownFile.writeAsString(toMarkdown(), flush: true);
    await jsonFile.writeAsString(toJsonString(), flush: true);
    return _AndroidSmokePreflightFiles(
      markdownFile: markdownFile,
      jsonFile: jsonFile,
    );
  }
}

// Android smoke 前置检查生成的两个留档文件。
final class _AndroidSmokePreflightFiles {
  const _AndroidSmokePreflightFiles({
    required this.markdownFile,
    required this.jsonFile,
  });

  final File markdownFile;
  final File jsonFile;
}

// 单项 Android smoke 前置检查结果。
class _AndroidSmokeCheck {
  const _AndroidSmokeCheck({
    required this.name,
    required this.ok,
    required this.detail,
    required this.nextStep,
  });

  final String name;
  final bool ok;
  final String detail;
  final String nextStep;

  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      'name': name,
      'ok': ok,
      'status': ok ? '通过' : '阻断',
      'detail': detail,
      'nextStep': nextStep,
    };
  }
}

// Android 手机检查结果，额外记录脱敏后的 ADB 状态计数。
final class _AndroidSmokeDeviceCheck extends _AndroidSmokeCheck {
  const _AndroidSmokeDeviceCheck({
    required super.name,
    required super.ok,
    required super.detail,
    required super.nextStep,
    this.ready = 0,
    this.unauthorized = 0,
    this.offline = 0,
    this.discovery,
    this.device,
  });

  final int ready;
  final int unauthorized;
  final int offline;
  final AndroidAdbDiscovery? discovery;
  final AndroidAdbDevice? device;

  @override
  Map<String, Object?> toJsonObject() {
    return <String, Object?>{
      ...super.toJsonObject(),
      'ready': ready,
      'unauthorized': unauthorized,
      'offline': offline,
    };
  }
}

// 读取需要跟随参数名的下一个值。
String _nextValue(List<String> args, int index, String name) {
  if (index + 1 >= args.length) {
    throw ArgumentError('$name 缺少参数值。');
  }
  return args[index + 1];
}

// 生成适合文件名的 UTC 时间戳。
String _safeTimestamp(DateTime value) {
  return value.toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
}

// 裁剪并脱敏错误文本，避免本机路径或设备号进入留档。
String _shortText(String value, {int maxLength = 220}) {
  final text = _redactText(value).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

// 对终端和报告输出做最小脱敏。
String _redactText(String value) {
  return value
      .replaceAll(RegExp(r'/Users/[^ ]+'), '[本机路径]')
      .replaceAll(RegExp(r'/private/[^ ]+'), '[本机路径]')
      .replaceAll(RegExp(r'\b[0-9A-Fa-f]{25,}\b'), '[设备]')
      .replaceAll(
        RegExp(
          r'\b[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\b',
        ),
        '[设备]',
      );
}

// 统一失败出口，保持 smoke 脚本终端输出简短可读。
Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

const _usage = '''
V4 Android smoke

用法：
  fvm dart run tool/v4_android_smoke.dart [选项]

选项：
  --host <host>          Appium 地址，默认 127.0.0.1
  --port <port>          Appium 端口，默认 4723
  --timeout <seconds>    请求超时，默认 8
  --out-dir <path>       结果目录，默认 ../../recordings/v4-smoke/android
  --allow-actions        允许真实 Tap / Swipe / Input
  --workflow-basic       使用基础 Project DSL 流程冒烟
  --input-text <text>    动作冒烟输入文本
  --help                 查看帮助
''';
