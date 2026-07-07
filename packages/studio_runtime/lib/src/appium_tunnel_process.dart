part of '../studio_runtime.dart';

// 本机隧道启动失败，只暴露用户可处理的短原因。
// 该异常不包含密码、完整路径或底层命令输出。
final class AppiumTunnelException implements Exception {
  const AppiumTunnelException(this.message);

  final String message;

  @override
  String toString() => message;
}

// Appium XCUITest 本机隧道配置。
// 隧道由 Runtime 受控启动，密码只通过 stdin 一次性传入。
final class AppiumTunnelProcessConfig {
  const AppiumTunnelProcessConfig({
    this.sudoExecutable = '/usr/bin/sudo',
    this.envExecutable = '/usr/bin/env',
    this.appiumExecutable = 'appium',
    this.workingDirectory,
    this.environment = _defaultAppiumProcessEnvironment,
    this.udid,
    this.registryPort = 42314,
  });

  final String sudoExecutable;
  final String envExecutable;
  final String appiumExecutable;
  final String? workingDirectory;
  final Map<String, String> environment;
  final String? udid;
  final int registryPort;

  // 生成更新后的隧道配置。
  // 重新绑定手机时只替换目标 UDID，其它进程参数保持不变。
  AppiumTunnelProcessConfig copyWith({String? udid}) {
    return AppiumTunnelProcessConfig(
      sudoExecutable: sudoExecutable,
      envExecutable: envExecutable,
      appiumExecutable: appiumExecutable,
      workingDirectory: workingDirectory,
      environment: environment,
      udid: udid ?? this.udid,
      registryPort: registryPort,
    );
  }

  List<String> get arguments {
    final path = Platform.environment['PATH'];
    return <String>[
      '-S',
      '-p',
      '',
      envExecutable,
      if (path != null && path.trim().isNotEmpty) 'PATH=$path',
      for (final entry in environment.entries) '${entry.key}=${entry.value}',
      appiumExecutable,
      'driver',
      'run',
      'xcuitest',
      'tunnel-creation',
      '--tunnel-registry-port',
      '$registryPort',
      if (udid case final target? when target.trim().isNotEmpty) ...[
        '--udid',
        target.trim(),
      ],
    ];
  }
}

abstract interface class AppiumTunnelProcessHandle {
  int get pid;

  Future<int> get exitCode;

  void writeInputLine(String value);

  Future<void> closeInput();

  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

final class DartAppiumTunnelProcessHandle implements AppiumTunnelProcessHandle {
  DartAppiumTunnelProcessHandle(this._process) {
    unawaited(_process.stdout.drain<void>());
    unawaited(_process.stderr.drain<void>());
  }

  final Process _process;

  @override
  int get pid => _process.pid;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  void writeInputLine(String value) {
    _process.stdin.writeln(value);
  }

  @override
  Future<void> closeInput() {
    return _process.stdin.close();
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return _process.kill(signal);
  }
}

typedef AppiumTunnelProcessStarter =
    Future<AppiumTunnelProcessHandle> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

typedef AppiumTunnelRegistryReader =
    Future<Set<String>> Function(AppiumTunnelProcessConfig config);

typedef AppiumTunnelWaitingCallback = void Function();

abstract interface class AppiumTunnelProcessCleaner {
  // 清理旧的 tunnel-creation 进程。
  // 实现不得记录或持久化 adminPassword。
  Future<void> cleanStaleTunnels({
    required AppiumTunnelProcessConfig config,
    required String adminPassword,
  });
}

Future<AppiumTunnelProcessHandle> defaultAppiumTunnelProcessStarter(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: true,
    mode: ProcessStartMode.normal,
  );
  return DartAppiumTunnelProcessHandle(process);
}

// 通过 sudo 清理遗留的 Appium XCUITest tunnel-creation 进程。
// 只在 registry 为空且一键连接已有密码时使用。
final class SudoAppiumTunnelProcessCleaner
    implements AppiumTunnelProcessCleaner {
  const SudoAppiumTunnelProcessCleaner({
    AppiumTunnelProcessStarter starter = defaultAppiumTunnelProcessStarter,
    this.timeout = const Duration(seconds: 4),
  }) : _starter = starter;

  final AppiumTunnelProcessStarter _starter;
  final Duration timeout;

  @override
  Future<void> cleanStaleTunnels({
    required AppiumTunnelProcessConfig config,
    required String adminPassword,
  }) async {
    if (adminPassword.isEmpty) {
      throw const AppiumTunnelException('请输入本机密码。');
    }
    final process = await _starter(
      config.sudoExecutable,
      <String>[
        '-S',
        '-p',
        '',
        '/usr/bin/pkill',
        '-f',
        'appium driver run xcuitest tunnel-creation',
      ],
      workingDirectory: config.workingDirectory,
      environment: config.environment,
    );
    process.writeInputLine(adminPassword);
    await process.closeInput();
    try {
      final code = await process.exitCode.timeout(timeout);
      if (code != 0 && code != 1) {
        throw const AppiumTunnelException('旧隧道清理失败。请重试密码。');
      }
    } on TimeoutException {
      process.kill();
      throw const AppiumTunnelException('旧隧道清理超时。请重试。');
    }
  }
}

