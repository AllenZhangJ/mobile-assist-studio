import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

import 'support/runtime_test_harness.dart';

// Runtime Inspector 回归测试。
// 用例只访问 fake session 和 fake 设备动作，不连接真实手机或 Appium。
void main() {
  test('inspector source parser builds sanitized element tree', () {
    final parsed = const InspectorSourceParser().parse('''
<hierarchy>
  <node class="android.widget.FrameLayout" bounds="[0,0][390,844]">
    <node class="android.widget.EditText" text="secret-value" password="true" bounds="[10,20][200,72]" focused="true" resource-id="com.demo:id/password" />
    <node class="android.widget.Button" text="登录" clickable="true" bounds="[10,90][120,150]" />
  </node>
</hierarchy>
''');

    expect(parsed.elementCount, 4);
    expect(parsed.root?.type, 'hierarchy');
    final frame = parsed.root!.children.single;
    expect(frame.type, 'FrameLayout');
    expect(frame.bounds?.width, 390);
    final input = frame.children.first;
    expect(input.type, 'EditText');
    expect(input.value, '已隐藏');
    expect(input.attributes, containsPair('focused', 'true'));
    expect(input.attributes.containsKey('resource-id'), isFalse);
    expect(parsed.preview, contains('Button'));
    expect(parsed.preview, isNot(contains('resource-id')));
  });

  test('runtime inspector captures screenshot source and snapshot', () async {
    final actions = FakeDeviceActionExecutor(
      screenshotBase64: 'fake-png',
      pageSourceXml: '''
<hierarchy>
  <node class="android.widget.FrameLayout" bounds="[0,0][390,844]">
    <node class="android.widget.Button" text="开始" clickable="true" bounds="[20,40][120,88]" />
  </node>
</hierarchy>
''',
    );
    final controller = StudioRuntimeController(
      sessionManager: SequencedSessionManager([
        const WebDriverSession(
          id: 'session-1',
          capabilities: {'platformName': 'Android'},
        ),
      ]),
      deviceActions: actions,
    );

    await controller.connectDevice();
    final snapshot = await controller.inspectCurrentScreen(reason: 'test');

    expect(snapshot, isNotNull);
    expect(
      actions.calls,
      containsAllInOrder(['screenshot', 'source:session-1']),
    );
    expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
    expect(controller.snapshot.latestScreenshotBase64, 'fake-png');
    expect(controller.snapshot.inspectorSnapshot?.elementCount, 3);
    expect(
      controller.snapshot.inspectorSnapshot?.rootElement?.type,
      'hierarchy',
    );
    expect(controller.snapshot.inspectorSnapshot?.sourceSummary, '已识别 3 个元素。');
    expect(
      controller.snapshot.events.map((event) => event.message),
      containsAllInOrder(['正在检查界面：test。', '界面检查完成。']),
    );
  });

  test('runtime inspector blocks when device is not connected', () async {
    final actions = FakeDeviceActionExecutor(pageSourceXml: '<hierarchy />');
    final controller = StudioRuntimeController(deviceActions: actions);

    final snapshot = await controller.inspectCurrentScreen();

    expect(snapshot, isNull);
    expect(actions.calls, isEmpty);
    expect(controller.snapshot.inspectorSnapshot, isNull);
    expect(controller.snapshot.events.last.message, '请先连接设备再检查。');
  });

  test('runtime inspector failure keeps connection usable', () async {
    final controller = StudioRuntimeController(
      sessionManager: SequencedSessionManager([
        const WebDriverSession(
          id: 'session-1',
          capabilities: {'platformName': 'Android'},
        ),
      ]),
      deviceActions: _FailingSourceActions(),
    );

    await controller.connectDevice();
    final snapshot = await controller.inspectCurrentScreen();

    expect(snapshot, isNull);
    expect(controller.snapshot.connectionStatus, ConnectionStatus.connected);
    expect(controller.snapshot.inspectorSnapshot, isNull);
    expect(
      controller.snapshot.mobileRuntime.resourceState,
      MobileResourceState.idle,
    );
    expect(controller.snapshot.events.last.message, contains('界面检查失败'));
  });
}

// page source 失败 fake，用于验证 Inspector 失败不污染连接主状态。
final class _FailingSourceActions implements DeviceActionExecutor {
  @override
  Future<String> screenshot(String sessionId) async => 'fake-png';

  @override
  Future<String> pageSource(String sessionId) async {
    throw StateError('source failed');
  }

  @override
  Future<ViewportSize> viewportSize(String sessionId) async {
    return const ViewportSize(width: 390, height: 844);
  }

  @override
  Future<void> tap(String sessionId, RuntimeTap tap) async {}

  @override
  Future<void> swipe(String sessionId, RuntimeSwipe swipe) async {}

  @override
  Future<void> pinch(String sessionId, RuntimePinch pinch) async {}

  @override
  Future<void> inputText(String sessionId, RuntimeInput input) async {}

  @override
  Future<void> launchApp(String sessionId, String appId) async {}

  @override
  Future<void> stopApp(String sessionId, String appId) async {}

  @override
  Future<void> pressButton(
    String sessionId,
    RuntimeDeviceButton button,
  ) async {}

  @override
  Future<void> releaseActions(String sessionId) async {}
}
