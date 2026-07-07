import 'dart:convert';

import 'package:appium_client/appium_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Execute 页面回归测试，聚焦运行控制台、确认弹窗和预检拦截。
// 这些用例从综合 widget_test 拆出，避免继续扩大单个测试文件。
void main() {
  testWidgets('workflow toolbar opens execute page without starting run', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    final openExecute = tester.widget<FilledButton>(
      find.byKey(const ValueKey('workflow-open-execute')),
    );
    expect(openExecute.onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('workflow-open-execute')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-command-center')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('execute-run-selected')), findsOneWidget);
    expect(controller.snapshot.runStatus, RunStatus.idle);
  });

  testWidgets('workflow toolbar blocks execute while source draft is dirty', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));

    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('源码'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('workflow-source-editor')),
      '{"name":"未保存"}',
    );
    await tester.pump(const Duration(milliseconds: 250));

    final openExecute = tester.widget<FilledButton>(
      find.byKey(const ValueKey('workflow-open-execute')),
    );
    expect(openExecute.onPressed, isNull);
  });

  testWidgets('execute and workflow views render runtime execution focus', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    const workflow = WorkflowDefinition(
      id: 'focus-workflow',
      name: 'Focus Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['tap_1'],
        ),
        WorkflowNode(
          id: 'tap_1',
          type: WorkflowNodeType.tap,
          label: '点登录',
          next: ['wait_1'],
          parameters: {'label': 'Login', 'x': 10, 'y': 20},
        ),
        WorkflowNode(
          id: 'wait_1',
          type: WorkflowNodeType.wait,
          label: '等待屏幕',
          next: ['end'],
          parameters: {'ms': 500},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final entry = RunHistoryEntry(
      runId: 'run-execute-latest',
      workflowName: '运行证据流程',
      status: 'failed',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 8, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 8, 3, 4, 9),
    );
    final detail = RunDetail(
      entry: entry,
      events: [
        RunEvidenceEvent(
          type: 'stepStart',
          status: null,
          nodeId: 'wait_1',
          nodeType: 'wait',
          label: '等待屏幕',
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 8, 3, 4, 6),
        ),
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'failed',
          nodeId: 'wait_1',
          nodeType: 'wait',
          label: '等待屏幕',
          loopIndex: 0,
          error: 'Runtime timeout while waiting for screen.',
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 8, 3, 4, 9),
        ),
      ],
    );
    final controller = StudioRuntimeController(
      runDetailReader: FakeRunDetailReader({'run-execute-latest': detail}),
    );
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      runStatus: RunStatus.running,
      runHistory: RunHistorySummary(
        totalRuns: 1,
        completedRuns: 0,
        failedRuns: 1,
        pausedRuns: 0,
        stoppedRuns: 0,
        dailyRuns: const <RunHistoryDay>[],
        recentRuns: [entry],
      ),
      executionFocus: const RuntimeExecutionFocus(
        activeNodeId: 'wait_1',
        completedNodeIds: {'tap_1'},
        failedNodeId: null,
        activeLoopIndex: 0,
        totalLoops: 1,
        runStartedAt: null,
        completedSteps: 1,
        totalSteps: 3,
      ),
      events: [
        RuntimeEvent(level: 'info', message: 'Run queued.'),
        RuntimeEvent(level: 'info', message: 'Starting workflow.'),
        RuntimeEvent(level: 'warning', message: '等待结束后停止。'),
        RuntimeEvent(
          level: 'error',
          message:
              'Failure at /Users/example/project with token 0123456789ABCDEF012345.',
        ),
      ],
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('运行设置'), findsOneWidget);
    expect(find.text('运行前'), findsOneWidget);
    expect(find.text('运行摘要'), findsOneWidget);
    expect(find.text('上次证据'), findsOneWidget);
    expect(find.text('运行证据流程'), findsOneWidget);
    expect(find.text('运行线'), findsOneWidget);
    expect(find.text('等待结束后停止。'), findsOneWidget);
    expect(find.textContaining('[本机路径]'), findsWidgets);
    expect(find.textContaining('[标识]'), findsWidgets);
    expect(find.textContaining('/Users/example'), findsNothing);
    expect(find.byKey(const ValueKey('execute-focus-panel')), findsOneWidget);
    expect(find.text('第 1/1 轮'), findsOneWidget);
    expect(find.text('等待屏幕'), findsOneWidget);
    expect(find.text('1/3 步'), findsOneWidget);
    expect(find.text('剩余'), findsOneWidget);

    final latestDetailButton = find.byKey(
      const ValueKey('execute-last-run-detail'),
    );
    await tester.ensureVisible(latestDetailButton);
    await tester.tap(latestDetailButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('run-detail-drawer')), findsOneWidget);
    expect(find.text('问题分析'), findsOneWidget);
    expect(find.text('超时'), findsOneWidget);
    expect(
      find.text('Runtime timeout while waiting for screen.'),
      findsWidgets,
    );
    await tester.tap(find.byTooltip('关闭详情'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('当前'), findsOneWidget);
    expect(find.text('完成'), findsWidgets);
  });

  testWidgets('execute view surfaces paused intervention state', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    const workflow = WorkflowDefinition(
      id: 'visual-workflow',
      name: 'Visual Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['visual_1'],
        ),
        WorkflowNode(
          id: 'visual_1',
          type: WorkflowNodeType.visualBranch,
          label: '查屏幕',
          next: ['tap_1'],
          parameters: {'confidenceThreshold': 0.8},
        ),
        WorkflowNode(
          id: 'tap_1',
          type: WorkflowNodeType.tap,
          label: '继续',
          next: ['end'],
          parameters: {'label': '继续', 'x': 10, 'y': 20},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController(
      sessionManager: FakeDeviceSessionManager('paused-session'),
      deviceActions: FakePreviewDeviceActionExecutor(
        screenshotBase64: base64Encode([1, 2, 3]),
        viewportSize: const ViewportSize(width: 390, height: 844),
      ),
      workflow: workflow,
    );
    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);

    expect(result?.paused, isTrue);
    expect(controller.snapshot.runStatus, RunStatus.paused);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('已暂停'), findsOneWidget);
    expect(find.text('等待处理'), findsOneWidget);
    expect(find.text('运行摘要'), findsOneWidget);
    expect(find.text('人工处理'), findsOneWidget);
    expect(find.text('暂停节点'), findsOneWidget);
    expect(find.text('查屏幕'), findsOneWidget);
    expect(find.text('解除暂停'), findsOneWidget);
    expect(find.textContaining('避免误点'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('execute-stop-or-resolve')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(find.text('空闲'), findsWidgets);
    expect(find.text('解除暂停'), findsNothing);
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('暂停已解除，任务已安全收口。'),
    );
  });

  testWidgets('execute focus surfaces failed reason safely', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    const workflow = WorkflowDefinition(
      id: 'failed-focus-workflow',
      name: '失败焦点流程',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['tap_1'],
        ),
        WorkflowNode(
          id: 'tap_1',
          type: WorkflowNodeType.tap,
          label: '点登录',
          next: ['end'],
          parameters: {'label': '登录', 'x': 10, 'y': 20},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController();
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
      executionFocus: const RuntimeExecutionFocus(
        activeNodeId: null,
        completedNodeIds: {'start'},
        failedNodeId: 'tap_1',
        activeLoopIndex: null,
        totalLoops: null,
        completedSteps: 1,
        totalSteps: 2,
      ),
      events: [
        RuntimeEvent(
          level: 'error',
          message:
              'Run failed: /Users/example/project secret 0123456789ABCDEF012345.',
        ),
      ],
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('execute-focus-panel')), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
    expect(find.text('点登录'), findsOneWidget);
    expect(find.text('原因'), findsOneWidget);
    expect(find.textContaining('运行失败'), findsWidgets);
    expect(find.textContaining('[本机路径]'), findsWidgets);
    expect(find.textContaining('[标识]'), findsWidgets);
    expect(find.textContaining('/Users/example'), findsNothing);
  });

  testWidgets('execute focus surfaces safe stopping state', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    const workflow = WorkflowDefinition(
      id: 'stopping-focus-workflow',
      name: '停止焦点流程',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['wait_1'],
        ),
        WorkflowNode(
          id: 'wait_1',
          type: WorkflowNodeType.wait,
          label: '等待屏幕',
          next: ['end'],
          parameters: {'ms': 500},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController();
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.stopping,
      executionFocus: const RuntimeExecutionFocus(
        activeNodeId: 'wait_1',
        completedNodeIds: {'start'},
        failedNodeId: null,
        activeLoopIndex: 0,
        totalLoops: 1,
        completedSteps: 1,
        totalSteps: 3,
      ),
      events: [RuntimeEvent(level: 'warning', message: '已请求停止，等待当前动作完成。')],
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    final focusPanel = find.byKey(const ValueKey('execute-focus-panel'));
    expect(focusPanel, findsOneWidget);
    expect(find.text('等待屏幕'), findsOneWidget);
    expect(
      find.descendant(of: focusPanel, matching: find.text('停止')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: focusPanel, matching: find.text('当前动作后停止')),
      findsOneWidget,
    );
    expect(find.textContaining('/Users/'), findsNothing);
  });

  testWidgets('execute start requires confirmation before runtime run', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final controller = StudioRuntimeController();
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    expect(find.text('循环 · 3 轮'), findsOneWidget);
    expect(find.text('开始 3 轮'), findsOneWidget);

    final eventCountBeforeCancel = controller.snapshot.events.length;
    await tester.tap(find.byKey(const ValueKey('execute-run-selected')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-run-confirmation')),
      findsOneWidget,
    );
    expect(find.text('确认运行'), findsOneWidget);
    expect(find.text('A-F 基础模板'), findsWidgets);
    expect(find.text('循环'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('串行运行'), findsOneWidget);
    expect(find.text('当前动作结束后停止'), findsOneWidget);
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.textContaining('/Users/'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('execute-run-cancel')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-run-confirmation')),
      findsNothing,
    );
    expect(controller.snapshot.events.length, eventCountBeforeCancel);

    await tester.tap(find.text('持续').first);
    await tester.pumpAndSettle();

    expect(find.text('持续 · 最多 999 轮'), findsOneWidget);
    expect(find.text('持续模式最多 999 轮，可随时停止。'), findsOneWidget);
    expect(find.text('开始持续'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('execute-run-selected')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-run-confirmation')),
      findsOneWidget,
    );
    expect(find.text('最多 999'), findsOneWidget);
    expect(find.text('达到上限会自动收口'), findsOneWidget);
    expect(find.text('开始持续'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('execute-run-cancel')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('单次').first);
    await tester.pumpAndSettle();

    expect(find.text('单次 · 1 轮'), findsOneWidget);
    expect(find.text('单次模式固定 1 轮。'), findsOneWidget);
    expect(find.text('开始 1 轮'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('execute-run-selected')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-run-confirmation')),
      findsOneWidget,
    );
    expect(find.text('单次'), findsWidgets);
    expect(find.text('开始 1 轮'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('execute-run-confirm')));
    await tester.pumpAndSettle();

    expect(
      controller.snapshot.events
          .map((event) => event.message)
          .contains('请先连接设备再运行。'),
      isTrue,
    );

    await controller.dispose();
  });

  testWidgets('execute preflight blocks missing sub workflow reference', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    const workflow = WorkflowDefinition(
      id: 'execute-missing-subflow',
      name: '缺失子流程运行',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['sub_1'],
        ),
        WorkflowNode(
          id: 'sub_1',
          type: WorkflowNodeType.subWorkflow,
          label: '缺失子流程',
          next: ['end'],
          parameters: {'workflowId': 'missing-child'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController(workflow: workflow);
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    expect(find.text('流程有问题，暂不能运行。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('execute-workflow-issue')),
      findsOneWidget,
    );
    expect(find.textContaining('不存在的子流程 missing-child'), findsOneWidget);

    final runButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('execute-run-selected')),
    );
    expect(runButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('execute-run-selected')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-run-confirmation')),
      findsNothing,
    );
    expect(
      controller.snapshot.events.map((event) => event.message),
      isNot(contains(contains('开始运行'))),
    );

    await controller.dispose();
  });

  testWidgets('execute view explains driver cannot see connected phone', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final copiedText = captureClipboardText();
    final controller = StudioRuntimeController();
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.error,
      appiumStatus: AppiumProcessStatus.running,
      appiumMessage: '驱动未识别手机。',
      lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
        type: RuntimeConnectionIssueType.driverDeviceNotVisible,
        status: ConnectionStatus.error,
        summary: '驱动未识别手机。',
        nextStep: '保持解锁，点连接设备。仍失败就重插线。',
        detail:
            'Unknown device or simulator UDID: 11112222-3333444455556666 at http://127.0.0.1:4723/session /Users/example/project',
      ),
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connection-diagnostic-card')),
      findsOneWidget,
    );
    expect(find.text('先处理连接'), findsOneWidget);
    expect(find.text('驱动'), findsWidgets);
    expect(find.text('驱动未识别手机。'), findsWidgets);
    expect(find.text('保持解锁，点连接设备。仍失败就重插线。'), findsWidgets);
    expect(find.textContaining('Unknown device'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('copy-connection-diagnostic')));
    await tester.pumpAndSettle();

    expect(copiedText(), contains('连接诊断'));
    expect(copiedText(), contains('问题：驱动'));
    expect(copiedText(), contains('状态：驱动未识别手机。'));
    expect(copiedText(), contains('下一步：保持解锁，点连接设备。仍失败就重插线。'));
    expect(copiedText(), contains('[标识]'));
    expect(copiedText(), contains('[本机地址]'));
    expect(copiedText(), contains('[本机路径]'));
    expect(copiedText(), isNot(contains('11112222')));
    expect(copiedText(), isNot(contains('127.0.0.1')));
    expect(copiedText(), isNot(contains('/Users/example')));

    final runButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('execute-run-selected')),
    );
    expect(runButton.onPressed, isNull);

    await controller.dispose();
  });

  testWidgets('execute view explains phone must be connected by USB', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final controller = StudioRuntimeController();
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

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('connection-diagnostic-card')),
      findsOneWidget,
    );
    expect(find.text('先处理连接'), findsOneWidget);
    expect(find.text('USB'), findsWidgets);
    expect(find.text('当前不是 USB 连接。'), findsWidgets);
    expect(find.text('用数据线连接一台手机并解锁。'), findsWidgets);

    final runButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('execute-run-selected')),
    );
    expect(runButton.onPressed, isNull);

    await controller.dispose();
  });

  testWidgets('execute connection action mirrors one button busy state', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connecting,
      appiumStatus: AppiumProcessStatus.running,
      appiumMessage: '正在连接设备。',
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    final connectButton = find.byKey(
      const ValueKey('execute-connect-one-button'),
    );

    expect(connectButton, findsOneWidget);
    expect(find.text('连接中'), findsWidgets);
    expect(find.text('请稍等，正在自动处理。'), findsOneWidget);
    expect(find.textContaining('终端'), findsNothing);
    expect(find.textContaining('session'), findsNothing);

    final connect = tester.widget<FilledButton>(connectButton);
    final run = tester.widget<FilledButton>(
      find.byKey(const ValueKey('execute-run-selected')),
    );

    expect(connect.onPressed, isNull);
    expect(run.onPressed, isNull);
  });

  // 覆盖运行前多问题清单，确保用户能看到完整修正范围。
  // 该清单只消费共享校验结果，不允许执行页自建另一套流程检查。
  testWidgets('execute preflight opens workflow issue details', (tester) async {
    await useDesktopSurface(tester, size: const Size(1400, 900));
    const workflow = WorkflowDefinition(
      id: 'execute-multi-issue-workflow',
      name: '多问题流程',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['sub_1'],
        ),
        WorkflowNode(
          id: 'sub_1',
          type: WorkflowNodeType.subWorkflow,
          label: '缺失子流程',
          next: ['tap_self'],
          parameters: {'workflowId': 'missing-child'},
        ),
        WorkflowNode(
          id: 'tap_self',
          type: WorkflowNodeType.tap,
          label: '自连点击',
          next: ['tap_self'],
          parameters: {'label': '自连点击', 'x': 10, 'y': 20},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController(workflow: workflow);
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-运行')));
    await tester.pumpAndSettle();

    expect(find.text('流程有问题，暂不能运行。'), findsOneWidget);
    expect(find.text('查看 2 项'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('execute-workflow-issue-details')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-workflow-issue-dialog')),
      findsOneWidget,
    );
    expect(find.text('流程问题'), findsOneWidget);
    expect(find.text('共 2 项，修正后再运行。'), findsOneWidget);
    expect(find.textContaining('不存在的子流程 missing-child'), findsOneWidget);
    expect(find.textContaining('节点 tap_self 不能连接自己'), findsWidgets);
    expect(
      find.byKey(const ValueKey('execute-workflow-issue-item-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('execute-workflow-issue-item-1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('execute-workflow-issue-close')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('execute-workflow-issue-dialog')),
      findsNothing,
    );

    await controller.dispose();
  });
}
