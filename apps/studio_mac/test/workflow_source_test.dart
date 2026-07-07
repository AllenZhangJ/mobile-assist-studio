import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

// Workflow Source 与 Validate 回归测试，聚焦 Project DSL 源码编辑和诊断定位。
// 用例只验证编辑期状态，不连接真实设备、不启动 Appium、不执行 workflow。
void main() {
  // 验证 Workflow 的画布、源码和检查三个视图都能读取同一 DSL。
  testWidgets('renders workflow visual source and validation views', (
    tester,
  ) async {
    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(find.text('流程检查'), findsOneWidget);
    expect(find.text('画布'), findsOneWidget);
    expect(find.text('源码'), findsOneWidget);
    expect(find.text('检查'), findsOneWidget);
    expect(find.text('点击 A'), findsOneWidget);

    await tester.tap(find.text('源码'));
    await tester.pumpAndSettle();

    expect(find.textContaining('"entryNodesId": "start"'), findsOneWidget);
    expect(find.textContaining('"type": "tap"'), findsWidgets);

    await tester.tap(find.text('检查'));
    await tester.pumpAndSettle();

    expect(find.text('流程检查通过'), findsOneWidget);
  });

  // 验证检查问题可从检查视图定位回对应画布节点。
  testWidgets('workflow validate diagnostics select affected visual node', (
    tester,
  ) async {
    final invalidWorkflow = const WorkflowDefinition(
      id: 'invalid-validate',
      name: 'Invalid Validate Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['input_1'],
        ),
        WorkflowNode(
          id: 'input_1',
          type: WorkflowNodeType.input,
          label: 'Input 缺失 Text',
          next: ['end'],
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final preview = StudioRuntimeSnapshot.initial(workflow: invalidWorkflow);

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('检查'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Input 缺失 Text 文本必填'), findsOneWidget);
    expect(find.text('Input 缺失 Text / 文本'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workflow-validation-diagnostic-0')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-visual-canvas')),
      findsOneWidget,
    );
    expect(find.text('节点检查'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workflow-node-issue-input_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('node-inspector-diagnostics')),
      findsOneWidget,
    );
    expect(find.text('1 个问题'), findsWidgets);
    expect(find.text('Input 缺失 Text'), findsWidgets);
    expect(find.textContaining('Input 缺失 Text 文本必填'), findsOneWidget);
  });

  // 验证动作节点参数诊断使用短中文字段，不暴露底层坐标字段名。
  testWidgets(
    'workflow validate diagnostics use friendly action field labels',
    (tester) async {
      const invalidWorkflow = WorkflowDefinition(
        id: 'invalid-swipe-label',
        name: '滑动字段检查',
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
            label: '滑动缺参',
            next: ['end'],
            parameters: {
              'fromY': 700,
              'toX': 200,
              'toY': 300,
              'durationMs': 450,
            },
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      final preview = StudioRuntimeSnapshot.initial(workflow: invalidWorkflow);

      await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查'));
      await tester.pumpAndSettle();

      expect(find.textContaining('滑动缺参 起横需填写数字'), findsOneWidget);
      expect(find.text('滑动缺参 / 起横'), findsOneWidget);
      expect(find.textContaining('fromX'), findsNothing);
      expect(find.textContaining('起点 X'), findsNothing);
    },
  );

  // 验证缺失子流程引用会在编辑期暴露并定位到节点。
  testWidgets('workflow validation surfaces missing sub workflow reference', (
    tester,
  ) async {
    const workflow = WorkflowDefinition(
      id: 'missing-subflow-main',
      name: '子流程引用检查',
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
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow);

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-node-issue-sub_1')),
      findsOneWidget,
    );

    await tester.tap(find.text('检查'));
    await tester.pumpAndSettle();

    expect(find.textContaining('缺失子流程 没有选到可用子流程'), findsOneWidget);
    expect(find.text('缺失子流程 / 子流程'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workflow-validation-diagnostic-0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('节点检查'), findsOneWidget);
    expect(find.text('缺失子流程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('node-inspector-diagnostics')),
      findsOneWidget,
    );
  });

  // 验证子流程循环引用会在运行前被校验层拦截。
  testWidgets('workflow validation surfaces recursive sub workflow reference', (
    tester,
  ) async {
    const childA = WorkflowDefinition(
      id: 'child-a',
      name: '子流程 A',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['sub'],
        ),
        WorkflowNode(
          id: 'sub',
          type: WorkflowNodeType.subWorkflow,
          label: '去 B',
          next: ['end'],
          parameters: {'workflowId': 'child-b'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const childB = WorkflowDefinition(
      id: 'child-b',
      name: '子流程 B',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['sub'],
        ),
        WorkflowNode(
          id: 'sub',
          type: WorkflowNodeType.subWorkflow,
          label: '回 A',
          next: ['end'],
          parameters: {'workflowId': 'child-a'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const workflow = WorkflowDefinition(
      id: 'main-recursive-subflow',
      name: '子流程循环检查',
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
          label: '循环子流程',
          next: ['end'],
          parameters: {'workflowId': 'child-a'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final preview = StudioRuntimeSnapshot.initial(
      workflow: workflow,
      subWorkflows: const {'child-a': childA, 'child-b': childB},
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-node-issue-sub_1')),
      findsOneWidget,
    );

    await tester.tap(find.text('检查'));
    await tester.pumpAndSettle();

    expect(find.textContaining('循环子流程 会造成子流程循环'), findsOneWidget);
    expect(find.text('循环子流程 / 子流程'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workflow-validation-diagnostic-0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('节点检查'), findsOneWidget);
    expect(find.text('循环子流程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('node-inspector-diagnostics')),
      findsOneWidget,
    );
  });

  // 覆盖嵌套缺失子流程在 Flutter 编辑期的可见性。
  // Validate View 必须定位到触发问题的 Sub Workflow 节点和 workflowId 字段。
  testWidgets('workflow validation surfaces nested missing sub workflow', (
    tester,
  ) async {
    const childA = WorkflowDefinition(
      id: 'child-a',
      name: '子流程 A',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['sub'],
        ),
        WorkflowNode(
          id: 'sub',
          type: WorkflowNodeType.subWorkflow,
          label: '缺失嵌套',
          next: ['end'],
          parameters: {'workflowId': 'missing-nested'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const workflow = WorkflowDefinition(
      id: 'main-nested-missing-subflow',
      name: '子流程嵌套检查',
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
          label: '嵌套缺失',
          next: ['end'],
          parameters: {'workflowId': 'child-a'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final preview = StudioRuntimeSnapshot.initial(
      workflow: workflow,
      subWorkflows: const {'child-a': childA},
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-node-issue-sub_1')),
      findsOneWidget,
    );

    await tester.tap(find.text('检查'));
    await tester.pumpAndSettle();

    expect(find.textContaining('嵌套缺失 的子流程链不完整'), findsOneWidget);
    expect(find.text('嵌套缺失 / 子流程'), findsOneWidget);
  });

  // 验证节点 next 和 Catch onError 自引用会统一进入诊断列表。
  testWidgets('workflow validation surfaces direct self references', (
    tester,
  ) async {
    const workflow = WorkflowDefinition(
      id: 'self-reference-main',
      name: '自引用检查',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['wait_self'],
        ),
        WorkflowNode(
          id: 'wait_self',
          type: WorkflowNodeType.wait,
          label: '自环等待',
          next: ['wait_self'],
          parameters: {'ms': 100},
        ),
        WorkflowNode(
          id: 'catch_self',
          type: WorkflowNodeType.catchNodes,
          label: '自环异常',
          next: ['end'],
          parameters: {'maxRetries': 1, 'onError': 'catch_self'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow);

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-node-issue-wait_self')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workflow-node-issue-catch_self')),
      findsOneWidget,
    );

    await tester.tap(find.text('检查'));
    await tester.pumpAndSettle();

    expect(find.textContaining('自环等待 不能连接自己'), findsWidgets);
    expect(find.textContaining('自环异常 的错误分支不能指向自己'), findsOneWidget);
    expect(find.text('自环等待 / 后续'), findsOneWidget);
    expect(find.text('自环异常 / 错误分支'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workflow-validation-diagnostic-0')),
    );
    await tester.pumpAndSettle();

    expect(find.text('节点检查'), findsOneWidget);
    expect(find.text('自环等待'), findsWidgets);
    expect(
      find.byKey(const ValueKey('node-inspector-diagnostics')),
      findsOneWidget,
    );
  });

  // 验证合法源码草稿会通过 Runtime 写回 Project DSL。
  testWidgets('workflow source editor saves valid project DSL', (tester) async {
    final controller = StudioRuntimeController();
    final editedWorkflow = const WorkflowDefinition(
      id: 'source-edited',
      name: '源码编辑流程',
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
          label: 'Wait 250ms',
          next: ['end'],
          parameters: {'ms': 250},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(
      find.byKey(const ValueKey('workflow-source-editor')),
      const JsonEncoder.withIndent('  ').convert(editedWorkflow.toJson()),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('workflow-source-save')),
    );
    expect(saveButton.onPressed, isNotNull);
    saveButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    expect(controller.snapshot.workflow.name, '源码编辑流程');
    expect(controller.snapshot.workflow.nodes, hasLength(3));
    expect(find.text('源码编辑流程'), findsOneWidget);
    expect(find.text('源码已同步。'), findsOneWidget);
  });

  // 验证非法源码只保留为草稿，不替换 Runtime 真值。
  testWidgets('workflow source editor keeps invalid DSL as draft only', (
    tester,
  ) async {
    final controller = StudioRuntimeController();
    final originalName = controller.snapshot.workflow.name;
    final invalidWorkflow = {
      'id': 'invalid-source',
      'name': 'Invalid Source Workflow',
      'entryNodesId': 'missing',
      'nodes': [
        {'id': 'start', 'type': 'start', 'label': '开始'},
      ],
    };

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(
      find.byKey(const ValueKey('workflow-source-editor')),
      const JsonEncoder.withIndent('  ').convert(invalidWorkflow),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('草稿提醒'), findsOneWidget);
    expect(find.textContaining('入口节点不存在'), findsWidgets);
    expect(
      find.byKey(const ValueKey('workflow-source-diagnostics')),
      findsOneWidget,
    );
    expect(find.text('entryNodesId'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workflow-source-diagnostic-0')),
    );
    await tester.pump(const Duration(milliseconds: 120));

    final sourceField = tester.widget<TextField>(
      find.byKey(const ValueKey('workflow-source-editor')),
    );
    final selection = sourceField.controller!.selection;
    final selectedText = sourceField.controller!.text.substring(
      selection.start,
      selection.end,
    );
    expect(selectedText, '"entryNodesId"');

    final saveButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('workflow-source-save')),
    );
    expect(saveButton.onPressed, isNull);
    expect(controller.snapshot.workflow.name, originalName);

    await tester.tap(find.text('画布'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-canvas-lock-banner')),
      findsOneWidget,
    );
    expect(find.text('画布锁定'), findsOneWidget);
    expect(find.textContaining('源码未保存'), findsOneWidget);
  });

  // 验证源码诊断能选中节点内部的具体问题字段。
  testWidgets('workflow source diagnostics select node field for self edge', (
    tester,
  ) async {
    final controller = StudioRuntimeController();
    const invalidWorkflow = WorkflowDefinition(
      id: 'source-self-edge',
      name: '源码自引用',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['wait_self'],
        ),
        WorkflowNode(
          id: 'wait_self',
          type: WorkflowNodeType.wait,
          label: '自环等待',
          next: ['wait_self'],
          parameters: {'ms': 100},
        ),
      ],
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.enterText(
      find.byKey(const ValueKey('workflow-source-editor')),
      const JsonEncoder.withIndent('  ').convert(invalidWorkflow.toJson()),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('草稿提醒'), findsOneWidget);
    expect(find.textContaining('节点 wait_self 不能连接自己'), findsWidgets);
    expect(find.text('wait_self / next'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workflow-source-diagnostic-0')),
    );
    await tester.pump(const Duration(milliseconds: 120));

    final sourceField = tester.widget<TextField>(
      find.byKey(const ValueKey('workflow-source-editor')),
    );
    final selection = sourceField.controller!.selection;
    final selectedText = sourceField.controller!.text.substring(
      selection.start,
      selection.end,
    );
    expect(selectedText, '"next"');
  });
}
