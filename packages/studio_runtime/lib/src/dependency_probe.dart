part of '../studio_runtime.dart';

// Appium 可用性摘要，只暴露 ready 状态和脱敏消息。
final class AppiumAvailability {
  // 创建 Appium 可用性摘要。
  const AppiumAvailability({required this.available, required this.message});

  final bool available;
  final String message;
}

// Appium 可用性检查接口，便于 Runtime 注入 fake。
abstract interface class AppiumAvailabilityChecker {
  // 检查当前 Appium /status 是否可用。
  Future<AppiumAvailability> check();
}

// 本机依赖检查接口，负责输出用户可读的本地准备度。
abstract interface class LocalDependencyChecker {
  // 检查当前 Appium 配置所需的本机依赖。
  Future<LocalDependencyReport> check({
    required AppiumProcessConfig appiumProcess,
  });
}

// 命令执行器类型，测试中用 fake 避免真实访问系统工具。
typedef CommandRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

// 默认命令执行器，只封装 Process.run。
Future<ProcessResult> defaultCommandRunner(
  String executable,
  List<String> arguments,
) {
  return Process.run(executable, arguments);
}

// 本机依赖探测入口，负责串联工具、隧道和会话准备检查。
final class LocalDependencyProbe implements LocalDependencyChecker {
  // 创建本机依赖探测器，可注入命令执行器和超时时间。
  const LocalDependencyProbe({
    CommandRunner runner = defaultCommandRunner,
    AppiumTunnelRegistryReader tunnelRegistryReader =
        defaultAppiumTunnelRegistryReader,
    this.timeout = const Duration(seconds: 4),
  }) : _runner = runner,
       _tunnelRegistryReader = tunnelRegistryReader;

  final CommandRunner _runner;
  final AppiumTunnelRegistryReader _tunnelRegistryReader;
  final Duration timeout;

  @override
  // 依次检查驱动、开发工具、设备工具、本机隧道和会话准备。
  Future<LocalDependencyReport> check({
    required AppiumProcessConfig appiumProcess,
  }) async {
    final appium = await _checkCommand(
      id: 'appium-cli',
      label: '驱动工具',
      executable: appiumProcess.executable,
      arguments: const ['--version'],
      detailBuilder: (result) => _commandDetail(result),
      readySummary: '本机驱动工具可用。',
      readyNextStep: '准备好后点连接设备。',
      errorSummary: '本机驱动工具不可用。',
      errorNextStep: '请安装驱动工具或更新配置。',
    );
    final xcode = await _checkCommand(
      id: 'xcode-cli',
      label: '开发工具',
      executable: 'xcodebuild',
      arguments: const ['-version'],
      detailBuilder: (result) => _commandDetail(result, maxLines: 2),
      readySummary: '开发工具可用。',
      readyNextStep: '请保持签名和开发者模式可用。',
      errorSummary: '开发工具不可用。',
      errorNextStep: '请安装开发工具并选择开发者目录。',
    );
    final deviceTools = await _checkCommand(
      id: 'ios-device-tools',
      label: '设备工具',
      executable: 'xcrun',
      arguments: const ['devicectl', '--help'],
      readySummary: '本机设备工具可用。',
      readyNextStep: '请连接一台已解锁的有线手机。',
      errorSummary: '本机设备工具不可用。',
      errorNextStep: '请先打开一次开发工具并确认可用。',
    );
    final tunnel = await _checkTunnelProcess();
    final wda = _wdaPrerequisiteCheck(appium, xcode, deviceTools, tunnel);
    final checks = <LocalDependencyCheck>[
      appium,
      xcode,
      deviceTools,
      tunnel,
      wda,
    ];
    return LocalDependencyReport(
      checks: checks,
      checkedAt: DateTime.now(),
      message: _dependencyReportMessage(checks),
    );
  }
}
