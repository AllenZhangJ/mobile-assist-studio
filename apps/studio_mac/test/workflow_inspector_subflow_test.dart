// ignore_for_file: unused_import, unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Inspector 子流程回归测试，覆盖选择、删除、示例和当前流程转子流程。
// 用例只调用 Runtime 本地项目命令，不连接设备、不启动运行。
void main() {
  testWidgets('workflow node inspector picks registered sub workflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    const workflow = WorkflowDefinition(
      id: 'sub-picker-main',
      name: 'Sub Picker Main',
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
          label: '子流程',
          next: ['end'],
          parameters: {'workflowId': 'local-workflow'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const nested = WorkflowDefinition(
      id: 'checkout-flow',
      name: '结账流程',
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
      workflow: workflow,
      subWorkflows: const {'checkout-flow': nested},
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'sub_1');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('sub-workflow-picker')), findsOneWidget);
    expect(find.text('可用子流程'), findsOneWidget);
    expect(find.text('结账流程 2'), findsOneWidget);
    expect(find.text('未找到子流程'), findsOneWidget);
    expect(find.text('local-workflow'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('sub-workflow-option-checkout-flow')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(
      find.byKey(const ValueKey('sub-workflow-option-checkout-flow')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('结账流程 · 2 节点'), findsOneWidget);
    await saveSelectedNodes(tester);

    final subWorkflow = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'sub_1',
    );
    expect(subWorkflow.parameters['workflowId'], 'checkout-flow');
  });

  testWidgets('workflow node inspector deletes unused sub workflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    const workflow = WorkflowDefinition(
      id: 'sub-delete-main',
      name: 'Sub Delete Main',
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
          label: '子流程',
          next: ['end'],
          parameters: {'workflowId': 'kept-flow'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const kept = WorkflowDefinition(
      id: 'kept-flow',
      name: '保留流程',
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
    const unused = WorkflowDefinition(
      id: 'unused-flow',
      name: '未用流程',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['wait'],
        ),
        WorkflowNode(
          id: 'wait',
          type: WorkflowNodeType.wait,
          label: '等待',
          next: ['end'],
          parameters: {'ms': 200},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController(
      workflow: workflow,
      subWorkflows: const {'kept-flow': kept, 'unused-flow': unused},
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'sub_1');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('未用流程 3'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('sub-workflow-delete-unused-flow')),
    );
    await tester.tap(
      find.byKey(const ValueKey('sub-workflow-delete-unused-flow')),
    );
    await tester.pumpAndSettle();
    expect(find.text('删除子流程？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sub-workflow-delete-confirm')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.subWorkflows, hasLength(1));
    expect(controller.snapshot.subWorkflows.single.workflowId, 'kept-flow');
    expect(find.text('未用流程 3'), findsNothing);
    expect(find.text('保留流程 2'), findsOneWidget);
  });

  testWidgets('workflow node inspector adds starter sub workflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    const workflow = WorkflowDefinition(
      id: 'sub-starter-main',
      name: 'Sub Starter Main',
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
          label: '子流程',
          next: ['end'],
          parameters: {'workflowId': 'local-workflow'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController(workflow: workflow);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'sub_1');
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('暂无子流程。'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('sub-workflow-add-starter')),
    );
    await tester.tap(find.byKey(const ValueKey('sub-workflow-add-starter')));
    await tester.pump(const Duration(milliseconds: 350));

    expect(controller.snapshot.subWorkflows, hasLength(1));
    expect(find.text('示例子流程 3'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('sub-workflow-option-starter-sub-workflow')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);

    final subWorkflow = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'sub_1',
    );
    expect(subWorkflow.parameters['workflowId'], 'starter-sub-workflow');
  });

  testWidgets(
    'workflow node inspector saves current workflow as sub workflow',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1500, 1100));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });
      const workflow = WorkflowDefinition(
        id: 'sub-save-current-main',
        name: '当前流程',
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
            label: '子流程',
            next: ['end'],
            parameters: {'workflowId': 'local-workflow'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
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
        workflow: workflow,
        subWorkflows: const {'local-workflow': localWorkflow},
      );

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));
      await selectWorkflowNode(tester, 'sub_1');
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('本地流程 2'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('sub-workflow-add-current')),
      );
      await tester.tap(find.byKey(const ValueKey('sub-workflow-add-current')));
      await tester.pump(const Duration(milliseconds: 350));

      expect(controller.snapshot.subWorkflows, hasLength(2));
      expect(
        controller.snapshot.subWorkflows.map((summary) => summary.workflowId),
        contains(startsWith('sub-save-current-main-sub-')),
      );
      expect(find.text('当前流程 子流程 3'), findsOneWidget);
    },
  );
}
