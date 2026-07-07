part of '../studio_runtime.dart';

// AndroidAdbDeviceState 表示 ADB 看到的设备状态。
// 只有 ready 能进入 Appium UiAutomator2 会话。
enum AndroidAdbDeviceState { ready, unauthorized, offline, unknown }

// AndroidDeviceDiscoveryException 是 Android 设备发现的用户可处理错误。
// 它只暴露短中文摘要和脱敏详情，不把完整 serial 展示给 UI。
final class AndroidDeviceDiscoveryException implements Exception {
  // 创建 Android 设备发现异常。
  const AndroidDeviceDiscoveryException({
    required this.summary,
    required this.nextStep,
    this.detail = '',
  });

  final String summary;
  final String nextStep;
  final String detail;

  @override
  String toString() => detail.isEmpty ? summary : '$summary $detail';
}

// AndroidAdbDevice 是 ADB 发现的 Android 设备候选。
// 完整 serial 只用于 ADB/Appium 命令，展示层必须使用 maskedSerial。
final class AndroidAdbDevice {
  // 创建 Android ADB 设备候选。
  const AndroidAdbDevice({
    required this.serial,
    required this.state,
    this.model,
    this.androidVersion,
  });

  final String serial;
  final AndroidAdbDeviceState state;
  final String? model;
  final String? androidVersion;

  // 判断设备是否可用于创建 UiAutomator2 会话。
  bool get isReady => state == AndroidAdbDeviceState.ready;

  // 返回用户可读的设备名，缺失机型时使用通用文案。
  String get displayName {
    final value = model?.trim();
    if (value != null && value.isNotEmpty) return value.replaceAll('_', ' ');
    return 'Android 手机';
  }

  // 返回脱敏后的 ADB serial，用于状态摘要和日志。
  String get maskedSerial => _maskAndroidSerial(serial);

  // 转成跨平台设备摘要，不携带完整 serial。
  MobileDeviceSummary toSummary() {
    return MobileDeviceSummary(
      platform: MobilePlatform.android,
      displayName: displayName,
      maskedIdentifier: maskedSerial,
      osVersion: androidVersion,
      connectionKind: MobileConnectionKind.usb,
    );
  }
}

// AndroidAdbDiscovery 汇总一次 ADB 设备发现结果。
// 它负责把无设备、多设备、未授权和离线归类为可操作错误。
final class AndroidAdbDiscovery {
  // 创建 Android ADB 发现结果。
  const AndroidAdbDiscovery({required this.devices});

  final List<AndroidAdbDevice> devices;

  // 当前可用的 Android 设备列表。
  List<AndroidAdbDevice> get readyDevices {
    return devices.where((device) => device.isReady).toList(growable: false);
  }

  // 返回唯一可用设备；否则抛出用户可处理异常。
  AndroidAdbDevice requireSingleReadyDevice() {
    final ready = readyDevices;
    if (ready.length == 1) return ready.single;
    if (ready.length > 1) {
      throw const AndroidDeviceDiscoveryException(
        summary: '发现多台安卓手机。',
        nextStep: '只保留一台 USB 手机后重试。',
      );
    }
    if (devices.any(
      (device) => device.state == AndroidAdbDeviceState.unauthorized,
    )) {
      throw const AndroidDeviceDiscoveryException(
        summary: '安卓手机未授权。',
        nextStep: '在手机上允许 USB 调试后重试。',
      );
    }
    if (devices.any(
      (device) => device.state == AndroidAdbDeviceState.offline,
    )) {
      throw const AndroidDeviceDiscoveryException(
        summary: '安卓手机离线。',
        nextStep: '重插数据线并保持亮屏。',
      );
    }
    throw const AndroidDeviceDiscoveryException(
      summary: '未找到安卓手机。',
      nextStep: '连接一台开启 USB 调试的手机后重试。',
    );
  }
}

// AndroidDeviceDiscovery 抽象 Android 设备发现和日志读取。
// 测试使用 fake，真实实现通过 ADB，不接触 Flutter UI。
abstract interface class AndroidDeviceDiscovery {
  // 发现当前本机可见的 Android 设备。
  Future<AndroidAdbDiscovery> discover();

  // 收集短 logcat 摘要，调用方负责写入受控证据。
  Future<List<String>> collectLogcat({
    required String serial,
    int maxLines = 120,
  });
}

// AdbAndroidDeviceDiscovery 使用 adb devices -l 发现 USB Android 设备。
// 它不启动 Appium，也不执行任何设备动作。
final class AdbAndroidDeviceDiscovery implements AndroidDeviceDiscovery {
  // 创建 ADB Android 发现器，可注入命令执行器以便测试。
  const AdbAndroidDeviceDiscovery({
    CommandRunner runner = defaultCommandRunner,
    this.timeout = const Duration(seconds: 6),
  }) : _runner = runner;

