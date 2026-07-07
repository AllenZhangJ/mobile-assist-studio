import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appium_client/appium_client.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Recorder 页面回归测试，聚焦录制、动作整理、隐私展示和 Promote 到 Project DSL。
// 这些用例从综合 widget_test 拆出，后续 Recorder 新场景优先放在这里。
void main() {
  testWidgets('recorder captures actions and hides coordinates until detail', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pumpAndSettle();

    expect(find.text('录制'), findsWidgets);
    expect(find.text('动作线'), findsOneWidget);
    expect(find.text('录制空闲'), findsOneWidget);
    expect(find.text('坐标'), findsNothing);

    await tester.ensureVisible(find.text('开始录制'));
    await tester.tap(find.text('开始录制'));
    await tester.pumpAndSettle();

    expect(find.text('录制中'), findsWidgets);

    await tester.ensureVisible(find.text('加点击'));
    await tester.tap(find.text('加点击'));
    await tester.ensureVisible(find.text('加等待'));
    await tester.tap(find.text('加等待'));
    await tester.ensureVisible(find.text('加滑动'));
    await tester.tap(find.text('加滑动'));
    await tester.pumpAndSettle();

    expect(find.text('3 个动作'), findsOneWidget);

    expect(find.text('点登录'), findsOneWidget);
    expect(find.text('等 500ms'), findsOneWidget);
    expect(find.text('3 个动作'), findsOneWidget);
    expect(find.text('坐标'), findsNothing);

    await tester.tap(find.text('点登录'));
    await tester.pumpAndSettle();

    expect(find.text('动作详情'), findsOneWidget);
    expect(find.text('坐标'), findsOneWidget);
    expect(find.text('摘要'), findsOneWidget);
    expect(find.text('点击 · 登录按钮，等 50ms'), findsOneWidget);
    expect(find.text('编号'), findsNothing);
    expect(find.text('recorded_001'), findsNothing);
    expect(find.text('横向'), findsOneWidget);
    expect(find.text('纵向'), findsOneWidget);
    expect(find.text('横向 92，纵向 499'), findsOneWidget);
    expect(find.text('ID'), findsNothing);
    expect(find.text('X'), findsNothing);
    expect(find.text('Y'), findsNothing);
    expect(find.text('证据'), findsOneWidget);
    expect(find.text('无预览'), findsWidgets);
    expect(find.text('暂无截图证据'), findsOneWidget);
  });

  testWidgets('recorder workbench surfaces live capture readiness', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      latestScreenshotBase64: onePixelPngBase64,
      latestScreenshotAt: DateTime(2026, 1, 7, 3, 4, 5),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pumpAndSettle();

    expect(find.text('实时截图'), findsOneWidget);
    expect(find.text('会话摘要'), findsOneWidget);
    expect(find.text('录制前'), findsOneWidget);
    expect(find.text('可截图'), findsOneWidget);
    expect(find.text('有预览'), findsOneWidget);
    expect(find.text('截图'), findsOneWidget);
    expect(find.text('03:04:05'), findsOneWidget);

    final captureButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('recorder-capture-screen')),
    );
    expect(captureButton.onPressed, isNotNull);
    expect(
      find.byKey(const ValueKey('recorder-connect-one-button')),
      findsNothing,
    );
  });

  testWidgets('recorder session offers shared one button connect', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pumpAndSettle();

    final connectButton = find.byKey(
      const ValueKey('recorder-connect-one-button'),
    );

    expect(connectButton, findsOneWidget);
    expect(find.text('连接设备'), findsOneWidget);
    expect(find.text('自动检查、启动、连接。'), findsOneWidget);
    expect(find.textContaining('终端'), findsNothing);
    expect(find.textContaining('session'), findsNothing);

    final connect = tester.widget<FilledButton>(connectButton);
    expect(connect.onPressed, isNotNull);
  });

  testWidgets('recorder picks tap from preview while recording', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final screenshotBase64 = await testPngBase64(width: 640, height: 1280);
    final deviceActions = FakePreviewDeviceActionExecutor(
      screenshotBase64: screenshotBase64,
      viewportSize: const ViewportSize(width: 640, height: 1280),
    );
    final controller = StudioRuntimeController(
      sessionManager: FakeDeviceSessionManager('runtime-session'),
      deviceActions: deviceActions,
    );
    await controller.connectDevice();
    await controller.captureScreenshot(reason: 'widget-test');

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('开始录制'));
    await tester.tap(find.text('开始录制'));
    await tester.pump(const Duration(milliseconds: 350));
    await pumpUntilFound(tester, find.text('可录'));

    expect(find.text('可录'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('recorder-preview-pick-target')),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('点画面'), findsOneWidget);
    expect(find.text('屏幕位置，等 50ms'), findsOneWidget);
    expect(find.text('有图'), findsOneWidget);
    expect(find.textContaining('x='), findsNothing);
    expect(find.textContaining('y='), findsNothing);
    expect(deviceActions.calls, ['screenshot']);

    await tester.tap(find.text('点画面'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('动作详情'), findsOneWidget);
    expect(find.text('坐标'), findsOneWidget);
    expect(find.text('横向 320，纵向 640'), findsOneWidget);
    expect(find.text('证据'), findsOneWidget);
    expect(find.textContaining('预览'), findsWidgets);
    expect(find.textContaining('已绑定预览'), findsOneWidget);
    expect(find.text('显示截图'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('recorder-evidence-reveal')),
    );
    final revealButton = tester.widget<TextButton>(
      find.byKey(const ValueKey('recorder-evidence-reveal')),
    );
    expect(revealButton.onPressed, isNotNull);
    revealButton.onPressed!();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('隐藏截图'), findsOneWidget);
  });

  testWidgets('recorder records swipe path from preview drag', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final screenshotBase64 = await testPngBase64(width: 400, height: 800);
    final deviceActions = FakePreviewDeviceActionExecutor(
      screenshotBase64: screenshotBase64,
      viewportSize: const ViewportSize(width: 400, height: 800),
    );
    final controller = StudioRuntimeController(
      sessionManager: FakeDeviceSessionManager('runtime-session'),
      deviceActions: deviceActions,
    );
    await controller.connectDevice();
    await controller.captureScreenshot(reason: 'widget-test');

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.ensureVisible(find.text('开始录制'));
    await tester.tap(find.text('开始录制'));
    await tester.pump(const Duration(milliseconds: 350));
    await pumpUntilFound(tester, find.text('可录'));

    final previewTarget = find.byKey(
      const ValueKey('recorder-preview-pick-target'),
    );
    await tester.drag(previewTarget, const Offset(0, -120));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('1 个动作'), findsOneWidget);
    expect(find.text('上滑'), findsOneWidget);
    expect(find.text('屏幕滑动，上滑 420ms'), findsOneWidget);
    expect(find.textContaining('x='), findsNothing);
    expect(find.textContaining('y='), findsNothing);

    await tester.tap(find.text('上滑'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('动作详情'), findsOneWidget);
    expect(find.text('坐标'), findsOneWidget);
    expect(find.textContaining('从 '), findsOneWidget);
    expect(find.text('起横'), findsOneWidget);
    expect(find.text('起纵'), findsOneWidget);
    expect(find.text('终横'), findsOneWidget);
    expect(find.text('终纵'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-x')),
        matching: find.byType(TextField),
      ),
      '200',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-y')),
        matching: find.byType(TextField),
      ),
      '600',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-to-x')),
        matching: find.byType(TextField),
      ),
      '220',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-to-y')),
        matching: find.byType(TextField),
      ),
      '120',
    );
    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('recorder-action-save')),
    );
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.pumpAndSettle();

    final promoteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('promote-recorder-workflow')),
    );
    expect(promoteButton.onPressed, isNotNull);
    promoteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final swipeNode = workflow.nodes.firstWhere(
      (node) => node.type == WorkflowNodeType.swipe,
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(swipeNode.label, '上滑');
    expect(swipeNode.parameters['direction'], 'up');
    expect(swipeNode.parameters['fromX'], 200);
    expect(swipeNode.parameters['fromY'], 600);
    expect(swipeNode.parameters['toX'], 220);
    expect(swipeNode.parameters['toY'], 120);
  });

  testWidgets('recorder promotes captured actions into workflow source', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('开始录制'));
    await tester.tap(find.text('开始录制'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('加点击'));
    await tester.tap(find.text('加点击'));
    await tester.ensureVisible(find.text('加等待'));
    await tester.tap(find.text('加等待'));
    await tester.ensureVisible(find.text('加滑动'));
    await tester.tap(find.text('加滑动'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('3 个动作'), findsOneWidget);

    await tester.ensureVisible(find.text('生成流程'));
    final promoteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('promote-recorder-workflow')),
    );
    expect(promoteButton.onPressed, isNotNull);
    promoteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.snapshot.workflow.name, '录制流程');

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('录制流程'), findsOneWidget);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"name": "录制流程"'), findsOneWidget);
    expect(find.textContaining('"type": "swipe"'), findsOneWidget);
  });

  testWidgets('recorder edits captured action before promoting workflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('开始录制'));
    await tester.tap(find.text('开始录制'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('加点击'));
    await tester.tap(find.text('加点击'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.text('点登录'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-label')),
        matching: find.byType(TextField),
      ),
      '点确认',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-target')),
        matching: find.byType(TextField),
      ),
      '确认按钮',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-wait')),
        matching: find.byType(TextField),
      ),
      '120',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-x')),
        matching: find.byType(TextField),
      ),
      '123',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-y')),
        matching: find.byType(TextField),
      ),
      '456',
    );
    await tester.tap(find.byKey(const ValueKey('recorder-action-save')));
    await tester.pumpAndSettle();

    expect(find.text('点确认'), findsOneWidget);
    expect(find.text('确认按钮，等 120ms'), findsOneWidget);
    expect(find.textContaining('x='), findsNothing);

    final promoteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('promote-recorder-workflow')),
    );
    expect(promoteButton.onPressed, isNotNull);
    promoteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final tapNode = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.type == WorkflowNodeType.tap,
    );
    final targetRef = tapNode.parameters['targetRef'];
    final target = controller.snapshot.targetLibrary.targetById(
      targetRef.toString(),
    );
    expect(tapNode.label, '点确认');
    expect(targetRef, 'recorder_recorded_001');
    expect(tapNode.parameters.containsKey('x'), isFalse);
    expect(tapNode.parameters.containsKey('y'), isFalse);
    expect(target?.label, '确认按钮');
    expect(target?.payload['x'], 123);
    expect(target?.payload['y'], 456);
    expect(tapNode.parameters['durationMs'], 80);
  });

  testWidgets(
    'recorder records input action without exposing text in timeline',
    (tester) async {
      String? copiedActionsSummary;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              final arguments = call.arguments as Map<Object?, Object?>;
              copiedActionsSummary = arguments['text'] as String?;
              return null;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      final controller = StudioRuntimeController();

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-录制')));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.ensureVisible(find.text('开始录制'));
      await tester.tap(find.text('开始录制'));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.ensureVisible(find.text('加输入'));
      await tester.tap(find.text('加输入'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('1 个动作'), findsOneWidget);
      expect(find.text('输入文本'), findsOneWidget);
      expect(find.text('当前焦点，等 50ms'), findsOneWidget);
      expect(find.text('示例文本'), findsNothing);

      await tester.tap(find.text('输入文本'));
      await tester.pumpAndSettle();

      expect(find.text('动作详情'), findsOneWidget);
      expect(find.text('输入'), findsWidgets);
      expect(find.text('示例文本'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('recorder-action-text')),
          matching: find.byType(TextField),
        ),
        '搜索内容',
      );
      await tester.tap(find.byKey(const ValueKey('recorder-action-save')));
      await tester.pumpAndSettle();

      expect(find.text('搜索内容'), findsNothing);
      expect(find.text('当前焦点，等 50ms'), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const ValueKey('recorder-copy-actions-summary')),
      );
      await tester.tap(
        find.byKey(const ValueKey('recorder-copy-actions-summary')),
      );
      await tester.pumpAndSettle();

      expect(copiedActionsSummary, contains('录制动作摘要'));
      expect(copiedActionsSummary, contains('数量：1'));
      expect(copiedActionsSummary, contains('1. 输入 · 输入文本 · 当前焦点，等 50ms'));
      expect(copiedActionsSummary, contains('无图'));
      expect(copiedActionsSummary, isNot(contains('搜索内容')));
      expect(copiedActionsSummary, isNot(contains('x=')));
      expect(copiedActionsSummary, isNot(contains('/Users/')));

      final promoteButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('promote-recorder-workflow')),
      );
      expect(promoteButton.onPressed, isNotNull);
      promoteButton.onPressed!();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final workflow = controller.snapshot.workflow;
      final inputNode = workflow.nodes.firstWhere(
        (node) => node.type == WorkflowNodeType.input,
      );
      final waitNode = workflow.nodes.firstWhere(
        (node) => node.id == 'wait_after_0',
      );
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
      expect(inputNode.label, '输入文本');
      expect(inputNode.parameters['text'], '搜索内容');
      expect(inputNode.next, ['wait_after_0']);
      expect(waitNode.type, WorkflowNodeType.wait);
      expect(waitNode.parameters['ms'], 50);
    },
  );

  testWidgets('recorder organizes actions before promoting workflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('开始录制'));
    await tester.tap(find.text('开始录制'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('加点击'));
    await tester.tap(find.text('加点击'));
    await tester.ensureVisible(find.text('加等待'));
    await tester.tap(find.text('加等待'));
    await tester.ensureVisible(find.text('加滑动'));
    await tester.tap(find.text('加滑动'));
    await tester.pumpAndSettle();

    final firstUp = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('recorder-action-up-recorded_001')),
        matching: find.byType(IconButton),
      ),
    );
    expect(firstUp.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('recorder-action-copy-recorded_001')),
    );
    await tester.pumpAndSettle();
    expect(find.text('复制 点登录'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('recorder-action-up-recorded_003')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('recorder-action-down-recorded_004')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('recorder-action-delete-recorded_002')),
    );
    await tester.pumpAndSettle();

    expect(find.text('等 500ms'), findsNothing);
    expect(find.text('4 个动作'), findsNothing);
    expect(find.text('3 个动作'), findsOneWidget);

    final promoteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('promote-recorder-workflow')),
    );
    expect(promoteButton.onPressed, isNotNull);
    promoteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final actionNodes = controller.snapshot.workflow.nodes
        .where(
          (node) =>
              node.type == WorkflowNodeType.tap ||
              node.type == WorkflowNodeType.swipe,
        )
        .map((node) => node.label)
        .toList();
    expect(actionNodes, ['点登录', '上滑', '复制 点登录']);
  });

  testWidgets('recorder opens workflow after promoting actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-录制')));
    await tester.pump(const Duration(milliseconds: 250));

    var openWorkflowButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('recorder-open-workflow')),
    );
    var openExecuteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('recorder-open-execute')),
    );
    expect(openWorkflowButton.onPressed, isNull);
    expect(openExecuteButton.onPressed, isNull);

    await tester.ensureVisible(find.text('开始录制'));
    await tester.tap(find.text('开始录制'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(find.text('加点击'));
    await tester.tap(find.text('加点击'));
    await tester.pump(const Duration(milliseconds: 250));

    final promoteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('promote-recorder-workflow')),
    );
    expect(promoteButton.onPressed, isNotNull);
    promoteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    openWorkflowButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('recorder-open-workflow')),
    );
    openExecuteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('recorder-open-execute')),
    );
    expect(openWorkflowButton.onPressed, isNotNull);
    expect(openExecuteButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('recorder-open-workflow')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('流程'), findsWidgets);
    expect(find.text('录制流程'), findsOneWidget);
  });
}
