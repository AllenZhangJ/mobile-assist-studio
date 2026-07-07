import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';

// V4 iOS 真机冒烟入口。
// 默认只做会话、截图和日志；显式传 --allow-actions 才执行点按和输入。
Future<void> main(List<String> args) async {
  final options = _IosSmokeOptions.parse(args);
  if (options.help) {
    stdout.writeln(_usage);
    return;
  }

  AppiumClient? client;
  try {
    final config = StudioProjectConfig.discover();
    client = AppiumClient(config: config.appiumServer);
    final status = await client.status();
    if (!status.ready) {
      _fail('驱动未就绪：${status.message}');
    }

    final device = _deviceSummary(config.deviceSession);
    if (device != null) {
      stdout.writeln('设备：${device.displayName} ${device.maskedIdentifier}');
    }
    final sessionManager = DeviceSessionManager(
      client: client,
      config: config.deviceSession,
    );
    final driver = IosAppiumMobileDriver(
      sessionManager: sessionManager,
      deviceActions: AppiumDeviceActionExecutor(client),
      device: device,
      defaultTapDurationMs: config.tapDurationMs,
    );
    final evidenceStore = LocalRunEvidenceStore(rootDirectory: options.outDir);
    final report =
        await MobileDriverSmokeRunner(
          driver: driver,
          evidenceStore: evidenceStore,
        ).run(
          MobileDriverSmokePlan(
            workflowName: 'V4 iOS Smoke',
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
  } on StudioProjectConfigDiscoveryException catch (error) {
    _fail('${error.summary} ${error.nextStep}');
  } on RuntimeDeviceBindingException catch (error) {
    _fail('${error.summary} ${error.nextStep}');
  } on AppiumClientException catch (error) {
    _fail('驱动请求失败：${error.message}');
  } on Object catch (error) {
    _fail('iOS 冒烟失败：$error');
  } finally {
    client?.close(force: true);
  }
}

// 从项目会话配置构造脱敏 iOS 设备摘要。
MobileDeviceSummary? _deviceSummary(DeviceSessionConfig config) {
  final udid = config.udid;
  if (udid == null) return null;
  final capabilities = config.capabilities;
  return MobileDeviceSummary(
    platform: MobilePlatform.ios,
    displayName:
        capabilities['appium:deviceName']?.toString() ??
        capabilities['deviceName']?.toString() ??
        'iPhone',
    maskedIdentifier: _maskIdentifier(udid),
    osVersion:
        capabilities['appium:platformVersion']?.toString() ??
        capabilities['platformVersion']?.toString(),
    connectionKind: MobileConnectionKind.usb,
  );
}

// 脱敏设备标识，只保留首尾极少字符帮助用户辨认。
String _maskIdentifier(String value) {
  final trimmed = value.trim();
  if (trimmed.length <= 8) return '设备...';
  return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 4)}';
}

// iOS smoke 参数。
final class _IosSmokeOptions {
  const _IosSmokeOptions({
    required this.outDir,
    required this.allowActions,
    required this.useBasicWorkflow,
    required this.inputText,
    required this.help,
  });

  final Directory outDir;
  final bool allowActions;
  final bool useBasicWorkflow;
  final String inputText;
  final bool help;

  // 从命令行参数解析 iOS smoke 配置。
  static _IosSmokeOptions parse(List<String> args) {
    var outDir = Directory('../../recordings/v4-smoke/ios');
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

    return _IosSmokeOptions(
      outDir: outDir,
      allowActions: allowActions,
      useBasicWorkflow: useBasicWorkflow,
      inputText: inputText,
      help: help,
    );
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
V4 iOS smoke

用法：
  fvm dart run tool/v4_ios_smoke.dart [选项]

选项：
  --out-dir <path>       结果目录，默认 ../../recordings/v4-smoke/ios
  --allow-actions        允许真实 Tap / Swipe / Input
  --workflow-basic       使用基础 Project DSL 流程冒烟
  --input-text <text>    动作冒烟输入文本
  --help                 查看帮助
''';
