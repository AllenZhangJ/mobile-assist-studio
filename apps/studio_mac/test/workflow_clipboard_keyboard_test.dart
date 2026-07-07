import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Canvas 键盘剪贴板回归测试。
// 用例只验证 Project DSL 编辑结果，不连接真实设备、不启动 Appium。
void main() {
  // 验证快捷键复制节点后，删除副本仍能保持 DSL 连线有效。
  testWidgets('workflow canvas keyboard shortcuts duplicate and delete nodes', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'tap_a');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var workflow = controller.snapshot.workflow;
    var tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    var copy = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(tapA.next, ['tap_new_1']);
    expect(copy.next, ['wait_ab']);

    await selectWorkflowNode(tester, 'tap_new_1');
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    tapA = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(workflow.nodes.any((node) => node.id == 'tap_new_1'), isFalse);
    expect(tapA.next, ['wait_ab']);
  });

  // 验证全选和清空选择只影响画布选区，不改写 workflow 源码。
  testWidgets('workflow canvas keyboard selects all and clears selection', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    final sourceBefore = jsonEncode(controller.snapshot.workflow.toJson());
    final nodeCount = controller.snapshot.workflow.nodes.length;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 $nodeCount 个'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'multi-selected-node-',
            ),
      ),
      findsNWidgets(nodeCount),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('多选'), findsNothing);
    expect(jsonEncode(controller.snapshot.workflow.toJson()), sourceBefore);
  });

  // 验证键盘复制粘贴会生成新节点，并通过 Project DSL 校验。
  testWidgets('workflow canvas keyboard copies and pastes selected nodes', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('多选'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = controller.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final waitAb = workflow.nodes.firstWhere((node) => node.id == 'wait_ab');
    final tapCopy = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    final waitCopy = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(
      workflow.nodes.where((node) => node.type == WorkflowNodeType.start),
      hasLength(1),
    );
    expect(start.next, ['tap_a']);
    expect(waitAb.next, ['tap_new_1']);
    expect(tapCopy.type, WorkflowNodeType.tap);
    expect(tapCopy.next, ['wait_new_1']);
    expect(waitCopy.type, WorkflowNodeType.wait);
    expect(waitCopy.next, ['tap_b']);
    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 2 个'), findsOneWidget);
  });

  // 验证页面内剪贴板不依赖源节点存活，删除源节点后仍可粘贴。
  testWidgets('workflow canvas clipboard survives source node deletion', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var workflow = controller.snapshot.workflow;
    var start = workflow.nodes.firstWhere((node) => node.id == 'start');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(workflow.nodes.any((node) => node.id == 'tap_a'), isFalse);
    expect(workflow.nodes.any((node) => node.id == 'wait_ab'), isFalse);
    expect(start.next, ['tap_b']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final tapCopy = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    final waitCopy = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['tap_new_1']);
    expect(tapCopy.type, WorkflowNodeType.tap);
    expect(tapCopy.next, ['wait_new_1']);
    expect(waitCopy.type, WorkflowNodeType.wait);
    expect(waitCopy.next, ['tap_b']);
    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 2 个'), findsOneWidget);
  });

  // 验证剪切粘贴会移动选中节点，并恢复合法执行顺序。
  testWidgets('workflow canvas keyboard cuts and pastes selected nodes', (
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

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    var workflow = controller.snapshot.workflow;
    var start = workflow.nodes.firstWhere((node) => node.id == 'start');
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(workflow.nodes.any((node) => node.id == 'tap_a'), isFalse);
    expect(workflow.nodes.any((node) => node.id == 'wait_ab'), isFalse);
    expect(start.next, ['tap_b']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    workflow = controller.snapshot.workflow;
    start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final tapCut = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    final waitCut = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['tap_new_1']);
    expect(tapCut.type, WorkflowNodeType.tap);
    expect(tapCut.next, ['wait_new_1']);
    expect(waitCut.type, WorkflowNodeType.wait);
    expect(waitCut.next, ['tap_b']);
    expect(find.text('多选'), findsOneWidget);
    expect(find.text('已选 2 个'), findsOneWidget);
  });
}
