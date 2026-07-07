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
// Workflow 画布连线、选边、删边和边插入回归。
// 每个用例只覆盖一个画布子域，避免综合测试继续膨胀。

// 构造允许新增第二分支的合法画布测试流程。
// Start 保持单主线，Condition 负责承载分支连线场景。
WorkflowDefinition _branchConnectionWorkflow() {
  return const WorkflowDefinition(
    id: 'branch-connection',
    name: '分支连线',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['branch'],
        visual: WorkflowNodeVisual(x: 80, y: 260),
      ),
      WorkflowNode(
        id: 'branch',
        type: WorkflowNodeType.condition,
        label: '分支判断',
        next: ['tap_a'],
        parameters: {'expression': 'context.runStatus'},
        visual: WorkflowNodeVisual(x: 320, y: 260),
      ),
      WorkflowNode(
        id: 'tap_a',
        type: WorkflowNodeType.tap,
        label: '点击 A',
        next: ['wait_ab'],
        parameters: {'x': 10, 'y': 20, 'label': '点击 A'},
        visual: WorkflowNodeVisual(x: 560, y: 160),
      ),
      WorkflowNode(
        id: 'wait_ab',
        type: WorkflowNodeType.wait,
        label: '等待 50ms',
        next: ['tap_b'],
        parameters: {'ms': 50},
        visual: WorkflowNodeVisual(x: 560, y: 380),
      ),
      WorkflowNode(
        id: 'tap_b',
        type: WorkflowNodeType.tap,
        label: '点击 B',
        next: ['end'],
        parameters: {'x': 30, 'y': 40, 'label': '点击 B'},
        visual: WorkflowNodeVisual(x: 820, y: 280),
      ),
      WorkflowNode(
        id: 'end',
        type: WorkflowNodeType.end,
        label: '结束',
        visual: WorkflowNodeVisual(x: 1060, y: 280),
      ),
    ],
  );
}

