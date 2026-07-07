part of '../studio_runtime.dart';

// 项目配置发现失败原因，供 UI 区分缺失和权限不可读。
enum StudioProjectConfigDiscoveryReason { notFound, notReadable }

// 项目配置发现异常，只暴露脱敏原因，不携带本机绝对路径。
final class StudioProjectConfigDiscoveryException implements Exception {
  // 创建项目配置发现异常。
  const StudioProjectConfigDiscoveryException({
    required this.reason,
    required this.relativePath,
    this.cause,
  });

  final StudioProjectConfigDiscoveryReason reason;
  final String relativePath;
  final Object? cause;

  // 用户侧短摘要，用于本机检查报告。
  String get summary {
    return switch (reason) {
      StudioProjectConfigDiscoveryReason.notFound => '未找到项目配置。',
      StudioProjectConfigDiscoveryReason.notReadable => '应用无法读取项目配置。',
    };
  }

  // 用户侧下一步，不展示具体路径。
  String get nextStep {
    return switch (reason) {
      StudioProjectConfigDiscoveryReason.notFound => '请从项目目录启动，或设置项目根目录。',
      StudioProjectConfigDiscoveryReason.notReadable => '请重启开发版，或设置项目根目录。',
    };
  }

  @override
  String toString() {
    return switch (reason) {
      StudioProjectConfigDiscoveryReason.notFound =>
        'Project config was not found.',
      StudioProjectConfigDiscoveryReason.notReadable =>
        'Project config could not be read.',
    };
  }
}

// 项目与设备会话配置，负责从 JSON 读取运行所需的安全配置。
final class DeviceSessionConfig {
  const DeviceSessionConfig({
    this.deviceName = 'iPhone',
    this.bundleId,
    this.noReset = true,
    this.capabilities = const <String, Object?>{},
  });

  final String deviceName;
  final String? bundleId;
  final bool noReset;
  final Map<String, Object?> capabilities;

  // 返回当前配置中的设备标识。
  // 只用于受控启动本机隧道，不直接展示给 UI。
  String? get udid {
    final value = capabilities['appium:udid'] ?? capabilities['udid'];
    return _normalizedConfiguredUdid(value);
  }

  // 判断当前配置是否有可用于真机会话的设备绑定。
  // V2 单设备模式必须显式绑定，避免 Appium 自行猜设备。
  bool get hasValidUdid => udid != null;

  // 判断配置里是否出现了脱敏或示例占位符。
  // 这类值不能进入 Appium session，否则用户只会看到误导性底层错误。
  bool get hasInvalidUdidPlaceholder {
    return _isInvalidConfiguredUdid(capabilities['appium:udid']) ||
        _isInvalidConfiguredUdid(capabilities['udid']);
  }

  // 判断当前真机会话是否需要 Appium XCUITest 本机隧道。
  bool get requiresAppiumTunnel {
    final version =
        capabilities['appium:platformVersion'] ??
        capabilities['platformVersion'];
    final major = _majorVersion(version);
    return major != null && major >= 18;
  }

  AppiumSessionRequest toSessionRequest() {
    if (capabilities.isNotEmpty) {
      return AppiumSessionRequest(
        capabilities: _capabilitiesWithoutInvalidUdid(capabilities),
      );
    }
    return AppiumSessionRequest(
      capabilities: <String, Object?>{
        'platformName': 'iOS',
        'appium:automationName': 'XCUITest',
        'appium:deviceName': deviceName,
        'appium:bundleId': ?bundleId,
        'appium:noReset': noReset,
        'appium:newCommandTimeout': 300,
      },
    );
  }
}

// _normalizedConfiguredUdid 返回可用于 Appium 的设备标识。
// 脱敏占位符和示例值按空处理，避免把假 UDID 发给驱动。
String? _normalizedConfiguredUdid(Object? value) {
  if (value is! String) return null;
  final normalized = value.trim();
  if (normalized.isEmpty || _looksLikeUdidPlaceholder(normalized)) return null;
  return normalized;
}

// _isInvalidConfiguredUdid 判断字段是否是显式无效占位符。
// 缺失或非字符串字段不视为无效，交由常规配置默认值处理。
bool _isInvalidConfiguredUdid(Object? value) {
  if (value is! String) return false;
  final normalized = value.trim();
  return normalized.isNotEmpty && _looksLikeUdidPlaceholder(normalized);
}

// _looksLikeUdidPlaceholder 匹配文档示例和脱敏占位符。
// 不用格式校验真实 UDID，避免误伤测试和未来设备标识格式。
bool _looksLikeUdidPlaceholder(String value) {
  final lower = value.toLowerCase();
  return lower == '[device]' ||
      lower == '<device>' ||
      lower == '{device}' ||
      lower == 'your_device_udid';
}

