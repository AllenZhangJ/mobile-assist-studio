// ignore_for_file: unused_import, unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Inspector 基础编辑回归测试，覆盖常用节点字段、连接和插入。
// 用例只验证 Project DSL 编辑结果，不连接真实设备、不执行 workflow。

// 构造 Inspector 连接测试用的合法分支流程。
// Start 只保留单主线，新增连接由 Condition 节点承载。
WorkflowDefinition _inspectorBranchWorkflow() {
  return const WorkflowDefinition(
    id: 'inspector-branch',
    name: '检查分支',
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
        label: '分支判断',
        next: ['tap_a'],
        parameters: {'expression': 'context.runStatus'},
      ),
      WorkflowNode(
        id: 'tap_a',
        type: WorkflowNodeType.tap,
        label: '点击 A',
        next: ['wait_ab'],
        parameters: {'x': 10, 'y': 20, 'label': '点击 A'},
      ),
      WorkflowNode(
        id: 'wait_ab',
        type: WorkflowNodeType.wait,
        label: '等待 50ms',
        next: ['end'],
        parameters: {'ms': 50},
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}

void main() {
  testWidgets('workflow node inspector edits tap node properties', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'tap_a');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('节点检查'), findsOneWidget);
    expect(find.text('点击 A'), findsWidgets);
    expect(find.text('tap_a'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('node-inspector-x')))
          .decoration
          ?.labelText,
      '横',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('node-inspector-y')))
          .decoration
          ?.labelText,
      '纵',
    );
    expect(find.text('X'), findsNothing);
    expect(find.text('Y'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-label')),
      '点登录 CTA',
    );
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-x')),
      '111',
    );
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-y')),
      '222',
    );
    await tester.pump(const Duration(milliseconds: 250));

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('node-inspector-save')),
    );
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final editedNodes = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'tap_a',
    );
    expect(editedNodes.label, '点登录 CTA');
    expect(editedNodes.parameters['x'], 111);
    expect(editedNodes.parameters['y'], 222);
    expect(find.text('点登录 CTA'), findsWidgets);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"label": "点登录 CTA"'), findsWidgets);
    expect(find.textContaining('"x": 111'), findsOneWidget);
  });

  testWidgets('workflow node inspector edits wait duration', (tester) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'wait_ab');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('节点检查'), findsOneWidget);
    expect(find.text('等待 50ms'), findsWidgets);
    expect(find.text('wait_ab'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('node-inspector-ms')))
          .decoration
          ?.labelText,
      '等待',
    );
    expect(find.text('等待毫秒'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-ms')),
      '750',
    );
    await tester.pump(const Duration(milliseconds: 250));

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('node-inspector-save')),
    );
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final editedNodes = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'wait_ab',
    );
    expect(editedNodes.parameters['ms'], 750);
    expect(find.text('等待 750ms'), findsOneWidget);
  });

  testWidgets('workflow node inspector adds and removes extra connection', (
    tester,
  ) async {
    final controller = StudioRuntimeController();
    expect(await controller.updateWorkflow(_inspectorBranchWorkflow()), isTrue);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'branch');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(
      find.byKey(const ValueKey('node-inspector-edge-target')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const ValueKey('node-inspector-edge-target')));
    await tester.pumpAndSettle();
    expect(find.text('等待 50ms · 等待'), findsOneWidget);
    expect(find.text('等待 50ms (wait_ab)'), findsNothing);
    await tester.tap(find.text('等待 50ms · 等待').last);
    await tester.pump(const Duration(milliseconds: 250));

    final addButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-add-edge')),
    );
    expect(addButton.onPressed, isNotNull);
    addButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var branch = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'branch',
    );
    expect(branch.next, ['tap_a', 'wait_ab']);
    expect(
      find.byKey(const ValueKey('node-edge-remove-wait_ab')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('node-edge-remove-button-wait_ab')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(
      find.byKey(const ValueKey('node-edge-remove-button-wait_ab')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    branch = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'branch',
    );
    expect(branch.next, ['tap_a']);
  });

  testWidgets('workflow node inspector disables invalid extra start branch', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'start');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.ensureVisible(
      find.byKey(const ValueKey('node-inspector-edge-target')),
    );
    await tester.pump(const Duration(milliseconds: 120));

    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byKey(const ValueKey('node-inspector-edge-target')),
    );
    final addButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-add-edge')),
    );

    expect(dropdown.onChanged, isNull);
    expect(addButton.onPressed, isNull);
  });

  testWidgets('workflow node inspector inserts wait after selected node', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'tap_a');
    await tester.pump(const Duration(milliseconds: 250));

    final insertButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('node-inspector-insert-wait')),
    );
    expect(insertButton.onPressed, isNotNull);
    insertButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final inserted = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(tapA.next, ['wait_new_1']);
    expect(inserted.type, WorkflowNodeType.wait);
    expect(inserted.next, ['wait_ab']);
    expect(inserted.parameters['ms'], 500);
    expect(
      find.byKey(const ValueKey('workflow-node-wait_new_1')),
      findsOneWidget,
    );

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"id": "wait_new_1"'), findsOneWidget);
  });

  testWidgets('workflow node inspector inserts advanced workflow nodes', (
    tester,
  ) async {
    const localWorkflow = WorkflowDefinition(
      id: 'local-workflow',
      name: '本地流程',
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
    );
    final controller = StudioRuntimeController(
      subWorkflows: const {'local-workflow': localWorkflow},
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'tap_a');
    await tester.pump(const Duration(milliseconds: 250));

    for (final key in [
      'node-inspector-insert-snapshot',
      'node-inspector-insert-condition',
      'node-inspector-insert-visual-branch',
      'node-inspector-insert-catch',
      'node-inspector-insert-sub-workflow',
    ]) {
      final insertButton = tester.widget<OutlinedButton>(
        find.byKey(ValueKey(key)),
      );
      expect(insertButton.onPressed, isNotNull);
      insertButton.onPressed!();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));
    }

    final workflow = controller.snapshot.workflow;
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final snapshot = workflow.nodes.firstWhere(
      (node) => node.id == 'snapshot_new_1',
    );
    final condition = workflow.nodes.firstWhere(
      (node) => node.id == 'condition_new_1',
    );
    final visualBranch = workflow.nodes.firstWhere(
      (node) => node.id == 'visual_branch_new_1',
    );
    final catchNodes = workflow.nodes.firstWhere(
      (node) => node.id == 'catch_new_1',
    );
    final subWorkflow = workflow.nodes.firstWhere(
      (node) => node.id == 'sub_workflow_new_1',
    );

    expect(tapA.next, ['snapshot_new_1']);
    expect(snapshot.type, WorkflowNodeType.snapshot);
    expect(snapshot.next, ['condition_new_1']);
    expect(snapshot.parameters['saveEvidence'], isTrue);
    expect(condition.type, WorkflowNodeType.condition);
    expect(condition.next, ['visual_branch_new_1']);
    expect(condition.parameters['expression'], 'context.flag');
    expect(visualBranch.type, WorkflowNodeType.visualBranch);
    expect(visualBranch.next, ['catch_new_1']);
    expect(catchNodes.type, WorkflowNodeType.catchNodes);
    expect(catchNodes.next, ['sub_workflow_new_1']);
    expect(subWorkflow.type, WorkflowNodeType.subWorkflow);
    expect(subWorkflow.next, ['wait_ab']);
    expect(
      find.byKey(const ValueKey('workflow-node-sub_workflow_new_1')),
      findsOneWidget,
    );
  });
}
