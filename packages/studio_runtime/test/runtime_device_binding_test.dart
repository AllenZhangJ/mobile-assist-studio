// ignore_for_file: unused_import, unnecessary_import

import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

import 'support/runtime_test_harness.dart';

// Runtime 设备绑定测试。
// 用例只使用 fake devicectl JSON，不访问真实 iPhone 或 Appium。
void main() {
  test('devicectl discovery returns only current USB devices', () async {
    final discovery = DevicectlUsbDeviceDiscovery(
      runner: (executable, arguments) async {
        final outputPath = arguments[arguments.indexOf('--json-output') + 1];
        await File(outputPath).writeAsString(
          jsonEncode({
            'result': {
              'devices': [
                _devicectlDevice(
                  udid: '00008120-000E708A26E2201E',
                  name: 'Wi-Fi Phone',
                  model: 'iPhone 15',
                  version: '18.7.8',
                  transport: 'localNetwork',
                  connectable: true,
                ),
                _devicectlDevice(
                  udid: '11112222-3333444455556666',
                  name: 'USB Phone',
                  model: 'iPhone 13 Pro',
                  version: '26.5',
                  transport: 'wired',
                  connectable: true,
                ),
                _devicectlDevice(
                  udid: '88889999-3333444455557777',
                  name: 'Old Phone',
                  model: 'iPhone 14',
                  version: '26.5',
                  transport: null,
                  connectable: false,
                ),
              ],
            },
          }),
        );
        return ProcessResult(1, 0, '', '');
      },
    );

    final devices = await discovery.listUsbDevices();

    expect(devices, hasLength(1));
    expect(devices.single.name, 'USB Phone');
    expect(devices.single.appiumDeviceName, 'iPhone 13 Pro');
    expect(devices.single.platformVersion, '26.5');
  });

  test('devicectl discovery explains network-only device', () async {
    final discovery = DevicectlUsbDeviceDiscovery(
      runner: (executable, arguments) async {
        final outputPath = arguments[arguments.indexOf('--json-output') + 1];
        await File(outputPath).writeAsString(
          jsonEncode({
            'result': {
              'devices': [
                _devicectlDevice(
                  udid: '00008120-000E708A26E2201E',
                  name: 'Wi-Fi Phone',
                  model: 'iPhone 15',
                  version: '18.7.8',
                  transport: 'localNetwork',
                  connectable: true,
                ),
              ],
            },
          }),
        );
        return ProcessResult(1, 0, '', '');
      },
    );

    await expectLater(
      discovery.listUsbDevices(),
      throwsA(
        isA<RuntimeDeviceBindingException>()
            .having((error) => error.summary, 'summary', '当前不是 USB 连接。')
            .having((error) => error.nextStep, 'nextStep', '用数据线连接一台手机并解锁。'),
      ),
    );
  });

  test('local device binding store updates only device fields', () async {
    final directory = await Directory.systemTemp.createTemp(
      'runtime-device-binding-',
    );
    final file = File('${directory.path}/connected-device.sequence.json');
    await file.writeAsString(
      jsonEncode({
        'appium': {
          'hostname': '127.0.0.1',
          'capabilities': {
            'platformName': 'iOS',
            'appium:automationName': 'XCUITest',
            'appium:deviceName': 'Old iPhone',
            'appium:platformVersion': '17.5',
            'appium:udid': 'OLD_DEVICE',
            'appium:updatedWDABundleId': 'com.example.wda',
          },
        },
        'sequence': [],
      }),
    );
    final store = LocalDeviceBindingStore(file: file);

    final sessionConfig = await store.saveDeviceBinding(
      const RuntimeUsbDevice(
        udid: 'NEW_DEVICE',
        name: 'Allen',
        modelName: 'iPhone 13 Pro',
        platformVersion: '26.5',
      ),
    );
    final persisted = jsonDecode(await file.readAsString()) as Map;
    await directory.delete(recursive: true);

    final capabilities = (persisted['appium'] as Map)['capabilities'] as Map;
    expect(capabilities['appium:udid'], 'NEW_DEVICE');
    expect(capabilities['appium:deviceName'], 'iPhone 13 Pro');
    expect(capabilities['appium:platformVersion'], '26.5');
    expect(capabilities['appium:updatedWDABundleId'], 'com.example.wda');
    expect((persisted['appium'] as Map)['lastInit'], isA<Map>());
    expect(sessionConfig.udid, 'NEW_DEVICE');
    expect(sessionConfig.requiresAppiumTunnel, isTrue);
  });

  test(
    'runtime binds current USB device and uses it for next session',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'runtime-device-binding-connect-',
      );
      final file = File('${directory.path}/connected-device.sequence.json');
      await file.writeAsString(
        jsonEncode({
          'appium': {
            'capabilities': {
              'platformName': 'iOS',
              'appium:automationName': 'XCUITest',
              'appium:deviceName': 'Old iPhone',
              'appium:platformVersion': '18.1',
              'appium:udid': 'OLD_DEVICE',
            },
          },
          'sequence': [],
        }),
      );
      final server = await _recordingSessionServer();
      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: const DeviceSessionConfig(
            capabilities: {
              'platformName': 'iOS',
              'appium:automationName': 'XCUITest',
              'appium:udid': 'OLD_DEVICE',
            },
          ),
        ),
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([
          RuntimeUsbDevice(
            udid: 'NEW_DEVICE',
            name: 'USB Phone',
            modelName: 'iPhone 13 Pro',
            platformVersion: '26.5',
          ),
        ]),
        deviceBindingStore: LocalDeviceBindingStore(file: file),
      );

      final bound = await controller.bindCurrentUsbDevice();
      await controller.connectDevice();
      await controller.dispose();
      await server.close(force: true);
      await directory.delete(recursive: true);

      expect(bound, isTrue);
      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'bound-session');
      expect(_lastSessionPayload, contains('NEW_DEVICE'));
      expect(_lastSessionPayload, isNot(contains('OLD_DEVICE')));
    },
  );

  test(
    'one-button connect auto binds current USB device before session',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'runtime-device-auto-binding-connect-',
      );
      final file = File('${directory.path}/connected-device.sequence.json');
      await file.writeAsString(
        jsonEncode({
          'appium': {
            'capabilities': {
              'platformName': 'iOS',
              'appium:automationName': 'XCUITest',
              'appium:deviceName': 'Old iPhone',
              'appium:platformVersion': '17.5',
              'appium:udid': 'OLD_DEVICE',
            },
          },
          'sequence': [],
        }),
      );
      final server = await _recordingSessionServer();
      final controller = StudioRuntimeController(
        availabilityProbe: FakeAvailabilityChecker([
          const AppiumAvailability(available: true, message: 'ready'),
        ]),
        dependencyChecker: FakeDependencyChecker(LocalDependencyReport.empty),
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: const DeviceSessionConfig(
            capabilities: {
              'platformName': 'iOS',
              'appium:automationName': 'XCUITest',
              'appium:udid': 'OLD_DEVICE',
            },
          ),
        ),
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([
          RuntimeUsbDevice(
            udid: 'NEW_DEVICE',
            name: 'USB Phone',
            modelName: 'iPhone 13 Pro',
            platformVersion: '17.5',
          ),
        ]),
        deviceBindingStore: LocalDeviceBindingStore(file: file),
        appiumReadinessInterval: Duration.zero,
      );

      _lastSessionPayload = '';
      await controller.connectDeviceEndToEnd();
      final persisted = jsonDecode(await file.readAsString()) as Map;
      await controller.dispose();
      await server.close(force: true);
      await directory.delete(recursive: true);

      final capabilities = (persisted['appium'] as Map)['capabilities'] as Map;
      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'bound-session');
      expect(capabilities['appium:udid'], 'NEW_DEVICE');
      expect(_lastSessionPayload, contains('NEW_DEVICE'));
      expect(_lastSessionPayload, isNot(contains('OLD_DEVICE')));
      expect(
        controller.snapshot.events.map((event) => event.message),
        containsAllInOrder([
          '正在连接设备。',
          '已自动绑定当前 USB 手机。',
          '正在检查本机环境。',
          '正在准备驱动。',
          '手机会话已连接。',
        ]),
      );
    },
  );

  test('one-button connect stops when no USB phone is visible', () async {
    final server = await _recordingSessionServer();
    final sessionManager = DeviceSessionManager(
      client: AppiumClient(config: AppiumServerConfig(port: server.port)),
      config: const DeviceSessionConfig(
        capabilities: {
          'platformName': 'iOS',
          'appium:automationName': 'XCUITest',
          'appium:udid': 'OLD_DEVICE',
        },
      ),
    );
    final controller = StudioRuntimeController(
      availabilityProbe: FakeAvailabilityChecker([
        const AppiumAvailability(available: true, message: 'ready'),
      ]),
      dependencyChecker: FakeDependencyChecker(LocalDependencyReport.empty),
      sessionManager: sessionManager,
      usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([]),
      deviceBindingStore: _RecordingDeviceBindingStore(),
      appiumReadinessInterval: Duration.zero,
    );

    _lastSessionPayload = '';
    await controller.connectDeviceEndToEnd();
    await controller.dispose();
    await server.close(force: true);

    expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
    expect(controller.snapshot.appiumMessage, '未找到 USB 手机。');
    expect(_lastSessionPayload, isEmpty);
  });

  test(
    'direct session connect stops before Appium when no USB phone is visible',
    () async {
      final server = await _recordingSessionServer();
      final sessionManager = DeviceSessionManager(
        client: AppiumClient(config: AppiumServerConfig(port: server.port)),
        config: const DeviceSessionConfig(
          capabilities: {
            'platformName': 'iOS',
            'appium:automationName': 'XCUITest',
            'appium:udid': 'OLD_DEVICE',
          },
        ),
      );
      final controller = StudioRuntimeController(
        sessionManager: sessionManager,
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([]),
        deviceBindingStore: _RecordingDeviceBindingStore(),
      );

      _lastSessionPayload = '';
      await controller.connectDevice();
      await controller.dispose();
      await server.close(force: true);

      expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
      expect(controller.snapshot.appiumMessage, '未找到 USB 手机。');
      expect(_lastSessionPayload, isEmpty);
    },
  );

  test(
    'direct session connect rejects redacted UDID placeholders before Appium',
    () async {
      final server = await _recordingSessionServer();
      final sessionManager = DeviceSessionManager(
        client: AppiumClient(config: AppiumServerConfig(port: server.port)),
        config: const DeviceSessionConfig(
          capabilities: {
            'platformName': 'iOS',
            'appium:automationName': 'XCUITest',
            'appium:udid': '[device]',
          },
        ),
      );
      final controller = StudioRuntimeController(
        sessionManager: sessionManager,
      );

      _lastSessionPayload = '';
      await controller.connectDevice();
      await controller.dispose();
      await server.close(force: true);

      expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
      expect(controller.snapshot.appiumMessage, '未找到 USB 手机。');
      expect(
        controller.snapshot.lastConnectionDiagnostic?.nextStep,
        '用数据线连接一台手机并解锁，再点连接设备。',
      );
      expect(
        controller.snapshot.events.last.message,
        isNot(contains('[device]')),
      );
      expect(_lastSessionPayload, isEmpty);
    },
  );

  test(
    'direct session connect binds current USB phone before Appium',
    () async {
      final server = await _recordingSessionServer();
      final sessionManager = DeviceSessionManager(
        client: AppiumClient(config: AppiumServerConfig(port: server.port)),
        config: const DeviceSessionConfig(
          capabilities: {
            'platformName': 'iOS',
            'appium:automationName': 'XCUITest',
            'appium:udid': 'OLD_DEVICE',
          },
        ),
      );
      final controller = StudioRuntimeController(
        sessionManager: sessionManager,
        usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([
          RuntimeUsbDevice(
            udid: 'NEW_DEVICE',
            name: 'USB Phone',
            modelName: 'iPhone 13 Pro',
            platformVersion: '17.5',
          ),
        ]),
        deviceBindingStore: _RecordingDeviceBindingStore(),
      );

      _lastSessionPayload = '';
      await controller.connectDevice();
      await controller.dispose();
      await server.close(force: true);

      expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
      expect(controller.snapshot.sessionId, 'bound-session');
      expect(_lastSessionPayload, contains('NEW_DEVICE'));
      expect(_lastSessionPayload, isNot(contains('OLD_DEVICE')));
    },
  );

  test('runtime refuses binding when no USB phone is visible', () async {
    final controller = StudioRuntimeController(
      usbDeviceDiscovery: const _StaticUsbDeviceDiscovery([]),
    );

    final bound = await controller.bindCurrentUsbDevice();
    await controller.dispose();

    expect(bound, isFalse);
    expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
    expect(controller.snapshot.appiumMessage, '未找到 USB 手机。');
    expect(
      controller.snapshot.lastConnectionDiagnostic?.nextStep,
      '用数据线连接一台手机并解锁。',
    );
  });
}

