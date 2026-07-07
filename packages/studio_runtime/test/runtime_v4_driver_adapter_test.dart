import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

import 'support/runtime_test_harness.dart';

// V4 driver adapter 回归。
// 测试只使用 fake session 和 fake 动作，不连接真实 Appium 或手机。
void main() {
  test('iOS Appium driver wraps current session and device actions', () async {
    final sessionManager = SequencedSessionManager([
      const WebDriverSession(
        id: 'ios-session',
        capabilities: {'platformName': 'iOS'},
      ),
    ]);
    final actions = FakeDeviceActionExecutor(pageSourceXml: '<App />');
    final driver = IosAppiumMobileDriver(
      sessionManager: sessionManager,
      deviceActions: actions,
      device: const MobileDeviceSummary(
        platform: MobilePlatform.ios,
        displayName: 'iPhone',
        maskedIdentifier: 'device...',
        osVersion: '18',
        connectionKind: MobileConnectionKind.usb,
      ),
    );

    final capabilities = await driver.capabilityReport();
    final session = await driver.connect();
    final heartbeat = await driver.heartbeat();
    final screenshot = await driver.captureScreenshot();
    final source = await driver.getPageSource();
    await driver.tap(const ViewportPoint(x: 12, y: 24));
    await driver.swipe(
      const ViewportPoint(x: 10, y: 20),
      const ViewportPoint(x: 10, y: 100),
      duration: const Duration(milliseconds: 250),
    );
    await driver.inputText('secret');
    await driver.pressHome();
    await driver.releaseActions();

    expect(capabilities.supportsCoreActions, isTrue);
    expect(session.sessionId, 'ios-session');
    expect(session.device?.maskedIdentifier, 'device...');
    expect(heartbeat.ready, isTrue);
    expect(screenshot.base64Png, 'base64-screenshot');
    expect(screenshot.viewport?.width, 390);
    expect(source, '<App />');
    expect(actions.calls, contains('tap:移动点按:12,24:80'));
    expect(actions.calls, contains('swipe:移动滑动:10,20->10,100:250'));
    expect(actions.calls, contains('input:移动输入:6'));
    expect(actions.calls, contains('button:回主页'));
    expect(actions.calls, contains('release'));
  });
}
