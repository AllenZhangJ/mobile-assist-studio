part of '../studio_runtime.dart';

// RuntimeDeviceBindingException 表示重新绑定手机时的用户可处理错误。
// 异常只携带短中文摘要和下一步，不包含完整设备标识或路径。
final class RuntimeDeviceBindingException implements Exception {
  // 创建重新绑定异常。
  const RuntimeDeviceBindingException({
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

// RuntimeUsbDevice 是 Runtime 内部的 USB 手机候选。
// 完整 UDID 只用于写入本地配置和创建 Appium session。
final class RuntimeUsbDevice {
  // 创建 USB 手机候选。
  const RuntimeUsbDevice({
    required this.udid,
    required this.name,
    required this.modelName,
    required this.platformVersion,
  });

  final String udid;
  final String name;
  final String modelName;
  final String platformVersion;

  // Appium 的 deviceName 优先使用机型名，缺失时退回设备名。
  String get appiumDeviceName {
    if (modelName.trim().isNotEmpty) return modelName.trim();
    if (name.trim().isNotEmpty) return name.trim();
    return 'iPhone';
  }
}

// UsbDeviceDiscovery 负责发现当前可绑定的 USB iPhone。
// 实现必须只返回 USB 设备，不能把局域网配对设备当作当前手机。
abstract interface class UsbDeviceDiscovery {
  Future<List<RuntimeUsbDevice>> listUsbDevices();
}

// DeviceBindingStore 负责把选中的手机写回项目配置。
// 写入成功后返回新的 Appium 会话配置，供 Runtime 内存态同步。
abstract interface class DeviceBindingStore {
  Future<DeviceSessionConfig> saveDeviceBinding(RuntimeUsbDevice device);
}

// NoopUsbDeviceDiscovery 用于未配置真实项目时的安全默认值。
// 它让预览和测试中的空 Runtime 不会访问本机设备。
final class NoopUsbDeviceDiscovery implements UsbDeviceDiscovery {
  const NoopUsbDeviceDiscovery();

  @override
  Future<List<RuntimeUsbDevice>> listUsbDevices() async {
    return const <RuntimeUsbDevice>[];
  }
}

// NoopDeviceBindingStore 用于未配置项目文件时的安全默认值。
// 真实 Mac App 会由 fromProjectConfig 注入本地配置写回实现。
final class NoopDeviceBindingStore implements DeviceBindingStore {
  const NoopDeviceBindingStore();

  @override
  Future<DeviceSessionConfig> saveDeviceBinding(RuntimeUsbDevice device) {
    throw const RuntimeDeviceBindingException(
      summary: '项目未就绪。',
      nextStep: '从项目目录启动后重试。',
    );
  }
}

// DevicectlUsbDeviceDiscovery 通过 xcrun devicectl 发现当前 USB iPhone。
// 它会排除 localNetwork 设备，避免偏离 V2.0 单台 USB 手机边界。
final class DevicectlUsbDeviceDiscovery implements UsbDeviceDiscovery {
  const DevicectlUsbDeviceDiscovery({
    CommandRunner runner = defaultCommandRunner,
    this.timeout = const Duration(seconds: 8),
  }) : _runner = runner;

  final CommandRunner _runner;
  final Duration timeout;

  @override
  Future<List<RuntimeUsbDevice>> listUsbDevices() async {
    final directory = await Directory.systemTemp.createTemp(
      'ios-assist-devices-',
    );
    final outputFile = File('${directory.path}/devices.json');
    try {
      final result = await _runner('xcrun', [
        'devicectl',
        'list',
        'devices',
        '--json-output',
        outputFile.path,
      ]).timeout(timeout);
      if (result.exitCode != 0) {
        throw RuntimeDeviceBindingException(
          summary: '无法读取手机。',
          nextStep: '确认开发工具可用后重试。',
          detail: _redactConnectionDetail('${result.stderr} ${result.stdout}'),
        );
      }
      final text = await outputFile.readAsString();
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const RuntimeDeviceBindingException(
          summary: '手机列表异常。',
          nextStep: '重试查环境后再绑定。',
        );
      }
      final devices = _usbDevicesFromDevicectlJson(decoded);
      if (devices.isEmpty && _hasAvailableNonUsbDevice(decoded)) {
        throw const RuntimeDeviceBindingException(
          summary: '当前不是 USB 连接。',
          nextStep: '用数据线连接一台手机并解锁。',
        );
      }
      return devices;
    } on RuntimeDeviceBindingException {
      rethrow;
    } on Object catch (error) {
      throw RuntimeDeviceBindingException(
        summary: '无法读取手机。',
        nextStep: '确认手机已解锁并信任电脑。',
        detail: _redactConnectionDetail(error.toString()),
      );
    } finally {
      try {
        await directory.delete(recursive: true);
      } on Object {
        // 临时目录清理失败不影响设备发现结果。
      }
    }
  }
}

// LocalDeviceBindingStore 把当前 USB 手机写回 connected-device 配置。
// 它保留原有签名、WDA 和运行配置，只替换设备绑定字段。
final class LocalDeviceBindingStore implements DeviceBindingStore {
  const LocalDeviceBindingStore({required this.file});

  final File file;

  @override
  Future<DeviceSessionConfig> saveDeviceBinding(RuntimeUsbDevice device) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const RuntimeDeviceBindingException(
        summary: '配置异常。',
        nextStep: '修复项目配置后重试。',
      );
    }
    final appium = _ensureJsonObject(decoded, 'appium');
    final capabilities = _ensureJsonObject(appium, 'capabilities');
    capabilities['appium:udid'] = device.udid;
    capabilities['appium:deviceName'] = device.appiumDeviceName;
    if (device.platformVersion.trim().isNotEmpty) {
      capabilities['appium:platformVersion'] = device.platformVersion.trim();
    }
    appium['lastInit'] = <String, Object?>{
      'initializedAt': DateTime.now().toUtc().toIso8601String(),
      'selectedUdid': device.udid,
      'source': 'devicectl/current-usb-device',
      'selection': 'single-usb-device',
      'device': <String, Object?>{
        'udid': device.udid,
        'connectionType': 'USB',
        if (device.name.trim().isNotEmpty) 'name': device.name.trim(),
        if (device.modelName.trim().isNotEmpty)
          'model': device.modelName.trim(),
        if (device.platformVersion.trim().isNotEmpty)
          'platformVersion': device.platformVersion.trim(),
      },
    };
    await _writeJsonAtomic(file, decoded);
    return DeviceSessionConfig(
      capabilities: Map<String, Object?>.unmodifiable(
        _stringKeyedJsonObject(capabilities),
      ),
    );
  }
}

