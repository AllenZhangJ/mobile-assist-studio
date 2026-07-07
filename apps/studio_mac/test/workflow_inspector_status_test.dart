// ignore_for_file: unused_import, unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/studio_widget_harness.dart';

// Workflow Inspector 状态区回归测试，聚焦运行状态文案和安全上下文字段。
// 用例只读取 Runtime snapshot，不连接真实设备、不启动 Appium。
void main() {
  testWidgets('workflow inspector keeps runtime status copy in Chinese', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.running,
      executionFocus: const RuntimeExecutionFocus(
        activeNodeId: 'tap_a',
        completedNodeIds: {'start'},
        failedNodeId: null,
        activeLoopIndex: 0,
        totalLoops: 2,
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));
    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('运行锁'), findsOneWidget);
    expect(find.text('运行中'), findsWidgets);
    expect(find.text('设备就绪'), findsWidgets);
    expect(find.text('running'), findsNothing);
    expect(find.text('connected'), findsNothing);
  });

  testWidgets('workflow inspector surfaces safe context variables', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final copiedText = captureClipboardText();
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      runStatus: RunStatus.running,
      sessionId: 'redacted-session-placeholder',
      latestScreenshotBase64: 'snapshot-preview',
      latestScreenshotAt: DateTime(2026, 1, 7, 3, 4, 5),
      executionFocus: const RuntimeExecutionFocus(
        activeNodeId: 'tap_a',
        completedNodeIds: {'start'},
        failedNodeId: null,
        activeLoopIndex: 2,
        totalLoops: 7,
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-流程')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-context-panel')),
      findsOneWidget,
    );
    expect(find.text('上下文'), findsOneWidget);
    expect(find.text('只读'), findsOneWidget);
    expect(find.text('context.loopIndex'), findsOneWidget);
    expect(find.text('context.loopNumber'), findsOneWidget);
    expect(find.text('context.totalLoops'), findsOneWidget);
    expect(find.text('context.hasScreenshot'), findsOneWidget);
    expect(find.text('context.connectionStatus'), findsOneWidget);
    expect(find.text('context.runStatus'), findsOneWidget);
    expect(find.text('context.inputs.xxx'), findsOneWidget);
    expect(find.text('context.execution.loopIndex'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workflow-context-copy-loop-index')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workflow-context-copy-all')),
      findsOneWidget,
    );

    final copyAllButton = find.byKey(
      const ValueKey('workflow-context-copy-all'),
    );
    await tester.ensureVisible(copyAllButton);
    await tester.pump();
    await tester.tap(copyAllButton);
    await tester.pump();

    expect(copiedText(), contains('可用变量'));
    expect(copiedText(), contains('context.loopNumber'));
    expect(copiedText(), contains('context.hasScreenshot'));
    expect(copiedText(), contains('当前轮次'));
    expect(copiedText(), isNot(contains('redacted-session-placeholder')));
    expect(copiedText(), isNot(contains('session')));
    expect(find.text('redacted-session-placeholder'), findsNothing);
  });
}
