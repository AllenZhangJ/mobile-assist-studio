import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

import 'support/runtime_test_harness.dart';

// ThrowingSessionManager 用于模拟 Appium 建立会话失败。
// 它不连接真实设备，只把指定异常交给 Runtime 分类。
final class ThrowingSessionManager implements RuntimeSessionManager {
  // 创建固定失败的会话管理器。
  ThrowingSessionManager(this.error);

  final Object error;

  @override
  WebDriverSession? get session => null;

  @override
  Future<WebDriverSession> connect() async {
    throw error;
  }

  @override
  Future<void> disconnect() async {}
}

// fake Appium 测试使用显式假设备绑定。
// 这保持测试请求形态接近真机，同时不访问本机 iPhone。
const _fakeDeviceSessionConfig = DeviceSessionConfig(
  capabilities: {
    'platformName': 'iOS',
    'appium:automationName': 'XCUITest',
    'appium:udid': 'TEST_DEVICE',
  },
);

// 设备会话与预览动作测试，聚焦 Appium session、截图和归一化手势换算。
// 用例只使用 fake Appium server 和 fake device actions，不连接真实 iPhone。
void main() {
  test(
    'device session manager connects and disconnects through Appium client',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      final serverSubscription = server.listen((request) async {
        requests.add('${request.method} ${request.uri.path}');
        if (request.method == 'POST' && request.uri.path == '/session') {
          await utf8.decodeStream(request);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'value': {
                  'sessionId': 'device-session',
                  'capabilities': {'platformName': 'iOS'},
                },
              }),
            )
            ..close();
          return;
        }
        if (request.method == 'DELETE' &&
            request.uri.path == '/session/device-session') {
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

      final manager = DeviceSessionManager(
        client: AppiumClient(config: AppiumServerConfig(port: server.port)),
        config: _fakeDeviceSessionConfig,
      );

      final session = await manager.connect();
      await manager.disconnect();

      expect(session.id, 'device-session');
      expect(manager.session, isNull);
      expect(requests, ['POST /session', 'DELETE /session/device-session']);

      await serverSubscription.cancel();
      await server.close(force: true);
    },
  );

  test('device session manager rejects redacted UDID before Appium', () async {
    final manager = DeviceSessionManager(
      config: const DeviceSessionConfig(
        capabilities: {
          'platformName': 'iOS',
          'appium:automationName': 'XCUITest',
          'appium:udid': '[device]',
        },
      ),
    );

    await expectLater(
      manager.connect(),
      throwsA(
        isA<RuntimeDeviceBindingException>()
            .having((error) => error.summary, 'summary', '未找到 USB 手机。')
            .having(
              (error) => error.nextStep,
              'nextStep',
              '用数据线连接一台手机并解锁，再点连接设备。',
            ),
      ),
    );
    expect(manager.session, isNull);
  });

  test('device session manager rejects missing UDID before Appium', () async {
    final manager = DeviceSessionManager();

    await expectLater(
      manager.connect(),
      throwsA(
        isA<RuntimeDeviceBindingException>()
            .having((error) => error.summary, 'summary', '未找到 USB 手机。')
            .having((error) => error.detail, 'detail', '缺少当前手机绑定。'),
      ),
    );
    expect(manager.session, isNull);
  });

  test(
    'runtime controller emits device connect and disconnect states',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverSubscription = server.listen((request) async {
        if (request.method == 'POST' && request.uri.path == '/session') {
          await utf8.decodeStream(request);
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'value': {
                  'sessionId': 'controller-session',
                  'capabilities': {'platformName': 'iOS'},
                },
              }),
            )
            ..close();
          return;
        }
        if (request.method == 'DELETE' &&
            request.uri.path == '/session/controller-session') {
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

      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: _fakeDeviceSessionConfig,
        ),
      );
      final snapshots = <StudioRuntimeSnapshot>[];
      final subscription = controller.snapshots.listen(snapshots.add);

      await controller.connectDevice();
      await controller.disconnectDevice();
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      await controller.dispose();

      expect(
        controller.snapshot.connectionStatus,
        ConnectionStatus.disconnected,
      );
      expect(controller.snapshot.sessionId, isNull);
      expect(
        snapshots.map((snapshot) => snapshot.connectionStatus),
        containsAllInOrder([
          ConnectionStatus.connecting,
          ConnectionStatus.connected,
          ConnectionStatus.disconnecting,
          ConnectionStatus.disconnected,
        ]),
      );

      await serverSubscription.cancel();
      await server.close(force: true);
    },
  );

  test(
    'runtime controller explains internal device binding failures',
    () async {
      final controller = StudioRuntimeController(
        sessionManager: ThrowingSessionManager(
          const RuntimeDeviceBindingException(
            summary: '未找到 USB 手机。',
            nextStep: '用数据线连接一台手机并解锁，再点连接设备。',
            detail: '设备配置不是当前手机。',
          ),
        ),
      );

      await controller.connectDevice();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
      expect(controller.snapshot.appiumMessage, '未找到 USB 手机。');
      expect(
        controller.snapshot.lastConnectionDiagnostic?.type,
        RuntimeConnectionIssueType.deviceNotVisible,
      );
      expect(controller.snapshot.events.last.message, contains('连接设备'));
      expect(
        controller.snapshot.events.last.message,
        isNot(contains('[device]')),
      );
    },
  );

  test(
    'runtime controller classifies developer trust connection failures',
    () async {
      final deviceId = ['11112222', '3333444455556666'].join('-');
      final controller = StudioRuntimeController(
        sessionManager: ThrowingSessionManager(
          AppiumClientException(
            'Developer App Certificate is not trusted at /Users/private/project on $deviceId',
          ),
        ),
      );

      await controller.connectDevice();
      await controller.dispose();

      expect(
        controller.snapshot.connectionStatus,
        ConnectionStatus.waitingForDeveloperTrust,
      );
      expect(controller.snapshot.appiumMessage, '等待手机信任。');
      expect(controller.snapshot.events.last.message, contains('信任一次'));
      expect(
        controller.snapshot.events.last.message,
        isNot(contains('/Users/')),
      );
      expect(
        controller.snapshot.events.last.message,
        isNot(contains(deviceId)),
      );
      expect(controller.snapshot.events.last.message, contains('[本机路径]'));
      expect(controller.snapshot.events.last.message, contains('[标识]'));
      expect(
        controller.snapshot.events.last.message,
        isNot(contains('[device]')),
      );
    },
  );
  test(
    'runtime controller classifies WDA socket hang up as session not ready',
    () async {
      final controller = StudioRuntimeController(
        sessionManager: ThrowingSessionManager(
          const AppiumClientException(
            'Could not proxy command to the remote server. socket hang up on port 8100',
          ),
        ),
      );

      await controller.connectDevice();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
      expect(controller.snapshot.appiumMessage, '手机会话启动失败。');
      expect(controller.snapshot.events.last.message, contains('已解锁'));
    },
  );
  test('runtime controller classifies Xcode build failures separately', () async {
    final controller = StudioRuntimeController(
      sessionManager: ThrowingSessionManager(
        const AppiumClientException(
          'Unable to launch WebDriverAgent. Original error: xcodebuild failed with code 65',
        ),
      ),
    );

    await controller.connectDevice();
    await controller.dispose();

    expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
    expect(controller.snapshot.appiumMessage, '手机会话构建失败。');
    expect(
      controller.snapshot.lastConnectionDiagnostic?.type,
      RuntimeConnectionIssueType.wdaBuildFailed,
    );
    expect(controller.snapshot.events.last.message, contains('处理签名'));
  });
  test('runtime controller explains driver invisible device failures', () async {
    final controller = StudioRuntimeController(
      sessionManager: ThrowingSessionManager(
        const AppiumClientException(
          'Appium returned HTTP 500 for /session. Unknown device or simulator UDID: 11112222-3333444455556666',
        ),
      ),
    );

    await controller.connectDevice();
    await controller.dispose();

    expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
    expect(controller.snapshot.appiumMessage, '驱动未识别手机。');
    expect(
      controller.snapshot.lastConnectionDiagnostic?.type,
      RuntimeConnectionIssueType.driverDeviceNotVisible,
    );
    expect(controller.snapshot.events.last.message, contains('保持解锁'));
    expect(controller.snapshot.events.last.message, contains('本机驱动没有看到当前手机'));
    expect(
      controller.snapshot.events.last.message,
      isNot(contains('11112222')),
    );
    expect(
      controller.snapshot.events.last.message,
      isNot(contains('[device]')),
    );
  });

  test('runtime controller explains missing RemoteXPC tunnel failures', () async {
    final controller = StudioRuntimeController(
      sessionManager: ThrowingSessionManager(
        const AppiumClientException(
          'Cannot create port forwarder via RemoteXPC tunnel for device (RemoteXPC tunnel is not available for this session)',
        ),
      ),
    );

    await controller.connectDevice();
    await controller.dispose();

    expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
    expect(controller.snapshot.appiumMessage, '本机隧道未就绪。');
    expect(controller.snapshot.events.last.message, contains('输入密码'));
  });

  test(
    'runtime controller blocks connection when required tunnel is missing',
    () async {
      final controller = StudioRuntimeController(
        requiresAppiumTunnel: true,
        dependencyChecker: FakeDependencyChecker(
          LocalDependencyReport(
            checks: const [
              LocalDependencyCheck(
                id: 'ios-tunnel',
                label: '本机隧道',
                status: LocalDependencyStatus.warning,
                summary: '未发现本机隧道。',
                nextStep: '在项目根目录运行隧道命令。',
              ),
            ],
            checkedAt: DateTime(2026, 1, 7),
            message: '本机检查需要处理。',
          ),
        ),
      );

      await controller.refreshDependencyReport();
      await controller.connectDevice();
      await controller.dispose();

      expect(controller.snapshot.connectionStatus, ConnectionStatus.error);
      expect(controller.snapshot.appiumMessage, '本机隧道未就绪。');
      expect(controller.snapshot.events.last.message, contains('输入密码'));
    },
  );

  test('runtime controller captures and clears latest screenshot', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor(
      screenshotBase64: 'base64-preview',
    );
    final controller = StudioRuntimeController(
      sessionManager: DeviceSessionManager(
        client: AppiumClient(config: AppiumServerConfig(port: server.port)),
        config: _fakeDeviceSessionConfig,
      ),
      deviceActions: deviceActions,
    );

    await controller.connectDevice();
    final screenshot = await controller.captureScreenshot(reason: 'test');

    expect(screenshot, 'base64-preview');
    expect(controller.snapshot.latestScreenshotBase64, 'base64-preview');
    expect(controller.snapshot.latestScreenshotAt, isNotNull);
    expect(deviceActions.calls, ['screenshot']);

    await controller.disconnectDevice();
    await controller.dispose();
    await server.close(force: true);

    expect(controller.snapshot.latestScreenshotBase64, isNull);
    expect(controller.snapshot.latestScreenshotAt, isNull);
  });
  test(
    'runtime controller taps device preview through viewport size',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor(
        viewportSize: const ViewportSize(width: 400, height: 800),
      );
      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: _fakeDeviceSessionConfig,
        ),
        deviceActions: deviceActions,
      );

      await controller.connectDevice();
      final tapped = await controller.tapViewportFraction(
        xRatio: 0.5,
        yRatio: 0.25,
      );
      await controller.dispose();
      await server.close(force: true);

      expect(tapped, isTrue);
      expect(deviceActions.calls, [
        'viewport:runtime-session',
        'tap:预览点击:200,200:80',
        'release',
      ]);
    },
  );
  test(
    'runtime controller releases preview actions after failed tap',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor(
        viewportSize: const ViewportSize(width: 400, height: 800),
        failingTapLabels: {'预览点击'},
      );
      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: _fakeDeviceSessionConfig,
        ),
        deviceActions: deviceActions,
      );

      await controller.connectDevice();
      final tapped = await controller.tapViewportFraction(
        xRatio: 0.5,
        yRatio: 0.25,
      );
      await controller.dispose();
      await server.close(force: true);

      expect(tapped, isFalse);
      expect(deviceActions.calls, [
        'viewport:runtime-session',
        'tap:预览点击:200,200:80',
        'release',
      ]);
      final messages = controller.snapshot.events
          .map((event) => event.message)
          .join('\n');
      expect(messages, contains('预览点击失败：'));
    },
  );
  test(
    'runtime controller swipes device preview through viewport size',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor(
        viewportSize: const ViewportSize(width: 400, height: 800),
      );
      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: _fakeDeviceSessionConfig,
        ),
        deviceActions: deviceActions,
      );

      await controller.connectDevice();
      final swiped = await controller.swipeViewportFractions(
        fromXRatio: 0.25,
        fromYRatio: 0.75,
        toXRatio: 0.75,
        toYRatio: 0.25,
      );
      await controller.dispose();
      await server.close(force: true);

      expect(swiped, isTrue);
      expect(deviceActions.calls, [
        'viewport:runtime-session',
        'swipe:预览滑动:100,600->300,200:450',
        'release',
      ]);
    },
  );
  test(
    'runtime controller pinches device preview through viewport size',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor(
        viewportSize: const ViewportSize(width: 400, height: 800),
      );
      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: _fakeDeviceSessionConfig,
        ),
        deviceActions: deviceActions,
      );

      await controller.connectDevice();
      final expanded = await controller.pinchViewport(expand: true);
      final shrunk = await controller.pinchViewport(expand: false);
      await controller.dispose();
      await server.close(force: true);

      expect(expanded, isTrue);
      expect(shrunk, isTrue);
      expect(deviceActions.calls, [
        'viewport:runtime-session',
        'pinch:预览放大:176,400->96,400|224,400->304,400:420',
        'release',
        'viewport:runtime-session',
        'pinch:预览缩小:96,400->176,400|304,400->224,400:420',
        'release',
      ]);
    },
  );
  test(
    'runtime controller double taps device preview through viewport size',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor(
        viewportSize: const ViewportSize(width: 400, height: 800),
      );
      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: _fakeDeviceSessionConfig,
        ),
        deviceActions: deviceActions,
      );

      await controller.connectDevice();
      final doubleTapped = await controller.doubleTapViewportFraction(
        xRatio: 0.5,
        yRatio: 0.25,
      );
      await controller.dispose();
      await server.close(force: true);

      expect(doubleTapped, isTrue);
      expect(deviceActions.calls, [
        'viewport:runtime-session',
        'tap:预览双击:200,200:80',
        'tap:预览双击:200,200:80',
        'release',
      ]);
    },
  );
  test(
    'runtime controller long presses device preview through viewport size',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor(
        viewportSize: const ViewportSize(width: 400, height: 800),
      );
      final controller = StudioRuntimeController(
        sessionManager: DeviceSessionManager(
          client: AppiumClient(config: AppiumServerConfig(port: server.port)),
          config: _fakeDeviceSessionConfig,
        ),
        deviceActions: deviceActions,
      );

      await controller.connectDevice();
      final longPressed = await controller.longPressViewportFraction(
        xRatio: 0.5,
        yRatio: 0.25,
      );
      await controller.dispose();
      await server.close(force: true);

      expect(longPressed, isTrue);
      expect(deviceActions.calls, [
        'viewport:runtime-session',
        'tap:预览长按:200,200:650',
        'release',
      ]);
    },
  );
  test('runtime controller inputs focused text from device preview', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: DeviceSessionManager(
        client: AppiumClient(config: AppiumServerConfig(port: server.port)),
        config: _fakeDeviceSessionConfig,
      ),
      deviceActions: deviceActions,
    );

    await controller.connectDevice();
    final inputSent = await controller.inputFocusedText(text: '  hello  ');
    await controller.dispose();
    await server.close(force: true);

    expect(inputSent, isTrue);
    expect(deviceActions.calls, ['input:预览输入:5']);
    final messages = controller.snapshot.events
        .map((event) => event.message)
        .join('\n');
    expect(messages, contains('发送输入。'));
    expect(messages, contains('输入完成：5 字。'));
    expect(messages, isNot(contains('hello')));
  });

  test('runtime controller presses home button while idle', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: DeviceSessionManager(
        client: AppiumClient(config: AppiumServerConfig(port: server.port)),
        config: _fakeDeviceSessionConfig,
      ),
      deviceActions: deviceActions,
    );

    await controller.connectDevice();
    final pressed = await controller.pressHomeButton();
    await controller.dispose();
    await server.close(force: true);

    expect(pressed, isTrue);
    expect(deviceActions.calls, ['button:回主页']);
    final messages = controller.snapshot.events
        .map((event) => event.message)
        .join('\n');
    expect(messages, contains('发送主页键。'));
    expect(messages, contains('已回主页。'));
  });

  test('runtime controller refuses screenshot while disconnected', () async {
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(deviceActions: deviceActions);

    final screenshot = await controller.captureScreenshot(reason: 'test');
    await controller.dispose();

    expect(screenshot, isNull);
    expect(deviceActions.calls, isEmpty);
    expect(controller.snapshot.events.last.message, '请先连接设备再截图。');
  });
}