void main() {
  testWidgets('workflow canvas ports connect nodes through project DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    expect(
      await controller.updateWorkflow(_branchConnectionWorkflow()),
      isTrue,
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey('workflow-output-port-branch')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('从 分支判断 连接'), findsOneWidget);
    expect(find.text('从 branch 连接'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('workflow-input-port-wait_ab')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final branch = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'branch',
    );
    expect(branch.next, ['tap_a', 'wait_ab']);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"wait_ab"'), findsWidgets);
  });

  testWidgets('workflow canvas drag connects endpoint through project DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    expect(
      await controller.updateWorkflow(_branchConnectionWorkflow()),
      isTrue,
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final outputPort = find.byKey(
      const ValueKey('workflow-output-port-branch'),
    );
    final inputPort = find.byKey(const ValueKey('workflow-input-port-wait_ab'));
    final outputCenter = tester.getCenter(outputPort);
    final inputCenter = tester.getCenter(inputPort);

    await tester.timedDragFrom(
      outputCenter,
      inputCenter - outputCenter,
      const Duration(milliseconds: 320),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(branch.next, ['tap_a', 'wait_ab']);
    expect(find.text('连接已添加。'), findsOneWidget);
  });

  testWidgets('workflow canvas selects and deletes edge through project DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    expect(
      await controller.updateWorkflow(_branchConnectionWorkflow()),
      isTrue,
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final outputPort = find.byKey(
      const ValueKey('workflow-output-port-branch'),
    );
    final inputPort = find.byKey(const ValueKey('workflow-input-port-wait_ab'));
    final outputCenter = tester.getCenter(outputPort);
    final inputCenter = tester.getCenter(inputPort);

    await tester.timedDragFrom(
      outputCenter,
      inputCenter - outputCenter,
      const Duration(milliseconds: 320),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var workflow = controller.snapshot.workflow;
    var branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(branch.next, ['tap_a', 'wait_ab']);

    final branchRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-branch')),
    );
    final waitRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-wait_ab')),
    );
    final edgeTapPosition = Offset(
      branchRect.center.dx + (waitRect.center.dx - branchRect.center.dx) / 2,
      branchRect.bottom + (waitRect.top - branchRect.bottom) / 2,
    );

    await tester.tapAt(edgeTapPosition);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-delete-selected-edge')),
      findsOneWidget,
    );
    expect(find.text('否则：分支判断 → 等待 50ms'), findsOneWidget);
    expect(find.text('branch -> wait_ab'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('workflow-delete-selected-edge')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(branch.next, ['tap_a']);
    expect(
      find.byKey(const ValueKey('workflow-delete-selected-edge')),
      findsNothing,
    );
  });

  testWidgets('workflow canvas keyboard deletes selected edge through DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    expect(
      await controller.updateWorkflow(_branchConnectionWorkflow()),
      isTrue,
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final outputPort = find.byKey(
      const ValueKey('workflow-output-port-branch'),
    );
    final inputPort = find.byKey(const ValueKey('workflow-input-port-wait_ab'));
    final outputCenter = tester.getCenter(outputPort);
    final inputCenter = tester.getCenter(inputPort);

    await tester.timedDragFrom(
      outputCenter,
      inputCenter - outputCenter,
      const Duration(milliseconds: 320),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var workflow = controller.snapshot.workflow;
    var branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(branch.next, ['tap_a', 'wait_ab']);

    final branchRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-branch')),
    );
    final waitRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-wait_ab')),
    );
    final edgeTapPosition = Offset(
      branchRect.center.dx + (waitRect.center.dx - branchRect.center.dx) / 2,
      branchRect.bottom + (waitRect.top - branchRect.bottom) / 2,
    );

    await tester.tapAt(edgeTapPosition);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-delete-selected-edge')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(branch.next, ['tap_a']);
    expect(
      find.byKey(const ValueKey('workflow-delete-selected-edge')),
      findsNothing,
    );
  });

  testWidgets('workflow canvas retargets selected edge through project DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    expect(
      await controller.updateWorkflow(_branchConnectionWorkflow()),
      isTrue,
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final outputPort = find.byKey(
      const ValueKey('workflow-output-port-branch'),
    );
    final inputPort = find.byKey(const ValueKey('workflow-input-port-wait_ab'));
    final outputCenter = tester.getCenter(outputPort);
    final inputCenter = tester.getCenter(inputPort);

    await tester.timedDragFrom(
      outputCenter,
      inputCenter - outputCenter,
      const Duration(milliseconds: 320),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var workflow = controller.snapshot.workflow;
    var branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(branch.next, ['tap_a', 'wait_ab']);

    final branchRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-branch')),
    );
    final waitRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-wait_ab')),
    );
    final edgeTapPosition = Offset(
      branchRect.center.dx + (waitRect.center.dx - branchRect.center.dx) / 2,
      branchRect.bottom + (waitRect.top - branchRect.bottom) / 2,
    );

    await tester.tapAt(edgeTapPosition);
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-edge-retarget-menu')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('workflow-edge-retarget-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('workflow-edge-retarget-tap_b')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(branch.next, ['tap_a', 'tap_b']);

    await tester.tap(find.byKey(const ValueKey('workflow-undo')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(branch.next, ['tap_a', 'wait_ab']);

    await tester.tap(find.byKey(const ValueKey('workflow-redo')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(branch.next, ['tap_a', 'tap_b']);
  });

  testWidgets('workflow canvas retargets catch error edge through DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    final workflow = WorkflowDefinition(
      id: 'catch-retarget',
      name: '错误分支重接',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['catch_guard'],
          visual: WorkflowNodeVisual(x: 80, y: 260),
        ),
        WorkflowNode(
          id: 'catch_guard',
          type: WorkflowNodeType.catchNodes,
          label: '异常保护',
          next: ['tap_main'],
          parameters: {'maxRetries': 1, 'onError': 'wait_recover'},
          visual: WorkflowNodeVisual(x: 320, y: 260),
        ),
        WorkflowNode(
          id: 'tap_main',
          type: WorkflowNodeType.tap,
          label: '主点击',
          next: ['wait_recover'],
          parameters: {'x': 20, 'y': 20, 'label': '主点击'},
          visual: WorkflowNodeVisual(x: 560, y: 180),
        ),
        WorkflowNode(
          id: 'wait_recover',
          type: WorkflowNodeType.wait,
          label: '恢复等待',
          next: ['tap_alt'],
          parameters: {'ms': 500},
          visual: WorkflowNodeVisual(x: 560, y: 380),
        ),
        WorkflowNode(
          id: 'tap_alt',
          type: WorkflowNodeType.tap,
          label: '备用点击',
          next: ['end'],
          parameters: {'x': 40, 'y': 40, 'label': '备用点击'},
          visual: WorkflowNodeVisual(x: 800, y: 380),
        ),
        WorkflowNode(
          id: 'end',
          type: WorkflowNodeType.end,
          label: '结束',
          visual: WorkflowNodeVisual(x: 1040, y: 280),
        ),
      ],
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(await controller.updateWorkflow(workflow), isTrue);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final catchRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-catch_guard')),
    );
    final recoverRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-wait_recover')),
    );
    final edgeTapPosition = Offset(
      catchRect.center.dx + (recoverRect.center.dx - catchRect.center.dx) / 2,
      catchRect.bottom + (recoverRect.top - catchRect.bottom) / 2,
    );

    await tester.tapAt(edgeTapPosition);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('错误：异常保护 → 恢复等待'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workflow-edge-retarget-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('workflow-edge-retarget-tap_alt')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final updatedWorkflow = controller.snapshot.workflow;
    final catchNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'catch_guard',
    );
    expect(const WorkflowValidator().validate(updatedWorkflow).isValid, isTrue);
    expect(catchNode.next, ['tap_main']);
    expect(catchNode.parameters['onError'], 'tap_alt');
  });

  testWidgets('workflow canvas retargets selected edge source through DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    final workflow = WorkflowDefinition(
      id: 'source-retarget',
      name: '起点重接',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['branch'],
          visual: WorkflowNodeVisual(x: 80, y: 320),
        ),
        WorkflowNode(
          id: 'branch',
          type: WorkflowNodeType.condition,
          label: '分支判断',
          next: ['tap_a', 'wait_b'],
          parameters: {'expression': 'context.runStatus'},
          visual: WorkflowNodeVisual(x: 300, y: 320),
        ),
        WorkflowNode(
          id: 'tap_a',
          type: WorkflowNodeType.tap,
          label: '原目标',
          next: ['end'],
          parameters: {'x': 20, 'y': 20, 'label': '原目标'},
          visual: WorkflowNodeVisual(x: 560, y: 160),
        ),
        WorkflowNode(
          id: 'wait_b',
          type: WorkflowNodeType.wait,
          label: '新起点',
          parameters: {'ms': 500},
          visual: WorkflowNodeVisual(x: 560, y: 420),
        ),
        WorkflowNode(
          id: 'end',
          type: WorkflowNodeType.end,
          label: '结束',
          visual: WorkflowNodeVisual(x: 920, y: 280),
        ),
      ],
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(await controller.updateWorkflow(workflow), isTrue);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final branchRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-branch')),
    );
    final tapRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-tap_a')),
    );
    final outputCenter = Offset(branchRect.center.dx, branchRect.bottom);
    final inputCenter = Offset(tapRect.center.dx, tapRect.top);
    final edgeTapPosition = Offset(
      outputCenter.dx + (inputCenter.dx - outputCenter.dx) / 2,
      outputCenter.dy + (inputCenter.dy - outputCenter.dy) / 2,
    );

    await tester.tapAt(edgeTapPosition);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('满足：分支判断 → 原目标'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workflow-edge-source-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workflow-edge-source-wait_b')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var updatedWorkflow = controller.snapshot.workflow;
    var branchNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'branch',
    );
    var waitNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'wait_b',
    );
    expect(const WorkflowValidator().validate(updatedWorkflow).isValid, isTrue);
    expect(branchNode.next, ['wait_b']);
    expect(waitNode.next, ['tap_a']);

    await tester.tap(find.byKey(const ValueKey('workflow-undo')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    updatedWorkflow = controller.snapshot.workflow;
    branchNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'branch',
    );
    waitNode = updatedWorkflow.nodes.firstWhere((node) => node.id == 'wait_b');
    expect(const WorkflowValidator().validate(updatedWorkflow).isValid, isTrue);
    expect(branchNode.next, ['tap_a', 'wait_b']);
    expect(waitNode.next, isEmpty);

    await tester.tap(find.byKey(const ValueKey('workflow-redo')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    updatedWorkflow = controller.snapshot.workflow;
    branchNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'branch',
    );
    waitNode = updatedWorkflow.nodes.firstWhere((node) => node.id == 'wait_b');
    expect(const WorkflowValidator().validate(updatedWorkflow).isValid, isTrue);
    expect(branchNode.next, ['wait_b']);
    expect(waitNode.next, ['tap_a']);
  });

  testWidgets('workflow canvas retargets catch error edge source through DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    final workflow = WorkflowDefinition(
      id: 'catch-source-retarget',
      name: '错误起点重接',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['branch'],
          visual: WorkflowNodeVisual(x: 80, y: 260),
        ),
        WorkflowNode(
          id: 'branch',
          type: WorkflowNodeType.condition,
          label: '分支判断',
          next: ['catch_guard', 'catch_backup'],
          parameters: {'expression': 'context.runStatus'},
          visual: WorkflowNodeVisual(x: 280, y: 260),
        ),
        WorkflowNode(
          id: 'catch_guard',
          type: WorkflowNodeType.catchNodes,
          label: '异常保护',
          next: ['tap_main'],
          parameters: {'maxRetries': 1, 'onError': 'wait_recover'},
          visual: WorkflowNodeVisual(x: 500, y: 220),
        ),
        WorkflowNode(
          id: 'catch_backup',
          type: WorkflowNodeType.catchNodes,
          label: '备用保护',
          next: ['tap_main'],
          parameters: {'maxRetries': 1},
          visual: WorkflowNodeVisual(x: 500, y: 420),
        ),
        WorkflowNode(
          id: 'tap_main',
          type: WorkflowNodeType.tap,
          label: '主点击',
          next: ['end'],
          parameters: {'x': 20, 'y': 20, 'label': '主点击'},
          visual: WorkflowNodeVisual(x: 740, y: 220),
        ),
        WorkflowNode(
          id: 'wait_recover',
          type: WorkflowNodeType.wait,
          label: '恢复等待',
          next: ['end'],
          parameters: {'ms': 500},
          visual: WorkflowNodeVisual(x: 740, y: 420),
        ),
        WorkflowNode(
          id: 'end',
          type: WorkflowNodeType.end,
          label: '结束',
          visual: WorkflowNodeVisual(x: 1000, y: 320),
        ),
      ],
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(await controller.updateWorkflow(workflow), isTrue);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final catchRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-catch_guard')),
    );
    final recoverRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-wait_recover')),
    );
    final edgeTapPosition = Offset(
      catchRect.center.dx + (recoverRect.center.dx - catchRect.center.dx) / 2,
      catchRect.bottom + (recoverRect.top - catchRect.bottom) / 2,
    );

    await tester.tapAt(edgeTapPosition);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('错误：异常保护 → 恢复等待'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('workflow-edge-source-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('workflow-edge-source-catch_backup')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final updatedWorkflow = controller.snapshot.workflow;
    final catchNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'catch_guard',
    );
    final backupNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'catch_backup',
    );
    expect(const WorkflowValidator().validate(updatedWorkflow).isValid, isTrue);
    expect(catchNode.parameters['onError'], isNull);
    expect(backupNode.parameters['onError'], 'wait_recover');
  });

  testWidgets(
    'workflow canvas inserts wait node on selected edge through DSL',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = StudioRuntimeController();

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byTooltip('适应画布'));
      await tester.pump(const Duration(milliseconds: 250));

      final startRect = tester.getRect(
        find.byKey(const ValueKey('workflow-node-start')),
      );
      final tapRect = tester.getRect(
        find.byKey(const ValueKey('workflow-node-tap_a')),
      );
      final edgeTapPosition = Offset(
        startRect.center.dx + (tapRect.center.dx - startRect.center.dx) / 2,
        startRect.bottom + (tapRect.top - startRect.bottom) / 2,
      );

      await tester.tapAt(edgeTapPosition);
      await tester.pump(const Duration(milliseconds: 250));

      expect(
        find.byKey(const ValueKey('workflow-edge-insert-wait')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('workflow-edge-insert-wait')));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final workflow = controller.snapshot.workflow;
      final start = workflow.nodes.firstWhere((node) => node.id == 'start');
      final inserted = workflow.nodes.firstWhere(
        (node) => node.id == 'wait_new_1',
      );
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
      expect(start.next, ['wait_new_1']);
      expect(inserted.type, WorkflowNodeType.wait);
      expect(inserted.next, ['tap_a']);
      expect(inserted.parameters['ms'], 500);
      expect(
        find.byKey(const ValueKey('workflow-node-wait_new_1')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'workflow canvas insert menu adds condition node on selected edge',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final controller = StudioRuntimeController();

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.byTooltip('适应画布'));
      await tester.pump(const Duration(milliseconds: 250));

      final startRect = tester.getRect(
        find.byKey(const ValueKey('workflow-node-start')),
      );
      final tapRect = tester.getRect(
        find.byKey(const ValueKey('workflow-node-tap_a')),
      );
      final edgeTapPosition = Offset(
        startRect.center.dx + (tapRect.center.dx - startRect.center.dx) / 2,
        startRect.bottom + (tapRect.top - startRect.bottom) / 2,
      );

      await tester.tapAt(edgeTapPosition);
      await tester.pump(const Duration(milliseconds: 250));

      await tester.tap(find.byKey(const ValueKey('workflow-edge-insert-menu')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('workflow-edge-insert-condition')),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final workflow = controller.snapshot.workflow;
      final start = workflow.nodes.firstWhere((node) => node.id == 'start');
      final inserted = workflow.nodes.firstWhere(
        (node) => node.id == 'condition_new_1',
      );
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
      expect(start.next, ['condition_new_1']);
      expect(inserted.type, WorkflowNodeType.condition);
      expect(inserted.next, ['tap_a']);
      expect(inserted.parameters['expression'], 'context.flag');
      expect(
        find.byKey(const ValueKey('workflow-node-condition_new_1')),
        findsOneWidget,
      );
    },
  );
}
