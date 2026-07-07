import 'package:appium_client/appium_client.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';

import 'support/studio_widget_harness.dart';

// Device Preview 回归测试，聚焦手机预览中的安全手势与输入。
// 这里不连接真实设备，只验证 Flutter UI 到 Runtime 设备动作的参数边界。
void main() {
  testWidgets('device preview sends guarded viewport tap', (tester) async {
    final preview = await _pumpPreviewDevice(tester);

    expect(find.text('有预览'), findsOneWidget);
    expect(find.text('可操作'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('device-preview-tap-target')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(
      find.byKey(const ValueKey('device-preview-tap-marker')),
      findsOneWidget,
    );

    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, [
      'screenshot',
      'viewport:runtime-session',
      'tap:预览点击:200,400:80',
      'release',
    ]);
  });

  testWidgets('device preview sends guarded viewport double tap', (
    tester,
  ) async {
    final preview = await _pumpPreviewDevice(tester);

    final previewTarget = find.byKey(
      const ValueKey('device-preview-tap-target'),
    );
    await tester.tap(previewTarget);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tap(previewTarget);
    await tester.pump();

    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, [
      'screenshot',
      'viewport:runtime-session',
      'tap:预览双击:200,400:80',
      'tap:预览双击:200,400:80',
      'release',
    ]);
  });

  testWidgets('device preview sends guarded viewport long press', (
    tester,
  ) async {
    final preview = await _pumpPreviewDevice(tester);

    final previewTarget = find.byKey(
      const ValueKey('device-preview-tap-target'),
    );
    await tester.longPress(previewTarget);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('device-preview-tap-marker')),
      findsOneWidget,
    );

    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, [
      'screenshot',
      'viewport:runtime-session',
      'tap:预览长按:200,400:650',
      'release',
    ]);
  });

  testWidgets('device preview sends guarded viewport swipe', (tester) async {
    final preview = await _pumpPreviewDevice(tester);

    expect(find.text('可操作'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('device-preview-tap-target')),
      const Offset(80, -80),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('device-preview-swipe-line')),
      findsOneWidget,
    );

    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, hasLength(4));
    expect(preview.deviceActions.calls[0], 'screenshot');
    expect(preview.deviceActions.calls[1], 'viewport:runtime-session');
    expect(preview.deviceActions.calls[2], startsWith('swipe:预览滑动:'));
    expect(preview.deviceActions.calls[2], endsWith(':450'));
    expect(preview.deviceActions.calls[3], 'release');
  });

  testWidgets('device preview turns scroll into guarded viewport swipe', (
    tester,
  ) async {
    final preview = await _pumpPreviewDevice(tester);

    final previewTarget = find.byKey(
      const ValueKey('device-preview-tap-target'),
    );
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: tester.getCenter(previewTarget),
        scrollDelta: const Offset(0, 120),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('device-preview-swipe-line')),
      findsOneWidget,
    );

    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, [
      'screenshot',
      'viewport:runtime-session',
      'swipe:预览滚动:200,544->200,256:260',
      'release',
    ]);
  });

  testWidgets('device preview arrow keys send guarded viewport swipe', (
    tester,
  ) async {
    final preview = await _pumpPreviewDevice(tester);

    final focus = tester.widget<Focus>(
      find.byKey(const ValueKey('device-preview-keyboard-focus')),
    );
    focus.focusNode!.requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('device-preview-swipe-line')),
      findsOneWidget,
    );

    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, [
      'screenshot',
      'viewport:runtime-session',
      'swipe:键盘上滑:200,544->200,256:320',
      'release',
    ]);
  });

  testWidgets('device preview zoom controls stay display-only', (tester) async {
    final preview = await _pumpPreviewDevice(tester);

    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('放大'));
    await tester.pumpAndSettle();
    expect(find.text('125%'), findsOneWidget);

    await tester.tap(find.byTooltip('缩小'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byTooltip('放大'));
    await tester.tap(find.byTooltip('放大'));
    await tester.pumpAndSettle();
    expect(find.text('150%'), findsOneWidget);

    await tester.tap(find.byTooltip('还原'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(preview.deviceActions.calls, ['screenshot']);
  });

  testWidgets('device preview sends guarded pinch gestures', (tester) async {
    final preview = await _pumpPreviewDevice(tester);

    expect(find.text('手势'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('device-preview-pinch-out')));
    await _settleAsyncGesture(tester);
    await tester.tap(find.byKey(const ValueKey('device-preview-pinch-in')));
    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, [
      'screenshot',
      'viewport:runtime-session',
      'pinch:预览放大:176,400->96,400|224,400->304,400:420',
      'release',
      'viewport:runtime-session',
      'pinch:预览缩小:96,400->176,400|304,400->224,400:420',
      'release',
    ]);
  });

  testWidgets('device preview sends focused input only while idle', (
    tester,
  ) async {
    final preview = await _pumpPreviewDevice(tester);

    final input = find.byKey(const ValueKey('device-preview-input-field'));
    await tester.enterText(input, 'hello');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('device-preview-input-send')));
    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, ['screenshot', 'input:预览输入:5']);
    expect(find.text('hello'), findsNothing);
  });

  testWidgets('device preview sends guarded home button', (tester) async {
    final preview = await _pumpPreviewDevice(tester);

    expect(find.text('主页'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('device-preview-home-button')));
    await tester.pump();

    await _settleAsyncGesture(tester);

    expect(preview.deviceActions.calls, ['screenshot', 'button:回主页']);
  });
}

// 构造已连接且有截图的 Device Preview 页面，统一手势测试前置状态。
Future<_PreviewDeviceHarness> _pumpPreviewDevice(
  WidgetTester tester, {
  Size size = const Size(1200, 1000),
}) async {
  await useDesktopSurface(tester, size: size);
  final deviceActions = FakePreviewDeviceActionExecutor(
    screenshotBase64: onePixelPngBase64,
    viewportSize: const ViewportSize(width: 400, height: 800),
  );
  final controller = StudioRuntimeController(
    sessionManager: FakeDeviceSessionManager('runtime-session'),
    deviceActions: deviceActions,
  );
  await controller.connectDevice();
  await controller.captureScreenshot(reason: 'widget-test');

  await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));
  await tester.tap(find.byKey(const ValueKey('nav-设备')));
  await tester.pumpAndSettle();

  return _PreviewDeviceHarness(deviceActions: deviceActions);
}

// 等待 Runtime 异步手势结算，避免断言早于设备动作回调。
Future<void> _settleAsyncGesture(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await tester.pumpAndSettle();
}

// Device Preview 测试夹具，只暴露断言需要的 fake 设备动作。
final class _PreviewDeviceHarness {
  const _PreviewDeviceHarness({required this.deviceActions});

  final FakePreviewDeviceActionExecutor deviceActions;
}