// _capabilitiesWithoutInvalidUdid 去除无效 UDID 字段后再发起 session。
// 真正的设备绑定由 Runtime 在会话前完成，这里只做最后防线。
Map<String, Object?> _capabilitiesWithoutInvalidUdid(
  Map<String, Object?> capabilities,
) {
  if (!_isInvalidConfiguredUdid(capabilities['appium:udid']) &&
      !_isInvalidConfiguredUdid(capabilities['udid'])) {
    return capabilities;
  }
  final next = Map<String, Object?>.of(capabilities);
  if (_isInvalidConfiguredUdid(next['appium:udid'])) {
    next.remove('appium:udid');
  }
  if (_isInvalidConfiguredUdid(next['udid'])) {
    next.remove('udid');
  }
  return Map<String, Object?>.unmodifiable(next);
}

final class StudioProjectConfig {
  const StudioProjectConfig({
    required this.appiumServer,
    required this.appiumProcess,
    required this.deviceSession,
    required this.workflow,
    required this.tapDurationMs,
    required this.sourcePath,
  });

  final AppiumServerConfig appiumServer;
  final AppiumProcessConfig appiumProcess;
  final DeviceSessionConfig deviceSession;
  final WorkflowDefinition workflow;
  final int tapDurationMs;
  final String sourcePath;

  static StudioProjectConfig load(String path) {
    final file = File(path);
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Project config root must be an object.');
    }
    return fromJson(decoded, sourcePath: file.absolute.path);
  }

  static StudioProjectConfig discover({
    Directory? startDirectory,
    String relativePath = 'config/connected-device.sequence.json',
  }) {
    var directory = startDirectory?.absolute ?? Directory.current.absolute;
    while (true) {
      final candidate = File('${directory.path}/$relativePath');
      final type = _projectConfigCandidateType(
        candidate,
        relativePath: relativePath,
      );
      if (type != FileSystemEntityType.notFound) {
        try {
          return load(candidate.path);
        } on FileSystemException catch (error) {
          throw StudioProjectConfigDiscoveryException(
            reason: StudioProjectConfigDiscoveryReason.notReadable,
            relativePath: relativePath,
            cause: error,
          );
        }
      }
      final parent = directory.parent.absolute;
      if (parent.path == directory.path) {
        throw StudioProjectConfigDiscoveryException(
          reason: StudioProjectConfigDiscoveryReason.notFound,
          relativePath: relativePath,
        );
      }
      directory = parent;
    }
  }

  static StudioProjectConfig discoverFrom({
    required Iterable<Directory> startDirectories,
    String relativePath = 'config/connected-device.sequence.json',
  }) {
    StudioProjectConfigDiscoveryException? lastNotFound;
    final visited = <String>{};
    for (final start in startDirectories) {
      final path = start.absolute.path;
      if (!visited.add(path)) continue;
      try {
        return discover(startDirectory: start, relativePath: relativePath);
      } on StudioProjectConfigDiscoveryException catch (error) {
        if (error.reason == StudioProjectConfigDiscoveryReason.notReadable) {
          rethrow;
        }
        lastNotFound = error;
      } on Object {
        rethrow;
      }
    }
    throw lastNotFound ??
        StudioProjectConfigDiscoveryException(
          reason: StudioProjectConfigDiscoveryReason.notFound,
          relativePath: relativePath,
        );
  }

  static StudioProjectConfig fromJson(
    Map<String, Object?> json, {
    String sourcePath = 'config/connected-device.sequence.json',
  }) {
    final appium = _mapValue(json, 'appium');
    final run = _optionalMapValue(json, 'run') ?? const <String, Object?>{};
    final sequence = _listValue(json, 'sequence');
    final capabilities =
        _optionalMapValue(appium, 'capabilities') ?? const <String, Object?>{};
    final hostname = appium['hostname']?.toString() ?? '127.0.0.1';
    final port = _optionalInt(appium['port']) ?? 4723;
    final path = appium['path']?.toString() ?? '/';
    final tapDurationMs = _optionalInt(run['tapDurationMs']) ?? 80;
    final workflow = WorkflowDefinition.fromLegacySequence(
      id: 'legacy-sequence',
      name: 'Legacy A-F Sequence',
      sequence: sequence,
    );

    return StudioProjectConfig(
      appiumServer: AppiumServerConfig(
        host: hostname,
        port: port,
        basePath: path,
        timeout: _appiumRequestTimeout(appium),
      ),
      appiumProcess: AppiumProcessConfig(
        executable:
            appium['executable']?.toString() ??
            _discoverAppiumExecutable(sourcePath),
        host: hostname,
        port: port,
        logLevel: appium['serverLogLevel']?.toString() ?? 'error',
      ),
      deviceSession: DeviceSessionConfig(
        capabilities: Map<String, Object?>.unmodifiable(capabilities),
      ),
      workflow: workflow,
      tapDurationMs: tapDurationMs,
      sourcePath: sourcePath,
    );
  }
}

