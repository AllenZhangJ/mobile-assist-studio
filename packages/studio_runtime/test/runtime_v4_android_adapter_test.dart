import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

import 'support/runtime_test_harness.dart';

// V4 Android adapter 回归。
// 测试使用 fake ADB 和 fake Appium，不连接真实 Android 手机。
void main() {
  test('ADB discovery parses ready devices and sanitizes logcat', () async {
    final calls = <String>[];
    final discovery = AdbAndroidDeviceDiscovery(
      runner: (executable, arguments) async {
        calls.add('$executable ${arguments.join(' ')}');
        if (arguments.length == 2 && arguments.first == 'devices') {
          return ProcessResult(
            42,
            0,
            [
              'List of devices attached',
              'ZY22ABCDEF device product:oriole model:Pixel_9 release:15 transport_id:1',
              'BADDEVICE unauthorized transport_id:2',
            ].join('\n'),
            '',
          );
        }
        if (arguments.contains('logcat')) {
          return ProcessResult(
            42,
            0,
            'W/App: device ZY22ABCDEF wrote /Users/local/file\n',
            '',
          );
        }
        return ProcessResult(42, 1, '', 'unexpected command');
      },
    );

    final result = await discovery.discover();
    final logs = await discovery.collectLogcat(serial: 'ZY22ABCDEF');

    expect(result.devices, hasLength(2));
    expect(result.readyDevices.single.displayName, 'Pixel 9');
    expect(result.readyDevices.single.maskedSerial, 'ZY22...CDEF');
    expect(result.devices.last.state, AndroidAdbDeviceState.unauthorized);
    expect(logs.single, contains('[设备]'));
    expect(logs.single, contains('[本机路径]'));
    expect(logs.single, isNot(contains('ZY22ABCDEF')));
    expect(calls, contains('adb devices -l'));
  });

  test(
    'Android Appium driver creates UiAutomator2 session and runs actions',
    () async {
      final requests = <String>[];
      Map<String, Object?>? sessionPayload;
      Map<String, Object?>? homePayload;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final subscription = server.listen((request) async {
        requests.add('${request.method} ${request.uri.path}');
        if (request.method == 'POST' && request.uri.path == '/session') {
          sessionPayload =
              jsonDecode(await utf8.decodeStream(request))
                  as Map<String, Object?>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'value': {
                  'sessionId': 'android-session',
                  'capabilities': {'platformName': 'Android'},
                },
              }),
            )
            ..close();
          return;
        }
        if (request.method == 'POST' &&
            request.uri.path ==
                '/session/android-session/appium/device/press_keycode') {
          homePayload =
              jsonDecode(await utf8.decodeStream(request))
                  as Map<String, Object?>;
          request.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'value': null}))
            ..close();
          return;
        }
        if (request.method == 'DELETE' &&
            request.uri.path == '/session/android-session') {
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

      final client = AppiumClient(
        config: AppiumServerConfig(port: server.port),
      );
      final actions = FakeDeviceActionExecutor(pageSourceXml: '<hierarchy />');
      final discovery = _FakeAndroidDiscovery(
        const AndroidAdbDiscovery(
          devices: [
            AndroidAdbDevice(
              serial: 'ZY22ABCDEF',
              state: AndroidAdbDeviceState.ready,
              model: 'Pixel_9',
              androidVersion: '15',
            ),
          ],
        ),
        logs: const ['W/App: 脱敏日志'],
      );
      final driver = AndroidAppiumMobileDriver(
        discovery: discovery,
        client: client,
        deviceActions: actions,
        baseCapabilities: const {'appium:appPackage': 'com.example'},
      );

      final capabilities = await driver.capabilityReport();
      final discovered = await driver.discoverCurrentDevice();
      final session = await driver.connect();
      final heartbeat = await driver.heartbeat();
      final screenshot = await driver.captureScreenshot();
      final source = await driver.getPageSource();
      await driver.tap(const ViewportPoint(x: 18, y: 24));
      await driver.swipe(
        const ViewportPoint(x: 10, y: 300),
        const ViewportPoint(x: 10, y: 80),
        duration: const Duration(milliseconds: 320),
      );
      await driver.inputText('hello');
      final logs = await driver.collectLogs();
      await driver.launchApp('com.example');
      await driver.stopApp('com.example');
      await driver.pressHome();
      await driver.releaseActions();
      await driver.disconnect();

      final alwaysMatch =
          (sessionPayload?['capabilities']
                  as Map<String, Object?>)['alwaysMatch']
              as Map<String, Object?>;

      expect(capabilities.supportsCoreActions, isTrue);
      expect(capabilities.appLifecycle, isTrue);
      expect(capabilities.logs, isTrue);
      expect(discovered?.displayName, 'Pixel 9');
      expect(discovered?.maskedIdentifier, 'ZY22...CDEF');
      expect(session.sessionId, 'android-session');
      expect(session.device?.maskedIdentifier, 'ZY22...CDEF');
      expect(heartbeat.ready, isTrue);
      expect(screenshot.base64Png, 'base64-screenshot');
      expect(source, '<hierarchy />');
      expect(logs, ['W/App: 脱敏日志']);
      expect(alwaysMatch['platformName'], 'Android');
      expect(alwaysMatch['appium:automationName'], 'UiAutomator2');
      expect(alwaysMatch['appium:udid'], 'ZY22ABCDEF');
      expect(alwaysMatch['appium:platformVersion'], '15');
      expect(alwaysMatch['appium:appPackage'], 'com.example');
      expect(actions.calls, contains('tap:安卓点按:18,24:80'));
      expect(actions.calls, contains('swipe:安卓滑动:10,300->10,80:320'));
      expect(actions.calls, contains('input:安卓输入:5'));
      expect(actions.calls, contains('launch:com.example'));
      expect(actions.calls, contains('stop:com.example'));
      expect(actions.calls, contains('release'));
      expect(homePayload, {'keycode': 3});
      expect(requests, [
        'POST /session',
        'POST /session/android-session/appium/device/press_keycode',
        'DELETE /session/android-session',
      ]);

      client.close(force: true);
      await subscription.cancel();
      await server.close(force: true);
    },
  );

  test(
    'Android driver blocks unauthorized devices before Appium session',
    () async {
      final driver = AndroidAppiumMobileDriver(
        discovery: _FakeAndroidDiscovery(
          const AndroidAdbDiscovery(
            devices: [
              AndroidAdbDevice(
                serial: 'LOCKED',
                state: AndroidAdbDeviceState.unauthorized,
              ),
            ],
          ),
        ),
        client: AppiumClient(
          config: const AppiumServerConfig(timeout: Duration(milliseconds: 50)),
        ),
      );

      await expectLater(
        driver.connect(),
        throwsA(
          isA<AndroidDeviceDiscoveryException>().having(
            (error) => error.summary,
            'summary',
            '安卓手机未授权。',
          ),
        ),
      );
    },
  );
}

// Android 设备发现 fake，避免测试访问真实 ADB。
final class _FakeAndroidDiscovery implements AndroidDeviceDiscovery {
  _FakeAndroidDiscovery(this.discovery, {this.logs = const <String>[]});

  final AndroidAdbDiscovery discovery;
  final List<String> logs;

  @override
  Future<List<String>> collectLogcat({
    required String serial,
    int maxLines = 120,
  }) async {
    return logs.take(maxLines).toList(growable: false);
  }

  @override
  Future<AndroidAdbDiscovery> discover() async {
    return discovery;
  }
}
