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
// Workflow 画布框选、多选和批量移动回归。
// 每个用例只覆盖一个画布子域，避免综合测试继续膨胀。
void main() {
  // 验证修饰键点击只改变画布多选态，不写入工作流结构。
  testWidgets('workflow canvas modifier click toggles multi selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey('workflow-node-start')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byKey(const ValueKey('workflow-node-tap_a')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 2 个'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('multi-selected-node-start')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('multi-selected-node-tap_a')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('workflow-node-start')));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsNothing);
    expect(find.byKey(const ValueKey('workflow-node-tap_a')), findsOneWidget);
  });

  // 验证点击画布空白处会回到无选区状态，符合桌面画布直觉。
  testWidgets('workflow canvas blank click clears node selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-inspector-empty')),
      findsOneWidget,
    );
    expect(find.text('完整画布是 V2.0 目标。'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('workflow-node-tap_a')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-inspector-empty')),
      findsNothing,
    );

    final selectedNodeRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-tap_a')),
    );
    await tester.tapAt(selectedNodeRect.centerRight + const Offset(260, 0));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-inspector-empty')),
      findsOneWidget,
    );
    expect(
      const WorkflowValidator().validate(controller.snapshot.workflow).isValid,
      isTrue,
    );
  });

  // 验证框选模式能批量选择节点，并只更新 UI 选区。
  testWidgets('workflow canvas box selects multiple nodes', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('框选'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
      findsOneWidget,
    );

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
    );
    await tester.timedDragFrom(
      overlayRect.topLeft + const Offset(18, 18),
      const Offset(320, 360),
      const Duration(milliseconds: 320),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 3 个'), findsOneWidget);
    expect(find.text('tap_a'), findsNothing);
    expect(find.text('wait_ab'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'multi-selected-node-',
            ),
      ),
      findsNWidgets(3),
    );
  });

  // 验证多选删除走 Project DSL 保存路径，并自动重接剩余连线。
  testWidgets('workflow multi selection deletes nodes through project DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('框选'));
    await tester.pump(const Duration(milliseconds: 250));

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
    );
    await tester.timedDragFrom(
      overlayRect.topLeft + const Offset(18, 18),
      const Offset(320, 360),
      const Duration(milliseconds: 320),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 3 个'), findsOneWidget);

    final deleteButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('multi-node-delete-selected')),
    );
    expect(deleteButton.onPressed, isNotNull);
    deleteButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    expect(workflow.nodes.any((node) => node.id == 'tap_a'), isFalse);
    expect(workflow.nodes.any((node) => node.id == 'wait_ab'), isFalse);
    expect(start.next, ['tap_b']);
    expect(find.byKey(const ValueKey('workflow-node-tap_a')), findsNothing);
    expect(find.byKey(const ValueKey('workflow-node-wait_ab')), findsNothing);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"id": "tap_a"'), findsNothing);
    expect(find.textContaining('"id": "wait_ab"'), findsNothing);
    expect(find.textContaining('"tap_b"'), findsWidgets);
  });

  // 验证多选复制会生成受控新节点，并保持 workflow 校验通过。
  testWidgets('workflow multi selection duplicates nodes through project DSL', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('框选'));
    await tester.pump(const Duration(milliseconds: 250));

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
    );
    await tester.timedDragFrom(
      overlayRect.topLeft + const Offset(18, 18),
      const Offset(320, 360),
      const Duration(milliseconds: 320),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 3 个'), findsOneWidget);

    final duplicateButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('multi-node-duplicate-selected')),
    );
    expect(duplicateButton.onPressed, isNotNull);
    duplicateButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final waitAb = workflow.nodes.firstWhere((node) => node.id == 'wait_ab');
    final tapCopy = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    final waitCopy = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(tapA.next, ['wait_ab']);
    expect(waitAb.next, ['tap_new_1']);
    expect(tapCopy.type, WorkflowNodeType.tap);
    expect(tapCopy.label, '复制 点击 A');
    expect(tapCopy.next, ['wait_new_1']);
    expect(waitCopy.type, WorkflowNodeType.wait);
    expect(waitCopy.label, '复制 等待 50ms');
    expect(waitCopy.next, ['tap_b']);
    expect(
      find.byKey(const ValueKey('workflow-node-tap_new_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workflow-node-wait_new_1')),
      findsOneWidget,
    );

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"id": "tap_new_1"'), findsOneWidget);
    expect(find.textContaining('"id": "wait_new_1"'), findsOneWidget);
    expect(find.textContaining('"label": "复制 点击 A"'), findsOneWidget);
    expect(find.textContaining('"label": "复制 等待 50ms"'), findsOneWidget);
  });

  // 验证拖动任一已选节点时，多选集合按整体移动并只写视觉位置。
  testWidgets('workflow multi selection drags selected nodes as a group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('框选'));
    await tester.pump(const Duration(milliseconds: 250));

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
    );
    await tester.timedDragFrom(
      overlayRect.topLeft + const Offset(18, 18),
      const Offset(320, 360),
      const Duration(milliseconds: 320),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 3 个'), findsOneWidget);

    await tester.tap(find.byTooltip('退出框选'));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.drag(
      find.byKey(const ValueKey('workflow-node-tap_a')),
      const Offset(72, 42),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    for (final nodeId in ['start', 'tap_a', 'wait_ab']) {
      final node = workflow.nodes.firstWhere((node) => node.id == nodeId);
      expect(node.visual, isNotNull, reason: '$nodeId should move');
      expect(node.visual!.x, greaterThanOrEqualTo(28));
      expect(node.visual!.y, greaterThanOrEqualTo(28));
    }
    final tapB = workflow.nodes.firstWhere((node) => node.id == 'tap_b');
    expect(tapB.visual, isNull);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"id": "start"'), findsOneWidget);
    expect(find.textContaining('"visual": {'), findsWidgets);
  });

  // 验证 Inspector 对齐只调整选中节点的画布位置元数据。
  testWidgets('workflow multi selection aligns nodes through inspector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('框选'));
    await tester.pump(const Duration(milliseconds: 250));

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
    );
    await tester.timedDragFrom(
      overlayRect.topLeft + const Offset(18, 18),
      const Offset(320, 360),
      const Duration(milliseconds: 320),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsOneWidget);
    expect(find.text('顶齐'), findsOneWidget);
    expect(find.text('底齐'), findsOneWidget);

    final alignBottomButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('multi-node-align-bottom')),
    );
    expect(alignBottomButton.onPressed, isNotNull);
    alignBottomButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    for (final nodeId in ['start', 'tap_a', 'wait_ab']) {
      final node = workflow.nodes.firstWhere((node) => node.id == nodeId);
      expect(node.visual, isNotNull, reason: '$nodeId should align');
      expect(node.visual!.y, 284);
    }
    final tapB = workflow.nodes.firstWhere((node) => node.id == 'tap_b');
    expect(tapB.visual, isNull);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"visual": {'), findsWidgets);
  });

  // 验证 Inspector 均分只调整选中节点的画布位置元数据。
  testWidgets('workflow multi selection distributes nodes through inspector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();
    final baseWorkflow = controller.snapshot.workflow;
    final preparedWorkflow = baseWorkflow.copyWith(
      nodes: baseWorkflow.nodes
          .map((node) {
            final position = switch (node.id) {
              'start' => const Offset(28, 28),
              'tap_a' => const Offset(220, 156),
              'wait_ab' => const Offset(300, 284),
              _ => null,
            };
            if (position == null) return node;
            return node.copyWith(
              visual: WorkflowNodeVisual(x: position.dx, y: position.dy),
            );
          })
          .toList(growable: false),
    );
    expect(await controller.updateWorkflow(preparedWorkflow), isTrue);

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byTooltip('框选'));
    await tester.pump(const Duration(milliseconds: 250));

    final overlayRect = tester.getRect(
      find.byKey(const ValueKey('workflow-selection-overlay')),
    );
    await tester.timedDragFrom(
      overlayRect.topLeft + const Offset(18, 18),
      const Offset(360, 360),
      const Duration(milliseconds: 320),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('横向均分'), findsOneWidget);
    expect(find.text('纵向均分'), findsOneWidget);

    final distributeButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('multi-node-distribute-horizontal')),
    );
    expect(distributeButton.onPressed, isNotNull);
    distributeButton.onPressed!();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    final waitAb = workflow.nodes.firstWhere((node) => node.id == 'wait_ab');
    expect(start.visual!.x, 28);
    expect(tapA.visual!.x, 164);
    expect(waitAb.visual!.x, 300);
    expect(tapA.visual!.y, 156);

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"visual": {'), findsWidgets);
  });

  // 验证方向键微调只影响选中节点布局，不改变执行语义。
  testWidgets('workflow arrow keys nudge selected node layout only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.tap(find.byKey(const ValueKey('workflow-node-tap_a')));
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var tapA = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'tap_a',
    );
    expect(
      const WorkflowValidator().validate(controller.snapshot.workflow).isValid,
      isTrue,
    );
    expect(tapA.visual, isNotNull);
    expect(tapA.visual!.x, 40);
    expect(tapA.visual!.y, 156);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    tapA = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'tap_a',
    );
    final waitAb = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'wait_ab',
    );
    expect(
      const WorkflowValidator().validate(controller.snapshot.workflow).isValid,
      isTrue,
    );
    expect(tapA.visual!.x, 40);
    expect(tapA.visual!.y, 204);
    expect(waitAb.visual, isNull);
  });
}