// _usbDevicesFromDevicectlJson 解析 devicectl JSON 并过滤 USB 设备。
// localNetwork 设备会被排除，避免把 Wi-Fi 配对设备写成当前 USB 手机。
List<RuntimeUsbDevice> _usbDevicesFromDevicectlJson(Map json) {
  final result = _optionalJsonObject(json['result']);
  final devices = _optionalJsonList(result?['devices']);
  if (devices == null) return const <RuntimeUsbDevice>[];
  final output = <RuntimeUsbDevice>[];
  for (final item in devices) {
    final device = _optionalJsonObject(item);
    if (device == null || !_devicectlDeviceLooksUsbConnected(device)) {
      continue;
    }
    final hardware = _optionalJsonObject(device['hardwareProperties']);
    final properties = _optionalJsonObject(device['deviceProperties']);
    final udid = _jsonString(hardware?['udid']);
    if (udid == null || udid.isEmpty) continue;
    output.add(
      RuntimeUsbDevice(
        udid: udid,
        name: _jsonString(properties?['name']) ?? '',
        modelName: _jsonString(hardware?['marketingName']) ?? '',
        platformVersion: _jsonString(properties?['osVersionNumber']) ?? '',
      ),
    );
  }
  return List<RuntimeUsbDevice>.unmodifiable(output);
}