Duration _appiumRequestTimeout(Map<String, Object?> appium) {
  final milliseconds =
      _optionalInt(appium['requestTimeoutMs']) ??
      _optionalInt(appium['connectionRetryTimeout']) ??
      300000;
  return Duration(milliseconds: milliseconds.clamp(1000, 600000).toInt());
}

int? _majorVersion(Object? value) {
  if (value is num && value.isFinite) return value.floor();
  if (value is! String) return null;
  final match = RegExp(r'^\s*(\d+)').firstMatch(value);
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

FileSystemEntityType _projectConfigCandidateType(
  File candidate, {
  required String relativePath,
}) {
  try {
    return candidate.statSync().type;
  } on FileSystemException catch (error) {
    throw StudioProjectConfigDiscoveryException(
      reason: StudioProjectConfigDiscoveryReason.notReadable,
      relativePath: relativePath,
      cause: error,
    );
  }
}

String _discoverAppiumExecutable(String sourcePath) {
  final configFile = File(sourcePath);
  final configDirectory = configFile.parent;
  final projectDirectory = configDirectory.path.endsWith('/config')
      ? configDirectory.parent
      : Directory.current;
  final localAppium = File('${projectDirectory.path}/node_modules/.bin/appium');
  if (localAppium.existsSync()) {
    return localAppium.absolute.path;
  }
  return 'appium';
}

Directory _evidenceRootForConfig(StudioProjectConfig config) {
  final projectDirectory = _projectDirectoryForConfig(config);
  return Directory('${projectDirectory.path}/recordings/studio_runtime');
}

File _workflowFileForConfig(StudioProjectConfig config) {
  final projectDirectory = _projectDirectoryForConfig(config);
  return File('${projectDirectory.path}/workflows/current.workflow.json');
}

// 计算当前项目的子流程持久化文件位置。
// 路径只在运行时使用，不进入公共 UI 或文档示例。
File _subWorkflowFileForConfig(StudioProjectConfig config) {
  final projectDirectory = _projectDirectoryForConfig(config);
  return File('${projectDirectory.path}/workflows/sub.workflows.json');
}

// 计算当前项目的目标库持久化文件位置。
// 文件只保存脱敏目标定义，不保存 session、设备标识或截图内容。
File _targetLibraryFileForConfig(StudioProjectConfig config) {
  final projectDirectory = _projectDirectoryForConfig(config);
  return File('${projectDirectory.path}/targets/target.library.json');
}

File _settingsFileForConfig(StudioProjectConfig config) {
  final projectDirectory = _projectDirectoryForConfig(config);
  return File('${projectDirectory.path}/settings/studio.settings.json');
}

Directory _projectDirectoryForConfig(StudioProjectConfig config) {
  final configFile = File(config.sourcePath);
  final configDirectory = configFile.parent;
  return configDirectory.path.endsWith('/config')
      ? configDirectory.parent
      : Directory.current;
}

Map<String, Object?> _mapValue(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) return value;
  throw FormatException('Config field $key must be an object.');
}

Map<String, Object?>? _optionalMapValue(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map<String, Object?>) return value;
  throw FormatException('Config field $key must be an object.');
}

List<Object?> _listValue(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List<Object?>) return value;
  throw FormatException('Config field $key must be a list.');
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite) return value.round();
  return null;
}

double? _optionalDouble(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

bool? _optionalBool(Object? value) {
  if (value is bool) return value;
  return null;
}

bool _validViewportRatio(double value) {
  return value.isFinite && value >= 0 && value <= 1;
}

ViewportPoint _pointForViewportRatio(
  ViewportSize viewport, {
  required double xRatio,
  required double yRatio,
}) {
  return ViewportPoint(
    x: (viewport.width * xRatio).round().clamp(0, viewport.width - 1),
    y: (viewport.height * yRatio).round().clamp(0, viewport.height - 1),
  );
}

int _clampEvidenceMaxRuns(int value) {
  return value.clamp(1, 200).toInt();
}

int _clampEvidenceMaxAgeDays(int value) {
  return value.clamp(1, 90).toInt();
}
