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
    final status = await client.status();
    if (!status.ready) {
      _fail('驱动未就绪：${status.message}');
    }

    final discovery = await adb.discover();
    final device = discovery.requireSingleReadyDevice();
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
  } on AndroidDeviceDiscoveryException catch (error) {
    _fail('${error.summary} ${error.nextStep}');
  } on AppiumClientException catch (error) {
    _fail('驱动请求失败：${error.message}');
  } on Object catch (error) {
    _fail('Android 冒烟失败：$error');
  } finally {
    client.close(force: true);
  }
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

// 读取需要跟随参数名的下一个值。
String _nextValue(List<String> args, int index, String name) {
  if (index + 1 >= args.length) {
    throw ArgumentError('$name 缺少参数值。');
  }
  return args[index + 1];
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
