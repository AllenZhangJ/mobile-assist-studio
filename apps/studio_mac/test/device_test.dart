import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appium_client/appium_client.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Device 页面回归测试，聚焦设备摘要、就绪检查和本机指引。
// 预览手势单独放在 device_preview_test.dart，避免页面测试继续膨胀。
void main() {
  testWidgets('renders device preview controls', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 2600));
    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(find.text('设备'), findsWidgets);
    expect(find.text('就绪检查'), findsOneWidget);
    expect(find.text('驱动服务'), findsWidgets);
    expect(find.text('手机'), findsOneWidget);
    expect(find.text('无预览'), findsWidgets);
    expect(find.text('截图'), findsWidgets);
    expect(find.byIcon(Icons.phone_iphone_outlined), findsWidgets);
  });

  testWidgets(
    'device target library creates coordinate target from screenshot',
    (tester) async {
      await useDesktopSurface(tester, size: const Size(1400, 1800));
      final screenshotBase64 = await testPngBase64(width: 400, height: 800);
      final actions = FakePreviewDeviceActionExecutor(
        screenshotBase64: screenshotBase64,
        viewportSize: const ViewportSize(width: 400, height: 800),
      );
      final controller = StudioRuntimeController(
        sessionManager: FakeDeviceSessionManager('target-session'),
        deviceActions: actions,
      );
      await controller.connectDevice();
      await controller.captureScreenshot(reason: 'device-target');

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );
      await tester.tap(find.byKey(const ValueKey('nav-设备')));
      await tester.pumpAndSettle();

      final createButton = find.byKey(
        const ValueKey('device-create-center-target'),
      );
      final deviceScroll = find.byKey(const ValueKey('device-side-scroll'));
      await tester.dragUntilVisible(
        createButton,
        deviceScroll,
        const Offset(0, -360),
        maxIteration: 12,
      );
      await tester.ensureVisible(createButton);
      await tester.pumpAndSettle();

      expect(find.text('目标库'), findsOneWidget);
      expect(find.text('0 个'), findsOneWidget);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      final target = controller.snapshot.targetLibrary.targets.single;
      expect(target.label, '画面中心 1');
      expect(target.kind, RuntimeTargetKind.coordinate);
      expect(target.payload['x'], 200);
      expect(target.payload['y'], 400);
      expect(target.payload['viewportWidth'], 400);
      expect(target.payload['viewportHeight'], 800);
      expect(controller.snapshot.targetLibrary.issues, isEmpty);
      expect(actions.calls, ['screenshot']);
      expect(find.text('目标已存。'), findsOneWidget);
    },
  );

  testWidgets('device target library tests image target safely', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1800));
    final screenshotBase64 = await testPngBase64(width: 4, height: 4);
    final templateBase64 = await testPngBase64(width: 1, height: 1);
    final actions = FakePreviewDeviceActionExecutor(
      screenshotBase64: screenshotBase64,
      viewportSize: const ViewportSize(width: 4, height: 4),
    );
    final controller = StudioRuntimeController(
      sessionManager: FakeDeviceSessionManager('image-target-session'),
      deviceActions: actions,
      targets: [
        RuntimeTargetDefinition(
          id: 'login_image',
          kind: RuntimeTargetKind.image,
          label: '登录图',
          payload: <String, Object?>{
            'imageRef': 'targets/images/login.png',
            'imageBase64': templateBase64,
          },
        ),
      ],
    );
    await controller.connectDevice();
    await controller.captureScreenshot(reason: 'image-target-test');

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));
    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    final testButton = find.byKey(
      const ValueKey('device-test-target-login_image'),
    );
    await tester.dragUntilVisible(
      testButton,
      find.byKey(const ValueKey('device-side-scroll')),
      const Offset(0, -360),
      maxIteration: 12,
    );
    await tester.ensureVisible(testButton);
    await tester.pumpAndSettle();

    expect(find.text('登录图'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
    await tester.tap(testButton);
    await tester.pumpAndSettle();

    expect(find.text('已找到。'), findsOneWidget);
    expect(actions.calls, ['screenshot']);
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('已找到目标：登录图。'),
    );
  });

  testWidgets('device inspector reads source through runtime', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 2200));
    final actions = FakePreviewDeviceActionExecutor(
      screenshotBase64: onePixelPngBase64,
      viewportSize: const ViewportSize(width: 390, height: 844),
      pageSourceXml: '''
<hierarchy>
  <node class="android.widget.FrameLayout" bounds="[0,0][390,844]">
    <node class="android.widget.Button" text="开始" clickable="true" bounds="[20,40][120,88]" />
  </node>
</hierarchy>
''',
    );
    final controller = StudioRuntimeController(
      sessionManager: FakeDeviceSessionManager('inspect-session'),
      deviceActions: actions,
    );
    await controller.connectDevice();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));
    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('device-inspector-refresh')),
      find.byKey(const ValueKey('device-side-scroll')),
      const Offset(0, -240),
    );
    await tester.tap(find.byKey(const ValueKey('device-inspector-refresh')));
    await tester.pumpAndSettle();

    expect(
      actions.calls,
      containsAllInOrder(['screenshot', 'source:inspect-session']),
    );
    expect(find.text('已识别 3 个元素。'), findsOneWidget);
    expect(find.text('元素树'), findsOneWidget);
    expect(find.text('源码'), findsOneWidget);
    expect(find.textContaining('Button'), findsWidgets);
    expect(find.textContaining('inspect-session'), findsNothing);
    expect(find.textContaining('resource-id'), findsNothing);

    final targetButton = find.byKey(
      const ValueKey('device-inspector-suggest-target'),
    );
    await tester.dragUntilVisible(
      targetButton,
      find.byKey(const ValueKey('device-side-scroll')),
      const Offset(0, -180),
      maxIteration: 8,
    );
    await tester.ensureVisible(targetButton);
    await tester.pumpAndSettle();
    await tester.tap(targetButton);
    await tester.pumpAndSettle();

    expect(find.text('智能建议'), findsOneWidget);
    expect(find.textContaining('已基于当前检查结果生成草稿'), findsOneWidget);
    expect(find.textContaining('开始 · 选择'), findsOneWidget);
    expect(controller.snapshot.targetLibrary.count, 0);
    expect(controller.snapshot.aiAuditLog.single.toolId, 'suggestTarget');

    await tester.tap(
      find.byKey(const ValueKey('device-inspector-suggest-locator')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('开始 · label=开始'), findsOneWidget);
    expect(controller.snapshot.targetLibrary.count, 0);
    expect(controller.snapshot.aiAuditLog.last.toolId, 'suggestLocator');
    expect(
      actions.calls,
      containsAllInOrder(['screenshot', 'source:inspect-session']),
    );

    final createTapButton = find.byKey(
      const ValueKey('device-inspector-create-tap-node'),
    );
    await tester.dragUntilVisible(
      createTapButton,
      find.byKey(const ValueKey('device-side-scroll')),
      const Offset(0, -180),
      maxIteration: 8,
    );
    await tester.ensureVisible(createTapButton);
    await tester.pumpAndSettle();
    await tester.tap(createTapButton);
    await tester.pumpAndSettle();

    final target = controller.snapshot.targetLibrary.targets.single;
    expect(target.kind, RuntimeTargetKind.selector);
    expect(target.label, '开始');
    expect(target.payload['selector'], 'label=开始');
    final generatedNodes = controller.snapshot.workflow.nodes
        .where((node) => node.parameters['targetRef'] == target.id)
        .toList(growable: false);
    expect(generatedNodes, hasLength(1));
    expect(generatedNodes.single.type, WorkflowNodeType.tap);
    expect(generatedNodes.single.label, '点开始');
    expect(
      find.byKey(const ValueKey('workflow-visual-canvas')),
      findsOneWidget,
    );
    expect(find.text('已加到流程。'), findsOneWidget);
  });

  testWidgets('device readiness guide summarizes connected local stack', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1200, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
      sessionId: 'redacted-session-placeholder-2',
      latestScreenshotAt: DateTime(2026, 1, 7, 3, 4, 5),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(find.text('就绪检查'), findsOneWidget);
    expect(find.text('6/6 就绪'), findsOneWidget);
    expect(find.text('驱动服务'), findsWidgets);
    expect(find.text('手机'), findsOneWidget);
    expect(find.text('开发者信任'), findsOneWidget);
    expect(find.text('手机会话'), findsOneWidget);
    expect(find.text('安全截图'), findsOneWidget);
    expect(find.text('流程文件'), findsOneWidget);
    expect(find.text('redacted-session-placeholder-2'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.textContaining('/session'), findsNothing);
  });

  testWidgets('device readiness guide uses project workflow validation', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1200, 1000));
    final workflow = missingSubWorkflowDefinition();
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
      sessionId: 'redacted-session-placeholder-3',
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(find.text('5/6 就绪'), findsOneWidget);
    expect(find.text('流程文件'), findsOneWidget);
    expect(find.text('流程需先修正。'), findsOneWidget);
    expect(find.text('redacted-session-placeholder-3'), findsNothing);
  });

  testWidgets('device readiness guide turns trust into operator action', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1200, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.waitingForDeveloperTrust,
      appiumStatus: AppiumProcessStatus.running,
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(find.text('需要信任'), findsWidgets);
    expect(find.text('开发者信任'), findsOneWidget);
    expect(find.text('操作'), findsOneWidget);
    expect(find.textContaining('信任证书'), findsOneWidget);
    expect(find.text('受阻'), findsOneWidget);
  });

  testWidgets('device readiness guide tells how to recover driver offline', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1200, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      appiumStatus: AppiumProcessStatus.stopped,
      appiumMessage: '未发现本机驱动。请点连接设备；若仍失败，点查环境。',
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(find.text('驱动服务'), findsWidgets);
    expect(find.text('离线'), findsWidgets);
    expect(find.text('点连接设备。'), findsWidgets);
    expect(find.textContaining('Unable to reach'), findsNothing);
  });

  testWidgets('device page disables stop action for external driver', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      appiumStatus: AppiumProcessStatus.running,
      appiumOwnership: AppiumProcessOwnership.external,
      appiumMessage: '驱动已就绪。外部启动。',
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();
    final stopButton = find.byKey(const ValueKey('device-stop-driver'));
    final deviceScroll = find.byKey(const ValueKey('device-side-scroll'));
    await tester.dragUntilVisible(
      stopButton,
      deviceScroll,
      const Offset(0, -360),
      maxIteration: 12,
    );
    await tester.ensureVisible(stopButton);
    await tester.pumpAndSettle();

    final stop = tester.widget<FilledButton>(stopButton);
    expect(stop.onPressed, isNull);
    expect(find.text('外部驱动可直接使用。'), findsOneWidget);
  });

  testWidgets('device primary connection locks disruptive actions while busy', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connecting,
      appiumStatus: AppiumProcessStatus.running,
      appiumMessage: '正在连接设备。',
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    final deviceScroll = find.byKey(const ValueKey('device-side-scroll'));
    final connectButton = find.byKey(
      const ValueKey('device-connect-one-button'),
    );
    await tester.dragUntilVisible(
      connectButton,
      deviceScroll,
      const Offset(0, -360),
      maxIteration: 12,
    );
    await tester.ensureVisible(connectButton);
    await tester.pumpAndSettle();

    expect(find.text('连接中'), findsWidgets);
    expect(find.text('请稍等，正在自动处理。'), findsOneWidget);
    expect(find.text('按提示输入密码，应用会自动连接。'), findsOneWidget);

    final connect = tester.widget<FilledButton>(connectButton);
    final check = tester.widget<FilledButton>(
      find.byKey(const ValueKey('check-local-stack')),
    );
    final stop = tester.widget<FilledButton>(
      find.byKey(const ValueKey('device-stop-driver')),
    );
    final bind = tester.widget<FilledButton>(
      find.byKey(const ValueKey('device-bind-usb')),
    );

    expect(connect.onPressed, isNull);
    expect(check.onPressed, isNull);
    expect(stop.onPressed, isNull);
    expect(bind.onPressed, isNull);
  });

  testWidgets('device page surfaces structured connection diagnostic', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1000));
    final copiedText = captureClipboardText();
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.error,
      appiumStatus: AppiumProcessStatus.running,
      appiumMessage: '手机会话启动失败。',
      lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
        type: RuntimeConnectionIssueType.wdaStartFailed,
        status: ConnectionStatus.error,
        summary: '手机会话启动失败。',
        nextStep: '确认已解锁和已信任，再点连接设备。',
        detail: 'driver returned HTTP 500 for [local-url].',
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connection-diagnostic-card')),
      findsOneWidget,
    );
    expect(find.text('连接受阻'), findsOneWidget);
    expect(find.text('会话'), findsWidgets);
    expect(find.text('手机会话启动失败。'), findsWidgets);
    expect(find.text('确认已解锁和已信任，再点连接设备。'), findsWidgets);
    expect(find.textContaining('HTTP 500'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('copy-connection-diagnostic')));
    await tester.pumpAndSettle();

    expect(copiedText(), contains('连接诊断'));
    expect(copiedText(), contains('问题：会话'));
    expect(copiedText(), contains('状态：手机会话启动失败。'));
    expect(copiedText(), contains('下一步：确认已解锁和已信任，再点连接设备。'));
    expect(copiedText(), contains('边界：本机、单设备、串行'));
    expect(copiedText(), isNot(contains('127.0.0.1')));
    expect(copiedText(), isNot(contains('/Users/')));

    await tester.tap(find.byKey(const ValueKey('top-status-device')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('status-detail-drawer')), findsOneWidget);
    expect(find.text('状态详情'), findsOneWidget);
    expect(find.text('确认已解锁和已信任，再点连接设备。'), findsWidgets);
    expect(
      find.text('driver returned HTTP 500 for [local-url].'),
      findsOneWidget,
    );
  });

  testWidgets('device readiness reuses driver invisible diagnostic', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.error,
      appiumStatus: AppiumProcessStatus.running,
      appiumMessage: '驱动未识别手机。',
      lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
        type: RuntimeConnectionIssueType.driverDeviceNotVisible,
        status: ConnectionStatus.error,
        summary: '驱动未识别手机。',
        nextStep: '保持解锁，点连接设备。仍失败就重插线。',
        detail: '本机驱动没有看到当前手机。',
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connection-diagnostic-card')),
      findsOneWidget,
    );
    expect(find.text('驱动'), findsAtLeastNWidgets(2));
    expect(find.text('驱动未识别手机。'), findsNWidgets(2));
    expect(find.text('保持解锁，点连接设备。仍失败就重插线。'), findsNWidgets(2));
    expect(find.textContaining('Unknown device'), findsNothing);
    expect(find.textContaining('[device]'), findsNothing);
  });

  testWidgets('device page surfaces WDA build diagnostic as build issue', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.error,
      appiumStatus: AppiumProcessStatus.running,
      appiumMessage: '手机会话构建失败。',
      lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
        type: RuntimeConnectionIssueType.wdaBuildFailed,
        status: ConnectionStatus.error,
        summary: '手机会话构建失败。',
        nextStep: '打开 Xcode 处理签名后，再点连接设备。',
        detail: 'xcodebuild failed with code 65 at [path].',
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connection-diagnostic-card')),
      findsOneWidget,
    );
    expect(find.text('构建'), findsWidgets);
    expect(find.text('手机会话构建失败。'), findsWidgets);
    expect(find.text('打开 Xcode 处理签名后，再点连接设备。'), findsWidgets);
    expect(find.textContaining('xcodebuild'), findsNothing);
  });

  testWidgets('device page explains network phone is not USB', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 1000));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.error,
      appiumStatus: AppiumProcessStatus.running,
      appiumMessage: '当前不是 USB 连接。',
      lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
        type: RuntimeConnectionIssueType.deviceUnavailable,
        status: ConnectionStatus.error,
        summary: '当前不是 USB 连接。',
        nextStep: '用数据线连接一台手机并解锁。',
        detail: '',
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connection-diagnostic-card')),
      findsOneWidget,
    );
    expect(find.text('USB'), findsWidgets);
    expect(find.text('当前不是 USB 连接。'), findsWidgets);
    expect(find.text('用数据线连接一台手机并解锁。'), findsWidgets);
  });

  testWidgets('device local stack check refreshes dependency guide', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1800));
    final controller = StudioRuntimeController(
      dependencyChecker: FakeDependencyChecker(
        LocalDependencyReport(
          checks: const [
            LocalDependencyCheck(
              id: 'appium-cli',
              label: '驱动工具',
              status: LocalDependencyStatus.ready,
              summary: '驱动工具可用。',
              nextStep: '连接设备。',
            ),
            LocalDependencyCheck(
              id: 'xcode-cli',
              label: '开发工具',
              status: LocalDependencyStatus.ready,
              summary: '开发工具可用。',
              nextStep: '连接设备。',
            ),
            LocalDependencyCheck(
              id: 'ios-tunnel',
              label: '本机隧道',
              status: LocalDependencyStatus.ready,
              summary: '本机隧道已运行。',
              nextStep: '回到应用继续连接。',
            ),
            LocalDependencyCheck(
              id: 'wda-prerequisites',
              label: '会话准备',
              status: LocalDependencyStatus.ready,
              summary: '会话条件已就绪。',
              nextStep: '如有提示，请处理信任。',
            ),
            LocalDependencyCheck(
              id: 'android-adb',
              label: '安卓调试',
              status: LocalDependencyStatus.ready,
              summary: '已发现一台安卓手机。',
              nextStep: '可运行安卓冒烟。',
              detail: 'Pixel 8 / Android 15',
            ),
          ],
          checkedAt: DateTime(2026, 1, 7, 3, 4, 5),
          message: '本机检查通过。',
        ),
      ),
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();
    final localStackButton = find.byKey(const ValueKey('check-local-stack'));
    final deviceScroll = find.byKey(const ValueKey('device-side-scroll'));
    await tester.dragUntilVisible(
      localStackButton,
      deviceScroll,
      const Offset(0, -260),
      maxIteration: 12,
    );
    await tester.ensureVisible(localStackButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('device-bind-usb')), findsOneWidget);
    expect(find.text('重绑'), findsOneWidget);
    await tester.tap(localStackButton);
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('驱动工具'),
      deviceScroll,
      const Offset(0, 260),
      maxIteration: 12,
    );

    expect(find.text('环境检查'), findsOneWidget);
    expect(find.text('已检查 03:04:05'), findsOneWidget);
    expect(find.text('驱动工具'), findsOneWidget);
    expect(find.text('开发工具'), findsWidgets);
    expect(find.text('本机隧道'), findsWidgets);
    expect(find.text('会话准备'), findsOneWidget);
    expect(find.text('安卓调试'), findsOneWidget);
    expect(controller.snapshot.dependencyReport.message, '本机检查通过。');
    expect(
      controller.snapshot.dependencyReport.checkById('android-adb')?.detail,
      'Pixel 8 / Android 15',
    );
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.textContaining('0000'), findsNothing);
  });

  testWidgets('device connect prompts Mac password when tunnel is needed', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1000));
    final controller = StudioRuntimeController(requiresAppiumTunnel: true);
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      dependencyReport: LocalDependencyReport(
        checks: const [
          LocalDependencyCheck(
            id: 'ios-tunnel',
            label: '本机隧道',
            status: LocalDependencyStatus.warning,
            summary: '未发现本机隧道。',
            nextStep: '点连接设备并输入密码。',
          ),
        ],
        checkedAt: DateTime(2026, 1, 7, 3, 4, 5),
        message: '本机检查需要处理。',
      ),
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();
    final connectButton = find.byKey(
      const ValueKey('device-connect-one-button'),
    );
    final deviceScroll = find.byKey(const ValueKey('device-side-scroll'));
    await tester.dragUntilVisible(
      connectButton,
      deviceScroll,
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.ensureVisible(connectButton);
    await tester.pumpAndSettle();
    await tester.tap(connectButton);
    await tester.pumpAndSettle();

    expect(find.text('密码'), findsWidgets);
    expect(find.text('只用于连接，不会保存。'), findsOneWidget);
    expect(find.byKey(const ValueKey('mac-password-input')), findsOneWidget);
    expect(find.textContaining('终端'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('mac-password-cancel')));
    await tester.pumpAndSettle();
    await controller.dispose();
  });

  testWidgets('device connect asks password after runtime tunnel refresh', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 1200));
    final checker = _SequenceDependencyChecker([
      _tunnelReadyReport(),
      _tunnelMissingReport(),
    ]);
    final controller = StudioRuntimeController(
      dependencyChecker: checker,
      requiresAppiumTunnel: true,
    );
    await controller.refreshDependencyReport();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();
    final connectButton = find.byKey(
      const ValueKey('device-connect-one-button'),
    );
    final deviceScroll = find.byKey(const ValueKey('device-side-scroll'));
    await tester.dragUntilVisible(
      connectButton,
      deviceScroll,
      const Offset(0, -420),
      maxIteration: 12,
    );
    await tester.ensureVisible(connectButton);
    await tester.pumpAndSettle();
    await tester.tap(connectButton);
    await tester.pumpAndSettle();

    expect(find.text('密码'), findsWidgets);
    expect(find.text('只用于连接，不会保存。'), findsOneWidget);
    expect(find.byKey(const ValueKey('mac-password-input')), findsOneWidget);
    expect(controller.snapshot.lastConnectionDiagnostic?.summary, '需要本机密码。');
    expect(checker.checks, 2);

    await tester.tap(find.byKey(const ValueKey('mac-password-cancel')));
    await tester.pumpAndSettle();
    await controller.dispose();
  });

  testWidgets('device setup guide opens local advanced drawer', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 1200));
    final copiedText = captureClipboardText();
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      dependencyReport: LocalDependencyReport(
        checks: const [
          LocalDependencyCheck(
            id: 'appium-cli',
            label: '驱动工具',
            status: LocalDependencyStatus.ready,
            summary: '驱动工具可用。',
            nextStep: '从设备页连接设备。',
            detail: '2.19.0',
          ),
          LocalDependencyCheck(
            id: 'xcode-cli',
            label: '开发工具',
            status: LocalDependencyStatus.warning,
            summary: '开发工具需要处理。',
            nextStep: '先打开一次开发工具并检查签名。',
            detail: 'Xcode 16.2 / Build version 16C5032a',
          ),
          LocalDependencyCheck(
            id: 'ios-device-tools',
            label: '设备工具',
            status: LocalDependencyStatus.ready,
            summary: '设备工具可用。',
            nextStep: '连接一台已解锁的有线手机。',
          ),
          LocalDependencyCheck(
            id: 'ios-tunnel',
            label: '本机隧道',
            status: LocalDependencyStatus.warning,
            summary: '未发现本机隧道。',
            nextStep: '在项目根目录运行隧道命令。',
          ),
          LocalDependencyCheck(
            id: 'wda-prerequisites',
            label: '会话准备',
            status: LocalDependencyStatus.warning,
            summary: '会话等待本机隧道或手机允许。',
            nextStep: '点连接设备并按手机提示允许。',
          ),
          LocalDependencyCheck(
            id: 'android-adb',
            label: '安卓调试',
            status: LocalDependencyStatus.warning,
            summary: '未发现安卓手机。',
            nextStep: '开启 USB 调试，插线并在手机上点允许。',
          ),
        ],
        checkedAt: DateTime(2026, 1, 7, 3, 4, 5),
        message: '本机检查需要处理。',
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-设备')));
    await tester.pumpAndSettle();

    final setupGuideButton = find.byKey(
      const ValueKey('open-local-setup-guide'),
    );
    final deviceScroll = find.byKey(const ValueKey('device-side-scroll'));
    await tester.dragUntilVisible(
      setupGuideButton,
      deviceScroll,
      const Offset(0, -520),
      maxIteration: 18,
    );
    await tester.ensureVisible(setupGuideButton);
    await tester.pumpAndSettle();
    await tester.tap(setupGuideButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('local-setup-guide-drawer')),
      findsOneWidget,
    );
    expect(find.text('本机指引'), findsOneWidget);
    expect(find.text('驱动服务'), findsWidgets);
    expect(find.text('2.19.0'), findsOneWidget);
    expect(find.textContaining('中间不加接口服务'), findsOneWidget);
    expect(find.text('开发工具'), findsWidgets);
    expect(find.textContaining('Xcode 16.2'), findsOneWidget);
    expect(find.text('会话与信任'), findsOneWidget);
    expect(find.text('本机隧道'), findsWidgets);
    expect(find.text('隧道步骤'), findsOneWidget);
    expect(find.textContaining('应用会继续准备驱动'), findsOneWidget);
    expect(find.textContaining('点允许'), findsWidgets);
    expect(
      find.byKey(const ValueKey('copy-local-tunnel-command')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('copy-local-tunnel-command')));
    await tester.pump();

    expect(
      copiedText(),
      'sudo node_modules/.bin/appium driver run xcuitest tunnel-creation',
    );
    expect(find.text('已复制'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('安卓准备'),
      find.byKey(const ValueKey('local-setup-guide-scroll')),
      const Offset(0, -180),
      maxIteration: 8,
    );
    expect(find.text('安卓准备'), findsOneWidget);
    expect(find.text('未发现安卓手机。'), findsWidgets);
    expect(find.text('开启 USB 调试，插线并在手机上点允许。'), findsWidgets);
    expect(find.text('开调试'), findsOneWidget);
    expect(find.text('插数据线'), findsOneWidget);
    expect(find.text('点允许'), findsWidgets);
    expect(find.text('跑安卓'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('copy-android-smoke-command')));
    await tester.pump();

    expect(copiedText(), 'npm run v4:android-smoke:full');
    expect(copiedText(), isNot(contains('/Users/')));
    expect(copiedText(), isNot(contains('127.0.0.1')));

    await tester.dragUntilVisible(
      find.text('边界'),
      find.byKey(const ValueKey('local-setup-guide-scroll')),
      const Offset(0, -220),
      maxIteration: 8,
    );
    expect(find.text('边界'), findsOneWidget);
    expect(find.textContaining('信任、签名或开发者模式'), findsOneWidget);
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.textContaining('/Users/'), findsNothing);
    expect(find.textContaining('device-unique-placeholder'), findsNothing);
  });
}

