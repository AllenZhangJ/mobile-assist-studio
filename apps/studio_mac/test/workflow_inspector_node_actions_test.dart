// ignore_for_file: unused_import, unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Inspector 节点动作回归测试，覆盖删除、复制和受保护节点边界。
// 用例只验证图结构重连和 Project DSL validator，不执行 workflow。
void main() {
  testWidgets(
    'workflow node inspector deletes selected node and reconnects graph',
    (tester) async {
      final controller = StudioRuntimeController();

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await selectWorkflowNode(tester, 'wait_ab');
      await tester.pump(const Duration(milliseconds: 250));

      final deleteButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('node-inspector-delete-node')),
      );
      expect(deleteButton.onPressed, isNotNull);
      deleteButton.onPressed!();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final workflow = controller.snapshot.workflow;
      final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
      expect(workflow.nodes.any((node) => node.id == 'wait_ab'), isFalse);
      expect(tapA.next, ['tap_b']);
      expect(find.byKey(const ValueKey('workflow-node-wait_ab')), findsNothing);
      expect(find.textContaining('未选中'), findsOneWidget);
    },
  );

  testWidgets(
    'workflow node inspector reconnects catch error target on delete',
    (tester) async {
      const workflow = WorkflowDefinition(
        id: 'catch-delete-target-workflow',
        name: '错误目标删除',
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
          WorkflowNode(
            id: 'wait_recover',
            type: WorkflowNodeType.wait,
            label: '恢复等待',
            next: ['end'],
            parameters: {'ms': 500},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      final controller = StudioRuntimeController(workflow: workflow);

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await selectWorkflowNode(tester, 'wait_recover');
      await tester.pump(const Duration(milliseconds: 250));

      final deleteButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('node-inspector-delete-node')),
      );
      expect(deleteButton.onPressed, isNotNull);
      deleteButton.onPressed!();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      final updatedWorkflow = controller.snapshot.workflow;
      final catchNode = updatedWorkflow.nodes.firstWhere(
        (node) => node.id == 'catch_1',
      );
      expect(
        updatedWorkflow.nodes.any((node) => node.id == 'wait_recover'),
        isFalse,
      );
      expect(catchNode.parameters['onError'], 'end');
      expect(
        const WorkflowValidator().validate(updatedWorkflow).isValid,
        isTrue,
      );
    },
  );

  testWidgets('workflow node inspector deletes loop without body self-cycle', (
    tester,
  ) async {
    const workflow = WorkflowDefinition(
      id: 'loop-delete',
      name: 'Loop Delete',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['loop_1'],
        ),
        WorkflowNode(
          id: 'loop_1',
          type: WorkflowNodeType.loop,
          label: '循环',
          next: ['wait_body', 'end'],
          parameters: {'count': 2},
        ),
        WorkflowNode(
          id: 'wait_body',
          type: WorkflowNodeType.wait,
          label: '循环等待',
          next: ['loop_1'],
          parameters: {'ms': 500},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController(workflow: workflow);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'loop_1');
    await tester.pump(const Duration(milliseconds: 250));

    final deleteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-delete-node')),
    );
    expect(deleteButton.onPressed, isNotNull);
    deleteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final updatedWorkflow = controller.snapshot.workflow;
    final start = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'start',
    );
    final body = updatedWorkflow.nodes.firstWhere(
      (node) => node.id == 'wait_body',
    );
    expect(updatedWorkflow.nodes.any((node) => node.id == 'loop_1'), isFalse);
    expect(start.next, ['wait_body']);
    expect(body.next, ['end']);
    expect(body.next, isNot(contains('wait_body')));
    expect(const WorkflowValidator().validate(updatedWorkflow).isValid, isTrue);
  });

  testWidgets('workflow node inspector duplicates selected tap node', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'tap_a');
    await tester.pump(const Duration(milliseconds: 250));

    final duplicateButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-duplicate-node')),
    );
    expect(duplicateButton.onPressed, isNotNull);
    duplicateButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final copy = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    expect(tapA.next, ['tap_new_1']);
    expect(copy.type, WorkflowNodeType.tap);
    expect(copy.label, '复制 点击 A');
    expect(copy.next, ['wait_ab']);
    expect(copy.parameters['x'], 92);
    expect(copy.parameters['y'], 499);
    expect(
      find.byKey(const ValueKey('workflow-node-tap_new_1')),
      findsOneWidget,
    );

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"id": "tap_new_1"'), findsOneWidget);
    expect(find.textContaining('"label": "复制 点击 A"'), findsOneWidget);
  });

  testWidgets('workflow node inspector protects start and end from delete', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'start');
    await tester.pump(const Duration(milliseconds: 250));

    var deleteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-delete-node')),
    );
    var duplicateButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-duplicate-node')),
    );
    expect(deleteButton.onPressed, isNull);
    expect(duplicateButton.onPressed, isNull);

    await selectWorkflowNode(tester, 'end');
    await tester.pump(const Duration(milliseconds: 250));

    deleteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-delete-node')),
    );
    final insertTapButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-insert-tap')),
    );
    duplicateButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-duplicate-node')),
    );
    expect(deleteButton.onPressed, isNull);
    expect(insertTapButton.onPressed, isNull);
    expect(duplicateButton.onPressed, isNull);
  });
}
