// ignore_for_file: unused_import, unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Inspector 高级参数回归测试，覆盖控制、视觉、手势和输入节点表单。
// 用例验证保存后 DSL 合法，不连接设备、不执行 workflow。
void main() {
  testWidgets('workflow node inspector edits advanced node parameters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final workflow = WorkflowDefinition(
      id: 'advanced-edit',
      name: 'Advanced Edit',
      entryNodesId: 'start',
      nodes: [
        const WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['snapshot_1'],
        ),
        const WorkflowNode(
          id: 'snapshot_1',
          type: WorkflowNodeType.snapshot,
          label: '截图',
          next: ['condition_1'],
          parameters: {'saveEvidence': true},
        ),
        const WorkflowNode(
          id: 'condition_1',
          type: WorkflowNodeType.condition,
          label: '条件',
          next: ['visual_1'],
          parameters: {'expression': 'context.ready'},
        ),
        const WorkflowNode(
          id: 'visual_1',
          type: WorkflowNodeType.visualBranch,
          label: '可视',
          next: ['catch_1'],
          parameters: {'confidenceThreshold': 0.8},
        ),
        const WorkflowNode(
          id: 'catch_1',
          type: WorkflowNodeType.catchNodes,
          label: '异常',
          next: ['sub_1'],
          parameters: {'maxRetries': 1},
        ),
        const WorkflowNode(
          id: 'sub_1',
          type: WorkflowNodeType.subWorkflow,
          label: 'Sub',
          next: ['end'],
          parameters: {'workflowId': 'local-workflow'},
        ),
        const WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
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
    const checkoutWorkflow = WorkflowDefinition(
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
      subWorkflows: const {
        'local-workflow': localWorkflow,
        'checkout-flow': checkoutWorkflow,
      },
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await selectWorkflowNode(tester, 'snapshot_1');
    final saveEvidenceTile = tester.widget<CheckboxListTile>(
      find.byKey(const ValueKey('node-inspector-save-evidence')),
    );
    expect(saveEvidenceTile.onChanged, isNotNull);
    saveEvidenceTile.onChanged!(false);
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    var snapshot = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'snapshot_1',
    );
    expect(snapshot.parameters['saveEvidence'], isFalse);

    await selectWorkflowNode(tester, 'condition_1');
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-expression')),
      'eval(context.ready)',
    );
    await tester.pump(const Duration(milliseconds: 250));
    var saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('node-inspector-save')),
    );
    expect(saveButton.onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-expression')),
      'context.user.ready',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    var condition = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'condition_1',
    );
    expect(condition.parameters['expression'], 'context.user.ready');

    await selectWorkflowNode(tester, 'visual_1');
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-confidence')),
      '0.67',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    final visual = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'visual_1',
    );
    expect(visual.parameters['confidenceThreshold'], 0.67);

    await selectWorkflowNode(tester, 'catch_1');
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-max-retries')),
      '3',
    );
    final onErrorPicker = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('node-inspector-on-error')),
    );
    onErrorPicker.onTap!();
    await tester.pumpAndSettle();
    expect(find.text('Sub · 子流程'), findsOneWidget);
    expect(find.text('Sub · sub_1'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('node-inspector-on-error-option-sub_1')).last,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    final catchNodes = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'catch_1',
    );
    expect(catchNodes.parameters['maxRetries'], 3);
    expect(catchNodes.parameters['onError'], 'sub_1');

    final clearOnErrorPicker = tester.widget<GestureDetector>(
      find.byKey(const ValueKey('node-inspector-on-error')),
    );
    clearOnErrorPicker.onTap!();
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('node-inspector-on-error-option-none')).last,
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    final catchWithoutOnError = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'catch_1',
    );
    expect(catchWithoutOnError.parameters.containsKey('onError'), isFalse);

    await selectWorkflowNode(tester, 'sub_1');
    await tester.ensureVisible(
      find.byKey(const ValueKey('sub-workflow-option-checkout-flow')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sub-workflow-option-checkout-flow')),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('结账流程 · 2 节点'), findsOneWidget);
    final addLoopNumber = find.byKey(
      const ValueKey('node-inspector-input-map-add-loopNumber'),
    );
    await tester.ensureVisible(addLoopNumber);
    await tester.pumpAndSettle();
    await tester.tap(addLoopNumber);
    await tester.pump(const Duration(milliseconds: 250));
    final addHasShot = find.byKey(
      const ValueKey('node-inspector-input-map-add-hasShot'),
    );
    await tester.ensureVisible(addHasShot);
    await tester.pumpAndSettle();
    await tester.tap(addHasShot);
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    final subWorkflow = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'sub_1',
    );
    expect(subWorkflow.parameters['workflowId'], 'checkout-flow');
    expect(subWorkflow.parameters['inputMap'], {
      'loopNumber': 'context.loopNumber',
      'hasShot': 'context.hasScreenshot',
    });
  });

  testWidgets('workflow node inspector edits swipe and input parameters', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    const workflow = WorkflowDefinition(
      id: 'gesture-input-edit',
      name: 'Gesture Input Edit',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['swipe_1'],
        ),
        WorkflowNode(
          id: 'swipe_1',
          type: WorkflowNodeType.swipe,
          label: 'Swipe Up',
          next: ['input_1'],
          parameters: {
            'label': 'Swipe Up',
            'fromX': 200,
            'fromY': 700,
            'toX': 200,
            'toY': 300,
            'durationMs': 450,
          },
        ),
        WorkflowNode(
          id: 'input_1',
          type: WorkflowNodeType.input,
          label: '输入文本',
          next: ['end'],
          parameters: {'label': '输入文本', 'text': '演示文本'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final controller = StudioRuntimeController(workflow: workflow);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await selectWorkflowNode(tester, 'swipe_1');
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('node-inspector-from-x')),
          )
          .decoration
          ?.labelText,
      '起横',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('node-inspector-from-y')),
          )
          .decoration
          ?.labelText,
      '起纵',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('node-inspector-to-x')))
          .decoration
          ?.labelText,
      '终横',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('node-inspector-to-y')))
          .decoration
          ?.labelText,
      '终纵',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('node-inspector-duration-ms')),
          )
          .decoration
          ?.labelText,
      '时长',
    );
    expect(find.text('起点 X'), findsNothing);
    expect(find.text('起点 Y'), findsNothing);
    expect(find.text('终点 X'), findsNothing);
    expect(find.text('终点 Y'), findsNothing);
    expect(find.text('时长毫秒'), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-from-y')),
      '720',
    );
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-to-y')),
      '260',
    );
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-duration-ms')),
      '520',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    var swipe = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'swipe_1',
    );
    expect(swipe.parameters['fromY'], 720);
    expect(swipe.parameters['toY'], 260);
    expect(swipe.parameters['durationMs'], 520);

    await selectWorkflowNode(tester, 'input_1');
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-input-text')),
      'checkout',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);
    final input = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'input_1',
    );
    expect(input.parameters['text'], 'checkout');
    expect(
      const WorkflowValidator().validate(controller.snapshot.workflow).isValid,
      isTrue,
    );
  });

  testWidgets('workflow node inspector edits loop count', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1500, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    const workflow = WorkflowDefinition(
      id: 'loop-edit',
      name: 'Loop Edit',
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
          label: 'Body Wait',
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
    await tester.enterText(
      find.byKey(const ValueKey('node-inspector-loop-count')),
      '4',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await saveSelectedNodes(tester);

    final loop = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'loop_1',
    );
    expect(loop.parameters['count'], 4);
    expect(
      const WorkflowValidator().validate(controller.snapshot.workflow).isValid,
      isTrue,
    );
  });
}