// 读取 Appium XCUITest tunnel registry，只返回设备标识集合。
// 调用方只使用数量或目标命中结果，不把完整标识写入 UI。
Future<Set<String>> defaultAppiumTunnelRegistryReader(
  AppiumTunnelProcessConfig config,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 1);
  try {
    final uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: config.registryPort,
      path: '/remotexpc/tunnels',
    );
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 1));
    final response = await request.close().timeout(const Duration(seconds: 1));
    final body = await utf8
        .decodeStream(response)
        .timeout(const Duration(seconds: 1));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const <String>{};
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) return const <String>{};
    final tunnels = decoded['tunnels'];
    if (tunnels is! Map) return const <String>{};
    return tunnels.keys.map((key) => '$key').toSet();
  } finally {
    client.close(force: true);
  }
}

// 管理由工作台启动的本机隧道进程。
// 只停止自己启动的进程，不接管用户手动打开的隧道终端。
final class AppiumTunnelProcessManager {
  AppiumTunnelProcessManager({
    this.config = const AppiumTunnelProcessConfig(),
    AppiumTunnelProcessStarter starter = defaultAppiumTunnelProcessStarter,
    AppiumTunnelRegistryReader registryReader =
        defaultAppiumTunnelRegistryReader,
    RuntimeDelay delay = defaultRuntimeDelay,
    this.settleDelay = const Duration(seconds: 2),
    this.readinessTimeout = const Duration(seconds: 30),
    this.readinessInterval = const Duration(milliseconds: 500),
  }) : _starter = starter,
       _registryReader = registryReader,
       _delay = delay;

  AppiumTunnelProcessConfig config;
  final AppiumTunnelProcessStarter _starter;
  final AppiumTunnelRegistryReader _registryReader;
  final RuntimeDelay _delay;
  final Duration settleDelay;
  final Duration readinessTimeout;
  final Duration readinessInterval;
  AppiumTunnelProcessHandle? _process;

  bool get isRunning => _process != null;

  int? get pid => _process?.pid;

  // 更新后续隧道启动和 registry 等待使用的目标设备。
  // 已运行的隧道不会被改写，调用方需要先停止再更新。
  void updateConfig(AppiumTunnelProcessConfig next) {
    if (_process != null) {
      throw const AppiumTunnelException('本机隧道已运行。请稍后重试。');
    }
    config = next;
  }

  // 等待已有 tunnel registry 出现目标手机。
  // 不启动或停止进程，用于处理外部已存在的隧道进程。
  Future<void> waitUntilRegistryReady({
    AppiumTunnelWaitingCallback? onWaitingForRegistry,
  }) {
    return _waitUntilRegistryReady(onWaitingForRegistry);
  }

  // 启动本机隧道，密码只写入 stdin，不进入事件、异常或快照。
  Future<int> start({
    required String adminPassword,
    AppiumTunnelWaitingCallback? onWaitingForRegistry,
  }) async {
    if (_process case final running?) {
      await _waitUntilRegistryReady(onWaitingForRegistry);
      return running.pid;
    }
    if (adminPassword.isEmpty) {
      throw const AppiumTunnelException('请输入本机密码。');
    }

    final process = await _starter(
      config.sudoExecutable,
      config.arguments,
      workingDirectory: config.workingDirectory,
      environment: config.environment,
    );
    process.writeInputLine(adminPassword);
    await process.closeInput();
    _process = process;
    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) {
          _process = null;
        }
      }),
    );

    try {
      final code = await process.exitCode.timeout(settleDelay);
      if (identical(_process, process)) {
        _process = null;
      }
      throw AppiumTunnelException(
        code == 0 ? '本机隧道已退出，请重试。' : '本机隧道启动失败。请重试密码。',
      );
    } on TimeoutException {
      try {
        await _waitUntilRegistryReady(onWaitingForRegistry);
      } on Object {
        await stop();
        rethrow;
      }
      return process.pid;
    }
  }

  // 停止由工作台启动的隧道进程。
  Future<void> stop({Duration timeout = const Duration(seconds: 3)}) async {
    final process = _process;
    if (process == null) return;
    process.kill();
    try {
      await process.exitCode.timeout(timeout);
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    } finally {
      if (identical(_process, process)) {
        _process = null;
      }
    }
  }

  // 等待目标手机出现在 tunnel registry。
  // 只有 registry 真正发布设备后，后续 Appium session 才能识别 UDID。
  Future<void> _waitUntilRegistryReady(
    AppiumTunnelWaitingCallback? onWaitingForRegistry,
  ) async {
    onWaitingForRegistry?.call();
    final deadline = DateTime.now().add(readinessTimeout);
    var sawDifferentDevice = false;
    while (!DateTime.now().isAfter(deadline)) {
      final devices = await _readRegistryDevices();
      if (_registryContainsTarget(devices)) return;
      sawDifferentDevice = sawDifferentDevice || devices.isNotEmpty;
      if (readinessInterval > Duration.zero) {
        await _delay(readinessInterval);
      }
    }
    if (sawDifferentDevice && config.udid?.trim().isNotEmpty == true) {
      throw const AppiumTunnelException('绑定手机不可用。');
    }
    throw const AppiumTunnelException('手机隧道未完成。请解锁手机并点允许。');
  }

  // 读取 registry 失败时按空集合处理，等待循环会继续重试。
  Future<Set<String>> _readRegistryDevices() async {
    try {
      return await _registryReader(config);
    } on Object {
      return const <String>{};
    }
  }

  // 单设备模式下优先要求目标 UDID 命中；没有目标时至少需要一个隧道。
  bool _registryContainsTarget(Set<String> devices) {
    final target = config.udid?.trim();
    if (target != null && target.isNotEmpty) {
      return devices.contains(target);
    }
    return devices.isNotEmpty;
  }
}