// _hasAvailableNonUsbDevice 判断是否只看到了无线可用手机。
// V2.0 只绑定 USB 手机，因此这种情况要给用户明确提示。
bool _hasAvailableNonUsbDevice(Map json) {
  final result = _optionalJsonObject(json['result']);
  final devices = _optionalJsonList(result?['devices']);
  if (devices == null) return false;
  for (final item in devices) {
    final device = _optionalJsonObject(item);
    if (device == null) continue;
    final connection = _optionalJsonObject(device['connectionProperties']);
    final transport = _jsonString(connection?['transportType'])?.toLowerCase();
    if (transport == null ||
        !_hasAny(transport, const ['localnetwork', 'network', 'wifi'])) {
      continue;
    }
    if (_devicectlDeviceHasConnectCapability(device)) {
      return true;
    }
  }
  return false;
}

// _devicectlDeviceLooksUsbConnected 判断设备是否是当前可操作的 USB 手机。
// 它要求设备可连接，并显式排除 localNetwork / Wi-Fi 传输。
bool _devicectlDeviceLooksUsbConnected(Map device) {
  final connection = _optionalJsonObject(device['connectionProperties']);
  final transport = _jsonString(connection?['transportType'])?.toLowerCase();
  if (transport != null &&
      _hasAny(transport, const ['localnetwork', 'network', 'wifi'])) {
    return false;
  }
  if (transport != null &&
      _hasAny(transport, const ['usb', 'wired', 'direct'])) {
    return true;
  }
  return _devicectlDeviceHasConnectCapability(device);
}

// _devicectlDeviceHasConnectCapability 判断 CoreDevice 是否认为设备可连接。
// 不可用的历史设备通常没有 connectdevice / usage assertion 能力。
bool _devicectlDeviceHasConnectCapability(Map device) {
  final capabilities = _optionalJsonList(device['capabilities']);
  if (capabilities == null) return false;
  for (final item in capabilities) {
    final capability = _optionalJsonObject(item);
    final id = _jsonString(capability?['featureIdentifier'])?.toLowerCase();
    if (id == null) continue;
    if (_hasAny(id, const ['connectdevice', 'acquireusageassertion'])) {
      return true;
    }
  }
  return false;
}

// _ensureJsonObject 返回指定 key 的 JSON 对象，缺失时创建。
// 若已有值不是对象，说明配置结构异常，直接阻断写入。
Map _ensureJsonObject(Map parent, String key) {
  final value = parent[key];
  if (value == null) {
    final created = <String, Object?>{};
    parent[key] = created;
    return created;
  }
  if (value is Map) return value;
  throw const RuntimeDeviceBindingException(
    summary: '配置异常。',
    nextStep: '修复项目配置后重试。',
  );
}

// _stringKeyedJsonObject 把 JSON Map 安全收窄成 String key。
// Appium capabilities 需要 String key，非字符串 key 会被忽略。
Map<String, Object?> _stringKeyedJsonObject(Map value) {
  final output = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is String) {
      output[entry.key as String] = entry.value;
    }
  }
  return output;
}

// _writeJsonAtomic 用临时文件写入再替换，避免配置半写入。
// 临时文件只落在同目录，便于保持权限和跨卷 rename 稳定。
Future<void> _writeJsonAtomic(File file, Object? value) async {
  final temporary = File(
    '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
  );
  try {
    const encoder = JsonEncoder.withIndent('  ');
    await temporary.writeAsString('${encoder.convert(value)}\n');
    await temporary.rename(file.path);
  } catch (_) {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    rethrow;
  }
}

// _optionalJsonObject 对动态 JSON 做 Map 收窄。
// 调用方只读取有限字段，不依赖 devicectl 的完整结构。
Map? _optionalJsonObject(Object? value) {
  return value is Map ? value : null;
}

// _optionalJsonList 对动态 JSON 做 List 收窄。
// 非列表数据按空处理，让上层给出统一错误。
List? _optionalJsonList(Object? value) {
  return value is List ? value : null;
}

// _jsonString 读取 JSON 字符串并去除首尾空白。
// 空字符串按 null 处理，减少无效字段进入配置。
String? _jsonString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
