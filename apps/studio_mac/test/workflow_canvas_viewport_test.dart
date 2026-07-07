// ignore_for_file: unused_import, unnecessary_import

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow 综合回归测试仍承载尚未继续拆出的画布、Palette、Mini Map 和跨区场景。
// Source/Validate、剪贴板、Inspector 已迁移到独立文件，新增用例优先落到对应子域。
// Workflow 画布缩放、小地图和节点拖动回归。
// 每个用例只覆盖一个画布子域，避免综合测试继续膨胀。
void main() {
  testWidgets('workflow canvas exposes zoom pan controls', (tester) async {
    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-visual-canvas')),
      findsOneWidget,
    );
    expect(find.byTooltip('适应画布'), findsOneWidget);
    expect(find.byTooltip('重置缩放'), findsOneWidget);
    expect(find.byTooltip('缩小'), findsOneWidget);
    expect(find.byTooltip('放大'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workflow-canvas-zoom-label')),
      findsOneWidget,
    );
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('workflow-canvas-fit')));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('50%'), findsOneWidget);
    expect(find.byKey(const ValueKey('workflow-node-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('workflow-node-end')), findsOneWidget);

    await tester.tap(find.byTooltip('放大'));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('60%'), findsOneWidget);

    await tester.tap(find.byTooltip('重置缩放'));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('workflow canvas keyboard controls viewport only', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('workflow-visual-canvas')));
    await tester.pump(const Duration(milliseconds: 120));

    final sourceBefore = jsonEncode(controller.snapshot.workflow.toJson());
    expect(find.text('100%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('50%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('60%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('50%'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('100%'), findsOneWidget);
    expect(jsonEncode(controller.snapshot.workflow.toJson()), sourceBefore);
  });

  testWidgets('workflow canvas renders mini map', (tester) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('workflow-mini-map')), findsOneWidget);
    expect(find.text('地图'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workflow-visual-canvas')),
      findsOneWidget,
    );
  });

  testWidgets('workflow canvas shows readable overview summary', (
    tester,
  ) async {
    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    final overview = find.byKey(const ValueKey('workflow-canvas-overview'));
    expect(overview, findsOneWidget);
    expect(
      find.descendant(of: overview, matching: find.text('节点 13')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overview, matching: find.text('连线 12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overview, matching: find.text('问题 0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overview, matching: find.text('选区 未选择')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('workflow-canvas-fit')));
    await tester.pump(const Duration(milliseconds: 120));
    await selectWorkflowNode(tester, 'start');

    expect(
      find.descendant(of: overview, matching: find.text('选区 开始')),
      findsOneWidget,
    );
    expect(find.text('start'), findsNothing);
  });

  testWidgets('workflow mini map navigates the canvas viewport', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    final endFinder = find.byKey(const ValueKey('workflow-node-end'));
    final before = tester.getCenter(endFinder);
    final miniMapRect = tester.getRect(
      find.byKey(const ValueKey('workflow-mini-map-canvas')),
    );

    await tester.tapAt(Offset(miniMapRect.center.dx, miniMapRect.bottom - 8));
    await tester.pump(const Duration(milliseconds: 250));

    final after = tester.getCenter(endFinder);
    expect(after.dy, lessThan(before.dy));
  });

  testWidgets('workflow mini map drags the canvas viewport', (tester) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    final endFinder = find.byKey(const ValueKey('workflow-node-end'));
    final before = tester.getCenter(endFinder);
    final miniMapRect = tester.getRect(
      find.byKey(const ValueKey('workflow-mini-map-canvas')),
    );

    await tester.timedDragFrom(
      Offset(miniMapRect.center.dx, miniMapRect.top + 8),
      Offset(0, miniMapRect.height - 16),
      const Duration(milliseconds: 260),
    );
    await tester.pump(const Duration(milliseconds: 250));

    final after = tester.getCenter(endFinder);
    expect(after.dy, lessThan(before.dy));
  });

  testWidgets('workflow canvas drags node and persists visual position', (
    tester,
  ) async {
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    final before = controller.snapshot.workflow.nodes
        .firstWhere((node) => node.id == 'tap_a')
        .visual;
    expect(before, isNull);

    await tester.drag(
      find.byKey(const ValueKey('workflow-node-tap_a')),
      const Offset(90, 48),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final draggedNodes = controller.snapshot.workflow.nodes.firstWhere(
      (node) => node.id == 'tap_a',
    );
    expect(draggedNodes.visual?.x, greaterThan(28));
    expect(draggedNodes.visual?.y, greaterThan(28));

    await tester.tap(find.text('源码'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('"visual": {'), findsOneWidget);
    expect(find.textContaining('"x":'), findsWidgets);
    expect(find.textContaining('"y":'), findsWidgets);
  });

  testWidgets(
    'workflow canvas auto layout clears visual positions through DSL',
    (tester) async {
      final controller = StudioRuntimeController();

      await tester.pumpWidget(
        StudioMacApp(controllerFactory: () => controller),
      );

      await tester.tap(find.byKey(const ValueKey('nav-流程')));
      await tester.pump(const Duration(milliseconds: 250));

      await tester.drag(
        find.byKey(const ValueKey('workflow-node-tap_a')),
        const Offset(90, 48),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      var workflow = controller.snapshot.workflow;
      var draggedNodes = workflow.nodes.firstWhere(
        (node) => node.id == 'tap_a',
      );
      expect(draggedNodes.visual?.hasPosition, isTrue);
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('workflow-canvas-auto-layout')),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      });
      await tester.pump(const Duration(milliseconds: 250));

      workflow = controller.snapshot.workflow;
      draggedNodes = workflow.nodes.firstWhere((node) => node.id == 'tap_a');
      expect(draggedNodes.visual, isNull);
      expect(workflow.nodes.where((node) => node.visual != null), isEmpty);
      expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    },
  );
}
