// ignore_for_file: unused_import, unnecessary_import

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow 综合回归测试仍承载尚未继续拆出的画布、Palette、Mini Map 和跨区场景。
// Source/Validate、剪贴板、Inspector 已迁移到独立文件，新增用例优先落到对应子域。
// Workflow 画布导航、分支摘要和语义连线回归。
// 每个用例只覆盖一个画布子域，避免综合测试继续膨胀。
void main() {
  // 验证画布节点能按 Runtime 执行焦点展示当前、失败和完成状态。
  testWidgets('workflow canvas highlights current failed and completed nodes', (
    tester,
  ) async {
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runStatus: RunStatus.running,
      executionFocus: const RuntimeExecutionFocus(
        activeNodeId: 'tap_b',
        completedNodeIds: {'start', 'tap_a'},
        failedNodeId: 'tap_d',
        activeLoopIndex: 1,
        totalLoops: 2,
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-tap_b')),
        matching: find.text('当前'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-tap_d')),
        matching: find.text('失败'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-tap_a')),
        matching: find.text('完成'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-node-tap_b')),
        matching: find.text('失败'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('workflow-node-navigator-toggle')),
    );
    await tester.pumpAndSettle();

    final failedButton = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('workflow-navigator-failed-button')),
    );
    expect(failedButton.onPressed, isNotNull);
    failedButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('点击 D'), findsWidgets);
    expect(find.text('tap_d'), findsNothing);
  });

  testWidgets('workflow canvas surfaces latest node evidence', (tester) async {
    final run = RunHistoryEntry(
      runId: 'run-latest',
      workflowName: 'A-F 基础流程',
      status: 'failed',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 10, 8),
      finishedAt: DateTime.utc(2026, 1, 10, 8, 0, 2),
    );
    final detail = RunDetail(
      entry: run,
      events: [
        RunEvidenceEvent(
          type: 'stepStart',
          status: 'running',
          nodeId: 'tap_b',
          nodeType: 'tap',
          label: '点击 B',
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 10, 8),
        ),
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'failed',
          nodeId: 'tap_b',
          nodeType: 'tap',
          label: '点击 B',
          loopIndex: 0,
          error: '低置信暂停',
          screenshotPath: 'screens/tap_b.png',
          at: DateTime.utc(2026, 1, 10, 8, 0, 1),
        ),
        RunEvidenceEvent(
          type: 'visualCheck',
          status: 'ok',
          nodeId: 'tap_b',
          nodeType: 'tap',
          label: '点击 B',
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 10, 8, 0, 1),
          visualEvidence: const RunVisualEvidence(
            rule: 'targetRef=login',
            screenshotAvailable: true,
            confidence: 0.42,
            confidenceThreshold: 0.7,
            result: false,
            action: 'pause',
            reason: '低置信',
            selectedNext: null,
          ),
        ),
      ],
    );
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runHistory: RunHistorySummary(
        totalRuns: 1,
        completedRuns: 0,
        failedRuns: 1,
        pausedRuns: 0,
        stoppedRuns: 0,
        dailyRuns: const <RunHistoryDay>[],
        recentRuns: [run],
      ),
    );
    final controller = StudioRuntimeController(
      runDetailReader: FakeRunDetailReader({'run-latest': detail}),
      runEvidenceAssetReader: const FakeRunEvidenceAssetReader({
        'run-latest/screens/tap_b.png': onePixelPngBase64,
      }),
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    final node = find.byKey(const ValueKey('workflow-node-tap_b'));
    expect(
      find.descendant(
        of: node,
        matching: find.byKey(const ValueKey('workflow-node-evidence-tap_b')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: node, matching: find.text('问题')),
      findsOneWidget,
    );

    await selectWorkflowNode(tester, 'tap_b');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('node-inspector-evidence-card')),
      findsOneWidget,
    );
    expect(find.text('上次留档'), findsOneWidget);
    expect(find.textContaining('1 步'), findsOneWidget);
    expect(find.textContaining('1 图'), findsOneWidget);
    expect(find.textContaining('1 视觉'), findsOneWidget);
    expect(find.textContaining('1 问题'), findsOneWidget);

    final openMonitorButton = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('node-inspector-open-monitor')),
    );
    expect(openMonitorButton.onPressed, isNotNull);
    openMonitorButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('monitor-page-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('run-detail-drawer')), findsOneWidget);
    expect(find.byKey(const ValueKey('run-trace-focused')), findsOneWidget);
    expect(find.byKey(const ValueKey('run-evidence-replay')), findsOneWidget);
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('evidence-filmstrip-image-tap_b-0')),
    );
    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-tap_b-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('screenshot-evidence-image-tap_b-0')),
      findsOneWidget,
    );
  });

  testWidgets('workflow node navigator searches and focuses nodes', (
    tester,
  ) async {
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runStatus: RunStatus.running,
      executionFocus: const RuntimeExecutionFocus(
        activeNodeId: 'tap_d',
        completedNodeIds: {'start', 'tap_a', 'tap_b', 'tap_c'},
        failedNodeId: null,
        activeLoopIndex: 1,
        totalLoops: 2,
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-node-navigator')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('workflow-node-navigator-toggle')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('workflow-node-search')),
      '点击 C',
    );
    await tester.pumpAndSettle();

    expect(find.text('点击 · 点击动作'), findsOneWidget);
    expect(find.text('tap_c / tap'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('workflow-navigator-result-tap_c')),
    );
    await tester.pumpAndSettle();

    expect(find.text('节点检查'), findsOneWidget);
    expect(find.text('tap_c'), findsNothing);
    expect(find.text('点击 C'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('workflow-node-search-clear')));
    await tester.pumpAndSettle();
    final currentButton = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('workflow-navigator-current-button')),
    );
    currentButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('tap_d'), findsNothing);
    expect(find.text('点击 D'), findsWidgets);
  });

  testWidgets('workflow node navigator focuses selected node', (tester) async {
    final preview = StudioRuntimeSnapshot.initial();

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    await selectWorkflowNode(tester, 'tap_b');

    await tester.tap(
      find.byKey(const ValueKey('workflow-node-navigator-toggle')),
    );
    await tester.pumpAndSettle();

    final selectedButton = tester.widget<ButtonStyleButton>(
      find.byKey(const ValueKey('workflow-navigator-selected-button')),
    );
    expect(selectedButton.onPressed, isNotNull);
    selectedButton.onPressed!();
    await tester.pumpAndSettle();

    expect(find.text('选中'), findsOneWidget);
    expect(find.text('点击 B'), findsWidgets);
    expect(find.text('tap_b'), findsNothing);
  });

  testWidgets('workflow canvas summarizes branches in plain Chinese', (
    tester,
  ) async {
    const workflow = WorkflowDefinition(
      id: 'branch-summary-workflow',
      name: '分支摘要',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['condition_1'],
        ),
        WorkflowNode(
          id: 'condition_1',
          type: WorkflowNodeType.condition,
          label: '判断状态',
          next: ['tap_ok', 'tap_else'],
          parameters: {'expression': 'context.ready'},
        ),
        WorkflowNode(
          id: 'tap_ok',
          type: WorkflowNodeType.tap,
          label: '点通过',
          next: ['catch_1'],
          parameters: {'x': 1, 'y': 1, 'label': '点通过'},
        ),
        WorkflowNode(
          id: 'tap_else',
          type: WorkflowNodeType.tap,
          label: '点否则',
          next: ['end'],
          parameters: {'x': 2, 'y': 2, 'label': '点否则'},
        ),
        WorkflowNode(
          id: 'catch_1',
          type: WorkflowNodeType.catchNodes,
          label: '失败兜底',
          next: ['visual_1'],
          parameters: {'maxRetries': 1, 'onError': 'tap_else'},
        ),
        WorkflowNode(
          id: 'visual_1',
          type: WorkflowNodeType.visualBranch,
          label: '看状态',
          next: ['loop_1'],
          parameters: {'confidenceThreshold': 0.7},
        ),
        WorkflowNode(
          id: 'loop_1',
          type: WorkflowNodeType.loop,
          label: '循环检查',
          next: ['tap_ok', 'end'],
          parameters: {'count': 2},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow);

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(find.text('满足 点通过 · 否则 点否则'), findsOneWidget);
    expect(find.text('主线 看状态 · 错误 点否则'), findsOneWidget);
    expect(find.text('通过 循环检查'), findsOneWidget);
    expect(find.text('主体 点通过 · 后续 结束'), findsOneWidget);
    expect(find.text('tap_ok, tap_else'), findsNothing);
    expect(find.text('visual_1'), findsNothing);
  });

  testWidgets(
    'workflow canvas selected branch edge explains route in Chinese',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      const workflow = WorkflowDefinition(
        id: 'branch-edge-workflow',
        name: '分支连线',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['condition_1'],
            visual: WorkflowNodeVisual(x: 80, y: 180),
          ),
          WorkflowNode(
            id: 'condition_1',
            type: WorkflowNodeType.condition,
            label: '检查状态',
            next: ['tap_ok', 'tap_else'],
            parameters: {'expression': 'context.ready'},
            visual: WorkflowNodeVisual(x: 320, y: 180),
          ),
          WorkflowNode(
            id: 'tap_ok',
            type: WorkflowNodeType.tap,
            label: '通过动作',
            next: ['end'],
            parameters: {'x': 1, 'y': 1, 'label': '通过'},
            visual: WorkflowNodeVisual(x: 620, y: 90),
          ),
          WorkflowNode(
            id: 'tap_else',
            type: WorkflowNodeType.tap,
            label: '兜底动作',
            next: ['end'],
            parameters: {'x': 2, 'y': 2, 'label': '兜底'},
            visual: WorkflowNodeVisual(x: 620, y: 290),
          ),
          WorkflowNode(
            id: 'end',
            type: WorkflowNodeType.end,
            label: '结束',
            visual: WorkflowNodeVisual(x: 900, y: 180),
          ),
        ],
      );
      final controller = StudioRuntimeController();
      expect(await controller.updateWorkflow(workflow), isTrue);

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byTooltip('适应画布'));
      await tester.pump(const Duration(milliseconds: 250));

      final conditionOutput = tester.getCenter(
        find.byKey(const ValueKey('workflow-output-port-condition_1')),
      );
      final okInput = tester.getCenter(
        find.byKey(const ValueKey('workflow-input-port-tap_ok')),
      );
      await tester.tapAt(conditionOutput + (okInput - conditionOutput) / 2);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('满足：检查状态 → 通过动作'), findsOneWidget);
      expect(find.text('condition_1 -> tap_ok'), findsNothing);

      final elseInput = tester.getCenter(
        find.byKey(const ValueKey('workflow-input-port-tap_else')),
      );
      await tester.tapAt(conditionOutput + (elseInput - conditionOutput) / 2);
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('否则：检查状态 → 兜底动作'), findsOneWidget);
      expect(find.text('condition_1 -> tap_else'), findsNothing);
    },
  );
}