String _lastSessionPayload = '';

// 启动记录 create session payload 的 fake Appium server。
// 用它验证重新绑定后的 UDID 会进入下一次 session 请求。
Future<HttpServer> _recordingSessionServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (request.method == 'POST' && request.uri.path == '/session') {
      _lastSessionPayload = await utf8.decodeStream(request);
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'value': {
              'sessionId': 'bound-session',
              'capabilities': {'platformName': 'iOS'},
            },
          }),
        )
        ..close();
      return;
    }
    if (request.method == 'DELETE' &&
        request.uri.path == '/session/bound-session') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'value': null}))
        ..close();
      return;
    }
    request.response
      ..statusCode = 404
      ..close();
  });
  return server;
}

// 构造 devicectl 设备 JSON。
// 测试只覆盖 Runtime 需要读取的字段。
Map<String, Object?> _devicectlDevice({
  required String udid,
  required String name,
  required String model,
  required String version,
  required String? transport,
  required bool connectable,
}) {
  return {
    'connectionProperties': {'transportType': ?transport},
    'deviceProperties': {'name': name, 'osVersionNumber': version},
    'hardwareProperties': {'udid': udid, 'marketingName': model},
    'capabilities': [
      if (connectable)
        {'featureIdentifier': 'com.apple.coredevice.feature.connectdevice'},
    ],
  };
}

// 静态 USB 设备发现 fake。
// Runtime 测试用它避免访问 xcrun 或真实手机。
final class _StaticUsbDeviceDiscovery implements UsbDeviceDiscovery {
  const _StaticUsbDeviceDiscovery(this.devices);

  final List<RuntimeUsbDevice> devices;

  @override
  Future<List<RuntimeUsbDevice>> listUsbDevices() async => devices;
}

// 记录型绑定存储 fake。
// 用于让一键连接走真实绑定分支，同时避免写本地项目文件。
final class _RecordingDeviceBindingStore implements DeviceBindingStore {
  int saves = 0;

  @override
  Future<DeviceSessionConfig> saveDeviceBinding(RuntimeUsbDevice device) async {
    saves += 1;
    return DeviceSessionConfig(
      capabilities: {
        'platformName': 'iOS',
        'appium:automationName': 'XCUITest',
        'appium:udid': device.udid,
        'appium:deviceName': device.appiumDeviceName,
        'appium:platformVersion': device.platformVersion,
      },
    );
  }
}
