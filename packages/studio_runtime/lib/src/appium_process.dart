part of '../studio_runtime.dart';

// XCUITest 11+ 在新系统上优先使用 devicectl 发现真机，避免旧 usbmux 列表为空。
const _defaultAppiumProcessEnvironment = <String, String>{
  'APPIUM_XCUITEST_PREFER_DEVICECTL': 'true',
};

// Appium 进程配置与生命周期管理，负责启动、复用和停止本机驱动进程。
final class AppiumProcessConfig {
  const AppiumProcessConfig({
    this.executable = 'appium',
    this.host = '127.0.0.1',
    this.port = 4723,
    this.logLevel = 'error',
    this.environment = _defaultAppiumProcessEnvironment,
  });

  final String executable;
  final String host;
  final int port;
  final String logLevel;
  final Map<String, String> environment;

  List<String> get arguments => <String>[
    '--address',
    host,
    '--port',
    '$port',
    '--log-level',
    logLevel,
  ];
}

abstract interface class ProcessHandle {
  int get pid;

  Future<int> get exitCode;

  bool kill([ProcessSignal signal = ProcessSignal.sigterm]);
}

final class DartProcessHandle implements ProcessHandle {
  DartProcessHandle(this._process) {
    unawaited(_process.stdout.drain<void>());
    unawaited(_process.stderr.drain<void>());
  }

  final Process _process;

  @override
  int get pid => _process.pid;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return _process.kill(signal);
  }
}

typedef ProcessStarter =
    Future<ProcessHandle> Function(
      String executable,
      List<String> arguments, {
      Map<String, String>? environment,
    });

typedef RuntimeDelay = Future<void> Function(Duration duration);

// Appium 主进程清理异常，只暴露短原因。
// 具体命令参数不进入 UI，避免泄露本机路径。
final class AppiumProcessCleanupException implements Exception {
  const AppiumProcessCleanupException(this.message);

  final String message;

  @override
  String toString() => message;
}

// AppiumProcessCleaner 清理已占用当前 host/port 的旧 Appium 服务。
// 它只服务一键连接恢复，不负责常规停止按钮。
abstract interface class AppiumProcessCleaner {
  Future<void> cleanStaleAppium({required AppiumProcessConfig config});
}

Future<ProcessHandle> defaultProcessStarter(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    arguments,
    environment: environment,
    includeParentEnvironment: true,
    mode: ProcessStartMode.normal,
  );
  return DartProcessHandle(process);
}

Future<void> defaultRuntimeDelay(Duration duration) {
  return Future<void>.delayed(duration);
}

// ScopedAppiumProcessCleaner 只清理当前配置端口上的 Appium 主服务。
// tunnel-creation 没有 --address / --port 参数，不会被该模式命中。
final class ScopedAppiumProcessCleaner implements AppiumProcessCleaner {
  const ScopedAppiumProcessCleaner({
    ProcessStarter starter = defaultProcessStarter,
    this.executable = '/usr/bin/pkill',
    this.timeout = const Duration(seconds: 4),
  }) : _starter = starter;

  final ProcessStarter _starter;
  final String executable;
  final Duration timeout;

  @override
  Future<void> cleanStaleAppium({required AppiumProcessConfig config}) async {
    final pattern = _scopedAppiumProcessPattern(config);
    final process = await _starter(executable, <String>[
      '-f',
      pattern,
    ], environment: config.environment);
    try {
      final code = await process.exitCode.timeout(timeout);
      if (code != 0 && code != 1) {
        throw const AppiumProcessCleanupException('旧驱动清理失败。');
      }
    } on TimeoutException {
      process.kill();
      throw const AppiumProcessCleanupException('旧驱动清理超时。');
    }
  }
}

final class AppiumProcessManager {
  AppiumProcessManager({
    this.config = const AppiumProcessConfig(),
    ProcessStarter starter = defaultProcessStarter,
  }) : _starter = starter;

  final AppiumProcessConfig config;
  final ProcessStarter _starter;
  ProcessHandle? _process;

  bool get isRunning => _process != null;

  int? get pid => _process?.pid;

  Future<int> start() async {
    if (_process case final running?) {
      return running.pid;
    }
    final process = await _starter(
      config.executable,
      config.arguments,
      environment: config.environment,
    );
    _process = process;
    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) {
          _process = null;
        }
      }),
    );
    return process.pid;
  }

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
}

// _scopedAppiumProcessPattern 生成 pkill 的最小匹配范围。
// 只匹配 Appium 主服务的地址和端口，不匹配隧道或其它 Node 进程。
String _scopedAppiumProcessPattern(AppiumProcessConfig config) {
  return 'appium .*--address ${_processRegexEscape(config.host)} .*--port ${config.port}';
}

// _processRegexEscape 转义 pkill -f 使用的正则片段。
// 这里不依赖第三方包，保持 runtime 包轻量。
String _processRegexEscape(String value) {
  return value.replaceAllMapped(
    RegExp(r'([\\.^$|?*+()[\]{}])'),
    (match) => '\\${match.group(1)}',
  );
}
