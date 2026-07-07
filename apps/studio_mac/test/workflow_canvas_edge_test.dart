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
// Workflow 画布 Catch 错误边和布局回归。
// 每个用例只覆盖一个画布子域，避免综合测试继续膨胀。
void main() {
  testWidgets('workflow canvas deletes catch error edge through project DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const workflow = WorkflowDefinition(
      id: 'catch-error-delete-workflow',
      name: '错误边删除',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['catch_1'],
          visual: WorkflowNodeVisual(x: 80, y: 180),
        ),
        WorkflowNode(
          id: 'catch_1',
          type: WorkflowNodeType.catchNodes,
          label: '兜底保护',
          next: ['tap_main'],
          parameters: {'maxRetries': 1, 'onError': 'end'},
          visual: WorkflowNodeVisual(x: 320, y: 180),
        ),
        WorkflowNode(
          id: 'tap_main',
          type: WorkflowNodeType.tap,
          label: '主线点击',
          next: ['end'],
          parameters: {'x': 1, 'y': 1, 'label': '主线'},
          visual: WorkflowNodeVisual(x: 620, y: 90),
        ),
        WorkflowNode(
          id: 'end',
          type: WorkflowNodeType.end,
          label: '结束',
          visual: WorkflowNodeVisual(x: 620, y: 290),
        ),
      ],
    );
    final controller = StudioRuntimeController();
    expect(await controller.updateWorkflow(workflow), isTrue);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final catchOutput = tester.getCenter(
      find.byKey(const ValueKey('workflow-output-port-catch_1')),
    );
    final endInput = tester.getCenter(
      find.byKey(const ValueKey('workflow-input-port-end')),
    );
    await tester.tapAt(catchOutput + (endInput - catchOutput) / 2);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('错误：兜底保护 → 结束'), findsOneWidget);
    expect(find.text('catch_1 -> end'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('workflow-delete-selected-edge')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final catchNode = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'catch_1',
    );
    expect(catchNode.next, ['tap_main']);
    expect(catchNode.parameters.containsKey('onError'), isFalse);
    expect(
      const WorkflowValidator().validate(controller.snapshot.workflow).isValid,
      isTrue,
    );
  });

  testWidgets('workflow canvas inserts wait on catch error edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const workflow = WorkflowDefinition(
      id: 'catch-error-insert-workflow',
      name: '错误边插入',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['catch_1'],
          visual: WorkflowNodeVisual(x: 80, y: 180),
        ),
        WorkflowNode(
          id: 'catch_1',
          type: WorkflowNodeType.catchNodes,
          label: '兜底保护',
          next: ['tap_main'],
          parameters: {'maxRetries': 1, 'onError': 'wait_recover'},
          visual: WorkflowNodeVisual(x: 320, y: 180),
        ),
        WorkflowNode(
          id: 'tap_main',
          type: WorkflowNodeType.tap,
          label: '主线点击',
          next: ['end'],
          parameters: {'x': 1, 'y': 1, 'label': '主线'},
          visual: WorkflowNodeVisual(x: 620, y: 90),
        ),
        WorkflowNode(
          id: 'wait_recover',
          type: WorkflowNodeType.wait,
          label: '恢复等待',
          next: ['end'],
          parameters: {'ms': 500},
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

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final catchOutput = tester.getCenter(
      find.byKey(const ValueKey('workflow-output-port-catch_1')),
    );
    final recoverInput = tester.getCenter(
      find.byKey(const ValueKey('workflow-input-port-wait_recover')),
    );
    await tester.tapAt(catchOutput + (recoverInput - catchOutput) / 2);
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey('workflow-edge-insert-wait')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final updatedWorkflow = controller.snapshot.workflow;
    final catchNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'catch_1',
    );
    final insertedId = catchNode.parameters['onError'];
    expect(insertedId, isA<String>());
    expect(insertedId, isNot('wait_recover'));
    final insertedNode = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == insertedId,
    );
    expect(insertedNode.type, WorkflowNodeType.wait);
    expect(insertedNode.next, ['wait_recover']);
    expect(const WorkflowValidator().validate(updatedWorkflow).isValid, isTrue);
  });

  testWidgets('workflow canvas auto layout includes catch error edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const workflow = WorkflowDefinition(
      id: 'catch-error-layout-workflow',
      name: '错误边布局',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['catch_1'],
        ),
        WorkflowNode(
          id: 'catch_1',
          type: WorkflowNodeType.catchNodes,
          label: '兜底保护',
          next: ['tap_main'],
          parameters: {'maxRetries': 1, 'onError': 'wait_recover'},
        ),
        WorkflowNode(
          id: 'tap_main',
          type: WorkflowNodeType.tap,
          label: '主线点击',
          next: ['end'],
          parameters: {'x': 1, 'y': 1, 'label': '主线'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        WorkflowNode(
          id: 'wait_recover',
          type: WorkflowNodeType.wait,
          label: '恢复等待',
          next: ['end'],
          parameters: {'ms': 500},
        ),
      ],
    );
    final controller = StudioRuntimeController();
    expect(await controller.updateWorkflow(workflow), isTrue);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('适应画布'));
    await tester.pump(const Duration(milliseconds: 250));

    final catchRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-catch_1')),
    );
    final recoverRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-wait_recover')),
    );
    final endRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-end')),
    );
    expect(recoverRect.center.dy, lessThan(endRect.center.dy));

    await tester.tapAt(
      catchRect.bottomCenter +
          (recoverRect.topCenter - catchRect.bottomCenter) / 2,
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('错误：兜底保护 → 恢复等待'), findsOneWidget);
    expect(find.byKey(const ValueKey('workflow-mini-map')), findsOneWidget);
  });
}
