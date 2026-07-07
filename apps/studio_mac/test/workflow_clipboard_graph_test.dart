import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Canvas 复杂图剪贴板回归测试。
// 用例聚焦图结构重映射，确保复制粘贴仍通过 Project DSL validator。
void main() {
  // 验证分支子图复制后，真假分支与终点连线都会被正确重映射。
  testWidgets('workflow canvas clipboard preserves branch subgraph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final copiedText = captureClipboardText();

    final sourceController = StudioRuntimeController();
    expect(
      await sourceController.updateWorkflow(branchClipboardSourceWorkflow()),
      isTrue,
    );
    await tester.pumpWidget(
      StudioMacApp(controllerFactory: () => sourceController),
    );

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byTooltip('框选'));
    await tester.pump(const Duration(milliseconds: 250));

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
    );
    await tester.timedDragFrom(
      overlayRect.topLeft + const Offset(120, 70),
      const Offset(520, 360),
      const Duration(milliseconds: 320),
    );
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    expect(copiedText(), contains('condition_1'));
    expect(copiedText(), contains('true_tap'));
    expect(copiedText(), contains('false_tap'));
    expect(copiedText(), isNot(contains('session')));
    expect(copiedText(), isNot(contains('WDA')));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));

    final targetController = StudioRuntimeController();
    expect(
      await targetController.updateWorkflow(
        const WorkflowDefinition(
          id: 'branch-target',
          name: '分支目标',
          entryNodesId: 'start',
          nodes: [
            WorkflowNode(
              id: 'start',
              type: WorkflowNodeType.start,
              label: '开始',
              next: ['end'],
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      ),
      isTrue,
    );
    await tester.pumpWidget(
      StudioMacApp(controllerFactory: () => targetController),
    );

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'start');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = targetController.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final condition = workflow.nodes.firstWhere(
      (node) => node.id == 'condition_new_1',
    );
    final trueTap = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    final falseTap = workflow.nodes.firstWhere(
      (node) => node.id == 'tap_new_2',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['condition_new_1']);
    expect(condition.type, WorkflowNodeType.condition);
    expect(condition.next, ['tap_new_1', 'tap_new_2']);
    expect(condition.parameters['expression'], 'context.flag');
    expect(trueTap.next, ['end']);
    expect(falseTap.next, ['end']);
    expect(find.text('已选 3 个'), findsOneWidget);
  });

  // 验证 Catch 的外部错误出口在复制后仍能指向正确兜底节点。
  testWidgets('workflow canvas clipboard preserves external catch error exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final clipboardText = workflowClipboardText([
      const WorkflowNode(
        id: 'catch_source',
        type: WorkflowNodeType.catchNodes,
        label: '异常保护',
        parameters: {'maxRetries': 1, 'onError': 'outside_recover'},
        visual: WorkflowNodeVisual(x: 220, y: 160),
      ),
    ]);
    captureClipboardText(clipboardText);

    final controller = StudioRuntimeController();
    expect(
      await controller.updateWorkflow(
        const WorkflowDefinition(
          id: 'catch-external-target',
          name: '错误出口目标',
          entryNodesId: 'start',
          nodes: [
            WorkflowNode(
              id: 'start',
              type: WorkflowNodeType.start,
              label: '开始',
              next: ['end'],
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      ),
      isTrue,
    );
    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'start');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final catchCopy = workflow.nodes.firstWhere(
      (node) => node.id == 'catchNodes_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['catchNodes_new_1']);
    expect(catchCopy.next, ['end']);
    expect(catchCopy.parameters['onError'], 'end');
    expect(
      find.byKey(const ValueKey('workflow-node-catchNodes_new_1')),
      findsOneWidget,
    );
  });

  // 验证 Loop 包 Catch 的嵌套子图复制后，主线、错误线和回边都保持合法。
  testWidgets(
    'workflow canvas clipboard preserves nested loop catch subgraph',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final clipboardText = workflowClipboardText([
        const WorkflowNode(
          id: 'loop_source',
          type: WorkflowNodeType.loop,
          label: '循环保护',
          next: ['catch_source', 'outside_after'],
          parameters: {'count': 2},
          visual: WorkflowNodeVisual(x: 180, y: 180),
        ),
        const WorkflowNode(
          id: 'catch_source',
          type: WorkflowNodeType.catchNodes,
          label: '保护点击',
          next: ['risky_tap'],
          parameters: {'maxRetries': 1, 'onError': 'recover_tap'},
          visual: WorkflowNodeVisual(x: 420, y: 120),
        ),
        const WorkflowNode(
          id: 'risky_tap',
          type: WorkflowNodeType.tap,
          label: '主线点击',
          next: ['loop_source'],
          parameters: {'x': 100, 'y': 200},
          visual: WorkflowNodeVisual(x: 680, y: 80),
        ),
        const WorkflowNode(
          id: 'recover_tap',
          type: WorkflowNodeType.tap,
          label: '错误恢复',
          next: ['loop_source'],
          parameters: {'x': 120, 'y': 220},
          visual: WorkflowNodeVisual(x: 680, y: 240),
        ),
      ]);
      captureClipboardText(clipboardText);

      final controller = StudioRuntimeController();
      expect(
        await controller.updateWorkflow(
          const WorkflowDefinition(
            id: 'nested-control-target',
            name: '嵌套控制目标',
            entryNodesId: 'start',
            nodes: [
              WorkflowNode(
                id: 'start',
                type: WorkflowNodeType.start,
                label: '开始',
                next: ['end'],
              ),
              WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
            ],
          ),
        ),
        isTrue,
      );
      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await selectWorkflowNode(tester, 'start');
      await tester.pump(const Duration(milliseconds: 250));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final workflow = controller.snapshot.workflow;
      final start = workflow.nodes.firstWhere((node) => node.id == 'start');
      final loop = workflow.nodes.firstWhere((node) => node.id == 'loop_new_1');
      final catchCopy = workflow.nodes.firstWhere(
        (node) => node.id == 'catchNodes_new_1',
      );
      final riskyTap = workflow.nodes.firstWhere(
        (node) => node.id == 'tap_new_1',
      );
      final recoverTap = workflow.nodes.firstWhere(
        (node) => node.id == 'tap_new_2',
      );
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
      expect(start.next, ['loop_new_1']);
      expect(loop.next, ['catchNodes_new_1', 'end']);
      expect(loop.parameters['count'], 2);
      expect(catchCopy.next, ['tap_new_1']);
      expect(catchCopy.parameters['onError'], 'tap_new_2');
      expect(riskyTap.next, ['loop_new_1']);
      expect(recoverTap.next, ['loop_new_1']);
      expect(find.text('已选 4 个'), findsOneWidget);
    },
  );

  // 验证多入口汇合子图粘贴时，会串成单入口流程，避免普通节点变成分支。
  testWidgets(
    'workflow canvas clipboard serializes multi-entry merge subgraph',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final clipboardText = workflowClipboardText([
        const WorkflowNode(
          id: 'left_tap',
          type: WorkflowNodeType.tap,
          label: '左路',
          next: ['merge_wait'],
          parameters: {'x': 80, 'y': 160},
          visual: WorkflowNodeVisual(x: 220, y: 120),
        ),
        const WorkflowNode(
          id: 'right_tap',
          type: WorkflowNodeType.tap,
          label: '右路',
          next: ['merge_wait'],
          parameters: {'x': 180, 'y': 260},
          visual: WorkflowNodeVisual(x: 220, y: 300),
        ),
        const WorkflowNode(
          id: 'merge_wait',
          type: WorkflowNodeType.wait,
          label: '汇合等待',
          next: ['outside_end'],
          parameters: {'ms': 300},
          visual: WorkflowNodeVisual(x: 520, y: 210),
        ),
      ]);
      captureClipboardText(clipboardText);

      final controller = StudioRuntimeController();
      expect(
        await controller.updateWorkflow(
          const WorkflowDefinition(
            id: 'multi-entry-target',
            name: '多入口目标',
            entryNodesId: 'start',
            nodes: [
              WorkflowNode(
                id: 'start',
                type: WorkflowNodeType.start,
                label: '开始',
                next: ['end'],
              ),
              WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
            ],
          ),
        ),
        isTrue,
      );
      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await selectWorkflowNode(tester, 'start');
      await tester.pump(const Duration(milliseconds: 250));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final workflow = controller.snapshot.workflow;
      final start = workflow.nodes.firstWhere((node) => node.id == 'start');
      final leftTap = workflow.nodes.firstWhere(
        (node) => node.id == 'tap_new_1',
      );
      final rightTap = workflow.nodes.firstWhere(
        (node) => node.id == 'tap_new_2',
      );
      final mergeWait = workflow.nodes.firstWhere(
        (node) => node.id == 'wait_new_1',
      );
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
      expect(start.next, ['tap_new_1']);
      expect(leftTap.next, ['tap_new_2']);
      expect(rightTap.next, ['wait_new_1']);
      expect(mergeWait.next, ['end']);
      expect(find.text('已选 3 个'), findsOneWidget);
    },
  );

  // 验证条件锚点能保留双入口汇合子图，不再强制串成线性流程。
  testWidgets(
    'workflow canvas clipboard preserves multi-entry merge under condition anchor',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final clipboardText = workflowClipboardText([
        const WorkflowNode(
          id: 'left_tap',
          type: WorkflowNodeType.tap,
          label: '左路',
          next: ['merge_wait'],
          parameters: {'x': 80, 'y': 160},
          visual: WorkflowNodeVisual(x: 220, y: 120),
        ),
        const WorkflowNode(
          id: 'right_tap',
          type: WorkflowNodeType.tap,
          label: '右路',
          next: ['merge_wait'],
          parameters: {'x': 180, 'y': 260},
          visual: WorkflowNodeVisual(x: 220, y: 300),
        ),
        const WorkflowNode(
          id: 'merge_wait',
          type: WorkflowNodeType.wait,
          label: '汇合等待',
          next: ['outside_end'],
          parameters: {'ms': 300},
          visual: WorkflowNodeVisual(x: 520, y: 210),
        ),
      ]);
      captureClipboardText(clipboardText);

      final controller = StudioRuntimeController();
      expect(
        await controller.updateWorkflow(
          const WorkflowDefinition(
            id: 'condition-multi-entry-target',
            name: '条件汇合目标',
            entryNodesId: 'start',
            nodes: [
              WorkflowNode(
                id: 'start',
                type: WorkflowNodeType.start,
                label: '开始',
                next: ['branch'],
              ),
              WorkflowNode(
                id: 'branch',
                type: WorkflowNodeType.condition,
                label: '条件',
                parameters: {'expression': 'context.flag'},
                next: ['end'],
              ),
              WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
            ],
          ),
        ),
        isTrue,
      );
      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await selectWorkflowNode(tester, 'branch');
      await tester.pump(const Duration(milliseconds: 250));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final workflow = controller.snapshot.workflow;
      final branch = workflow.nodes.firstWhere((node) => node.id == 'branch');
      final leftTap = workflow.nodes.firstWhere(
        (node) => node.id == 'tap_new_1',
      );
      final rightTap = workflow.nodes.firstWhere(
        (node) => node.id == 'tap_new_2',
      );
      final mergeWait = workflow.nodes.firstWhere(
        (node) => node.id == 'wait_new_1',
      );
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
      expect(branch.next, ['tap_new_1', 'tap_new_2']);
      expect(leftTap.next, ['wait_new_1']);
      expect(rightTap.next, ['wait_new_1']);
      expect(mergeWait.next, ['end']);
      expect(find.text('已选 3 个'), findsOneWidget);
    },
  );

  // 验证不连通组件被一起粘贴时，会按安全顺序串回主流程。
  testWidgets('workflow canvas clipboard chains disconnected components', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final clipboardText = workflowClipboardText([
      const WorkflowNode(
        id: 'first_tap',
        type: WorkflowNodeType.tap,
        label: '第一段',
        next: ['outside_end'],
        parameters: {'x': 100, 'y': 200},
        visual: WorkflowNodeVisual(x: 220, y: 120),
      ),
      const WorkflowNode(
        id: 'second_wait',
        type: WorkflowNodeType.wait,
        label: '第二段',
        next: ['outside_end'],
        parameters: {'ms': 300},
        visual: WorkflowNodeVisual(x: 420, y: 260),
      ),
    ]);
    captureClipboardText(clipboardText);

    final controller = StudioRuntimeController();
    expect(
      await controller.updateWorkflow(
        const WorkflowDefinition(
          id: 'disconnected-target',
          name: '多段目标',
          entryNodesId: 'start',
          nodes: [
            WorkflowNode(
              id: 'start',
              type: WorkflowNodeType.start,
              label: '开始',
              next: ['end'],
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      ),
      isTrue,
    );
    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'start');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final tapCopy = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    final waitCopy = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['tap_new_1']);
    expect(tapCopy.label, '复制 第一段');
    expect(tapCopy.next, ['wait_new_1']);
    expect(waitCopy.label, '复制 第二段');
    expect(waitCopy.next, ['end']);
    expect(find.text('已选 2 个'), findsOneWidget);
  });
}