  final CommandRunner _runner;
  final Duration timeout;

  @override
  Future<AndroidAdbDiscovery> discover() async {
    try {
      final result = await _runner('adb', const [
        'devices',
        '-l',
      ]).timeout(timeout);
      if (result.exitCode != 0) {
        throw AndroidDeviceDiscoveryException(
          summary: '无法读取安卓手机。',
          nextStep: '确认 ADB 已安装并开启 USB 调试。',
          detail: _redactConnectionDetail('${result.stderr} ${result.stdout}'),
        );
      }
      final devices = _parseAdbDevices('${result.stdout}');
      return AndroidAdbDiscovery(devices: devices);
    } on AndroidDeviceDiscoveryException {
      rethrow;
    } on TimeoutException {
      throw const AndroidDeviceDiscoveryException(
        summary: '安卓设备检查超时。',
        nextStep: '关闭卡住的 ADB 后重试。',
      );
    } on Object catch (error) {
      throw AndroidDeviceDiscoveryException(
        summary: '无法读取安卓手机。',
        nextStep: '确认 ADB 可用后重试。',
        detail: _redactConnectionDetail(error.toString()),
      );
    }
  }

  @override
  Future<List<String>> collectLogcat({
    required String serial,
    int maxLines = 120,
  }) async {
    final safeMax = maxLines.clamp(1, 500);
    try {
      final result = await _runner('adb', [
        '-s',
        serial,
        'logcat',
        '-d',
        '-t',
        '$safeMax',
        '*:W',
      ]).timeout(timeout);
      if (result.exitCode != 0) {
        return const ['安卓日志读取失败。'];
      }
      return _sanitizeLogcatLines(
        '${result.stdout}',
        serial: serial,
      ).take(safeMax).toList(growable: false);
    } on Object {
      return const ['安卓日志不可用。'];
    }
  }
}

// 解析 adb devices -l 输出为设备候选列表。
List<AndroidAdbDevice> _parseAdbDevices(String output) {
  final devices = <AndroidAdbDevice>[];
  for (final line in output.split(RegExp(r'\r?\n'))) {
    final parsed = _parseAdbDeviceLine(line);
    if (parsed != null) devices.add(parsed);
  }
  return List<AndroidAdbDevice>.unmodifiable(devices);
}

// 解析单行 ADB 设备记录，忽略表头和空行。
AndroidAdbDevice? _parseAdbDeviceLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || trimmed.startsWith('List of devices')) {
    return null;
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length < 2) return null;
  final serial = parts[0].trim();
  if (serial.isEmpty) return null;
  return AndroidAdbDevice(
    serial: serial,
    state: _androidStateFromAdb(parts[1]),
    model: _adbTagValue(parts.skip(2), 'model'),
    androidVersion: _adbTagValue(parts.skip(2), 'release'),
  );
}

// 把 ADB 原始状态映射为 Runtime 内部枚举。
AndroidAdbDeviceState _androidStateFromAdb(String value) {
  return switch (value.trim().toLowerCase()) {
    'device' => AndroidAdbDeviceState.ready,
    'unauthorized' => AndroidAdbDeviceState.unauthorized,
    'offline' => AndroidAdbDeviceState.offline,
    _ => AndroidAdbDeviceState.unknown,
  };
}

// 从 adb devices -l 的 tag 列中提取指定字段。
String? _adbTagValue(Iterable<String> tags, String key) {
  final prefix = '$key:';
  for (final tag in tags) {
    if (!tag.startsWith(prefix)) continue;
    final value = tag.substring(prefix.length).trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

// 脱敏 Android serial，只保留首尾极少字符用于用户辨认。
String _maskAndroidSerial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '设备';
  if (trimmed.length <= 4) return '设备...';
  if (trimmed.length <= 8) {
    return '${trimmed.substring(0, 2)}...${trimmed.substring(trimmed.length - 2)}';
  }
  return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 4)}';
}

// 清理 logcat 摘要，避免设备标识和路径进入 UI 或证据摘要。
Iterable<String> _sanitizeLogcatLines(String output, {required String serial}) {
  return output
      .split(RegExp(r'\r?\n'))
      .map(
        (line) => line
            .replaceAll(serial, '[设备]')
            .replaceAll(RegExp(r'/Users/[^ ]+'), '[本机路径]')
            .replaceAll(RegExp(r'/private/[^ ]+'), '[本机路径]')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
      )
      .where((line) => line.isNotEmpty);
}
