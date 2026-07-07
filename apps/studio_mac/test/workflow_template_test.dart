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
// Workflow 模板库导入和模板 DSL 回归。
// 每个用例只覆盖一个画布子域，避免综合测试继续膨胀。
void main() {
  testWidgets('workflow template library imports a project DSL template', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开模板'));
    await tester.pumpAndSettle();

    expect(find.text('流程模板'), findsOneWidget);
    expect(find.text('空白流程'), findsOneWidget);
    expect(find.text('A-F 基础模板'), findsWidgets);
    expect(find.text('视觉守卫'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('workflow-template-import-blank-workflow')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pumpAndSettle();

    var workflow = controller.snapshot.workflow;
    expect(workflow.name, '空白流程');
    expect(workflow.nodes.map((node) => node.type), [
      WorkflowNodeType.start,
      WorkflowNodeType.end,
    ]);
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);

    await tester.tap(find.byKey(const ValueKey('workflow-add-node-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workflow-add-node-wait')));
    await tester.pumpAndSettle();

    workflow = controller.snapshot.workflow;
    expect(
      workflow.nodes.any((node) => node.type == WorkflowNodeType.wait),
      isTrue,
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);

    await tester.tap(find.byTooltip('打开模板'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('workflow-template-import-visual-guard')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(
      find.byKey(const ValueKey('workflow-template-import-visual-guard')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pumpAndSettle();

    workflow = controller.snapshot.workflow;
    expect(workflow.name, '视觉守卫');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(
      workflow.nodes.any((node) => node.type == WorkflowNodeType.snapshot),
      isTrue,
    );
    expect(
      workflow.nodes.any((node) => node.type == WorkflowNodeType.visualBranch),
      isTrue,
    );
    expect(find.text('视觉守卫'), findsWidgets);
    expect(
      find.byKey(const ValueKey('workflow-node-visual_1')),
      findsOneWidget,
    );

    await tester.tap(find.text('源码'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('"id": "visual-guard-template"'),
      findsOneWidget,
    );
    expect(find.textContaining('"type": "visualBranch"'), findsOneWidget);
    expect(find.textContaining('"confidenceThreshold": 0.72'), findsOneWidget);
  });

  testWidgets('workflow template library imports advanced templates', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('打开模板'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('workflow-template-import-loop-batch')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(
      find.byKey(const ValueKey('workflow-template-import-loop-batch')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pumpAndSettle();

    var workflow = controller.snapshot.workflow;
    expect(workflow.name, '批量循环');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    final loop = workflow.nodes.firstWhere(
      (node) => node.type == WorkflowNodeType.loop,
    );
    expect(loop.next, ['tap_item', 'snapshot_done']);
    expect(loop.parameters['count'], 3);

    await tester.tap(find.byTooltip('打开模板'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('workflow-template-import-catch-retry')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(
      find.byKey(const ValueKey('workflow-template-import-catch-retry')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pumpAndSettle();

    workflow = controller.snapshot.workflow;
    expect(workflow.name, '异常兜底');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    final catchNode = workflow.nodes.firstWhere(
      (node) => node.type == WorkflowNodeType.catchNodes,
    );
    expect(catchNode.next, ['tap_primary']);
    expect(catchNode.parameters['maxRetries'], 2);
    expect(catchNode.parameters['onError'], 'wait_recover');
  });
}
