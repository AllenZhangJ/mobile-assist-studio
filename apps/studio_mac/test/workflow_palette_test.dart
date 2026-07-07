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
// Workflow 节点菜单、撤销重做和节点库回归。
// 每个用例只覆盖一个画布子域，避免综合测试继续膨胀。
void main() {
  testWidgets('workflow node palette uses short friendly labels', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1900, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('重复'), findsOneWidget);
    expect(find.text('看图'), findsOneWidget);
    expect(find.text('等目标'), findsOneWidget);
    expect(find.text('重复几次'), findsOneWidget);
    expect(find.text('看不准就停'), findsOneWidget);
    expect(find.text('等到出现'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('workflow-node-palette-list')),
      const Offset(0, -220),
    );
    await tester.pump();
    expect(find.text('兜底'), findsOneWidget);
    expect(find.text('失败重试'), findsOneWidget);
    expect(find.text('视觉分支'), findsNothing);
    expect(find.text('低置信暂停'), findsNothing);
    expect(find.text('有限循环'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('workflow-add-node-menu')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-add-node-loop')),
        matching: find.text('重复'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-add-node-visual-branch')),
        matching: find.text('看图'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-add-node-wait-target')),
        matching: find.text('等目标'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('workflow-add-node-catch')),
        matching: find.text('兜底'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('workflow canvas add node menu inserts after entry node', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey('workflow-add-node-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workflow-add-node-wait')));
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

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"id": "wait_new_1"'), findsOneWidget);
  });

  testWidgets('workflow canvas add node menu inserts wait target node', (
    tester,
  ) async {
    final controller = StudioRuntimeController(
      targets: [
        RuntimeTargetDefinition.coordinate(
          id: 'target_1',
          label: '目标一',
          x: 10,
          y: 20,
        ),
      ],
    );

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey('workflow-add-node-menu')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('workflow-add-node-wait-target')),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final inserted = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_target_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['wait_target_new_1']);
    expect(inserted.type, WorkflowNodeType.waitForTarget);
    expect(inserted.next, ['tap_a']);
    expect(inserted.parameters['targetRef'], 'target_1');
    expect(inserted.parameters['timeoutMs'], 5000);
    expect(inserted.parameters['intervalMs'], 500);
    expect(inserted.parameters['confidenceThreshold'], 0.8);
    expect(
      find.byKey(const ValueKey('workflow-node-wait_target_new_1')),
      findsOneWidget,
    );
  });

  testWidgets('workflow canvas undo and redo restore graph edits', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    var undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('workflow-undo')),
    );
    var redoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('workflow-redo')),
    );
    expect(undoButton.onPressed, isNull);
    expect(redoButton.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('workflow-add-node-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workflow-add-node-wait')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      controller.snapshot.workflow.nodes.any((node) => node.id == 'wait_new_1'),
      isTrue,
    );
    undoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('workflow-undo')),
    );
    expect(undoButton.onPressed, isNotNull);

    undoButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      controller.snapshot.workflow.nodes.any((node) => node.id == 'wait_new_1'),
      isFalse,
    );
    redoButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('workflow-redo')),
    );
    expect(redoButton.onPressed, isNotNull);

    redoButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['wait_new_1']);
    expect(workflow.nodes.any((node) => node.id == 'wait_new_1'), isTrue);
  });

  testWidgets('workflow node palette inserts after selected node', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1900, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('workflow-node-palette')), findsOneWidget);
    await selectWorkflowNode(tester, 'tap_a');

    expect(find.text('在 点击 A 后'), findsOneWidget);

    final paletteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('workflow-palette-node-wait')),
    );
    expect(paletteButton.onPressed, isNotNull);
    paletteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final inserted = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
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

  testWidgets('workflow node palette locks while run is active', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1900, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runStatus: RunStatus.running,
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.byKey(const ValueKey('workflow-node-palette')), findsOneWidget);
    expect(find.text('锁定'), findsWidgets);
    expect(
      find.byKey(const ValueKey('workflow-canvas-lock-banner')),
      findsOneWidget,
    );
    expect(find.text('画布锁定'), findsOneWidget);
    expect(find.textContaining('运行中'), findsWidgets);

    final paletteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('workflow-palette-node-wait')),
    );
    expect(paletteButton.onPressed, isNull);
  });

  testWidgets('workflow node palette inserts swipe and input nodes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1900, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'tap_a');

    for (final key in [
      'workflow-palette-node-swipe',
      'workflow-palette-node-input',
    ]) {
      final button = tester.widget<OutlinedButton>(find.byKey(ValueKey(key)));
      expect(button.onPressed, isNotNull);
      button.onPressed!();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));
    }

    final workflow = controller.snapshot.workflow;
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final swipe = workflow.nodes.firstWhere((node) => node.id == 'swipe_new_1');
    final input = workflow.nodes.firstWhere((node) => node.id == 'input_new_1');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(tapA.next, ['swipe_new_1']);
    expect(swipe.type, WorkflowNodeType.swipe);
    expect(swipe.next, ['input_new_1']);
    expect(swipe.parameters['fromY'], 700);
    expect(input.type, WorkflowNodeType.input);
    expect(input.next, ['wait_ab']);
    expect(input.parameters['text'], '演示文本');

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"type": "swipe"'), findsOneWidget);
    expect(find.textContaining('"type": "input"'), findsOneWidget);
  });

  testWidgets('workflow node palette inserts bounded loop scaffold', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1900, 1100));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'tap_a');

    final button = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('workflow-palette-node-loop')),
    );
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final loop = workflow.nodes.firstWhere((node) => node.id == 'loop_new_1');
    final body = workflow.nodes.firstWhere(
      (node) => node.id == 'loop_body_wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(tapA.next, ['loop_new_1']);
    expect(loop.type, WorkflowNodeType.loop);
    expect(loop.parameters['count'], 2);
    expect(loop.next, ['loop_body_wait_new_1', 'wait_ab']);
    expect(body.type, WorkflowNodeType.wait);
    expect(body.next, ['loop_new_1']);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"type": "loop"'), findsOneWidget);
    expect(find.textContaining('"id": "loop_body_wait_new_1"'), findsOneWidget);
  });
}