final class _SequenceDependencyChecker implements LocalDependencyChecker {
  _SequenceDependencyChecker(this._reports);

  final List<LocalDependencyReport> _reports;
  int checks = 0;

  @override
  Future<LocalDependencyReport> check({
    required AppiumProcessConfig appiumProcess,
  }) async {
    final index = checks < _reports.length ? checks : _reports.length - 1;
    checks += 1;
    return _reports[index];
  }
}

LocalDependencyReport _tunnelReadyReport() {
  return LocalDependencyReport(
    checks: [
      LocalDependencyCheck(
        id: 'ios-tunnel',
        label: '本机隧道',
        status: LocalDependencyStatus.ready,
        summary: '本机隧道已就绪。',
        nextStep: '继续连接设备。',
      ),
    ],
    checkedAt: DateTime(2026, 1, 7, 3, 4, 5),
    message: '本机检查通过。',
  );
}

LocalDependencyReport _tunnelMissingReport() {
  return LocalDependencyReport(
    checks: [
      LocalDependencyCheck(
        id: 'ios-tunnel',
        label: '本机隧道',
        status: LocalDependencyStatus.warning,
        summary: '未发现本机隧道。',
        nextStep: '点连接设备并输入密码。',
      ),
    ],
    checkedAt: DateTime(2026, 1, 7, 3, 4, 6),
    message: '本机检查需要处理。',
  );
}
