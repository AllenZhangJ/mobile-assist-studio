import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Canvas 系统剪贴板回归测试。
// 用例保护跨 workflow 粘贴和剪贴板隐私边界。
void main() {
  // 验证系统剪贴板可跨 workflow 粘贴，同时不泄露运行私密信息。
  testWidgets('workflow canvas system clipboard pastes into another workflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final copiedText = captureClipboardText();

    final sourceController = StudioRuntimeController();
    await tester.pumpWidget(
      StudioMacApp(controllerFactory: () => sourceController),
    );

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
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    expect(copiedText(), isNotNull);
    expect(
      copiedText(),
      contains('ios-assist-studio.workflow-canvas-clipboard'),
    );
    expect(copiedText(), isNot(contains('session')));
    expect(copiedText(), isNot(contains('WDA')));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));

    final targetController = StudioRuntimeController();
    expect(
      await targetController.updateWorkflow(
        const WorkflowDefinition(
          id: 'blank-target',
          name: '空白目标',
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
        ),
      ),
      isTrue,
    );
    await tester.pumpWidget(
      StudioMacApp(controllerFactory: () => targetController),
    );

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));
    await selectWorkflowNode(tester, 'start');
    await tester.pump(const Duration(milliseconds: 250));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    await tester.pump(const Duration(milliseconds: 250));

    final workflow = targetController.snapshot.workflow;
    final start = workflow.nodes.firstWhere((node) => node.id == 'start');
    final tapCopy = workflow.nodes.firstWhere((node) => node.id == 'tap_new_1');
    final waitCopy = workflow.nodes.firstWhere(
      (node) => node.id == 'wait_new_1',
    );
    expect(const WorkflowValidator().validate(workflow).isValid, isTrue);
    expect(start.next, ['tap_new_1']);
    expect(tapCopy.type, WorkflowNodeType.tap);
    expect(tapCopy.next, ['wait_new_1']);
    expect(waitCopy.type, WorkflowNodeType.wait);
    expect(waitCopy.next, ['end']);
    expect(find.text('已选 2 个'), findsOneWidget);
  });
}
