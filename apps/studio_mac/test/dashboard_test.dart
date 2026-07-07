import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';

import 'support/studio_widget_harness.dart';

// Dashboard 页面回归测试，聚焦本机概览、最近流程和入口跳转。
// 这些用例独立于综合测试，便于后续按入口页持续扩展。
void main() {
  // 验证 Dashboard 汇总信息、流程详情抽屉和模块入口跳转。
  testWidgets('dashboard renders local KPIs and navigates to modules', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1200, 900));
    final entry = RunHistoryEntry(
      runId: 'run-2026-01-07T03-04-05Z',
      workflowName: 'Dashboard Workflow',
      status: 'completed',
      loops: 2,
      completedLoops: 2,
      startedAt: DateTime.utc(2026, 1, 7, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 7, 3, 4, 8),
    );
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runHistory: RunHistorySummary(
        totalRuns: 2,
        completedRuns: 2,
        failedRuns: 0,
        pausedRuns: 0,
        stoppedRuns: 0,
        dailyRuns: [
          RunHistoryDay(
            day: DateTime.utc(2026, 1, 7),
            totalRuns: 2,
            completedRuns: 2,
            failedRuns: 0,
            pausedRuns: 0,
            stoppedRuns: 0,
          ),
        ],
        recentRuns: [entry],
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    expect(find.text('就绪'), findsWidgets);
    expect(find.text('已连设备'), findsOneWidget);
    expect(find.text('流程'), findsWidgets);
    expect(find.text('今日运行'), findsOneWidget);
    expect(find.text('成功率'), findsOneWidget);
    expect(find.text('最近流程'), findsOneWidget);
    expect(find.text('本机流程摘要。'), findsOneWidget);
    expect(find.text('A-F 基础模板'), findsWidgets);
    expect(find.text('趋势'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboard-workflow-details')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dashboard-workflow-detail-drawer')),
      findsOneWidget,
    );
    expect(find.text('流程摘要'), findsOneWidget);
    expect(find.text('流程文件'), findsOneWidget);
    expect(find.text('节点组成'), findsOneWidget);
    expect(find.text('最近运行'), findsWidgets);
    expect(find.text('入口节点'), findsOneWidget);
    expect(find.text('完成'), findsWidgets);
    expect(find.text('点击'), findsOneWidget);
    expect(find.text('等待'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('边界'),
      find.byKey(const ValueKey('dashboard-workflow-detail-scroll')),
      const Offset(0, -220),
      maxIteration: 8,
    );
    expect(find.text('边界'), findsOneWidget);
    expect(find.text('completed'), findsNothing);
    expect(find.text('start'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.textContaining('/Users/'), findsNothing);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboard-open-workflow')));
    await tester.pumpAndSettle();

    expect(find.text('画布'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workflow-visual-canvas')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('nav-总览')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboard-open-execute')));
    await tester.pumpAndSettle();

    expect(find.text('运行设置'), findsOneWidget);
    expect(find.text('运行摘要'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('nav-总览')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('已连设备'));
    await tester.pumpAndSettle();

    expect(find.text('设备'), findsWidgets);
  });

  // 验证子流程缺失时，Dashboard 会禁用执行入口并说明原因。
  testWidgets('dashboard blocks execute shortcut for missing sub workflow', (
    tester,
  ) async {
    await useDesktopSurface(tester, size: const Size(1200, 900));
    final workflow = missingSubWorkflowDefinition();
    final preview = StudioRuntimeSnapshot.initial(workflow: workflow).copyWith(
      connectionStatus: ConnectionStatus.connected,
      appiumStatus: AppiumProcessStatus.running,
      runStatus: RunStatus.idle,
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    final executeButton = tester.widget<IconButton>(
      find.byKey(const ValueKey('dashboard-open-execute')),
    );
    expect(executeButton.onPressed, isNull);
    expect(find.byTooltip('需修正'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboard-workflow-details')));
    await tester.pumpAndSettle();

    expect(find.text('需修正'), findsOneWidget);
    expect(find.textContaining('不存在的子流程 missing-child'), findsOneWidget);
  });

  // 验证收藏、复制和删除都只更新本机 Runtime 状态。
  testWidgets('dashboard manages current workflow locally', (tester) async {
    await useDesktopSurface(tester, size: const Size(1200, 900));
    final controller = StudioRuntimeController();

    await tester.pumpWidget(StudioMacApp(controllerFactory: () => controller));
    await tester.pumpAndSettle();

    expect(find.byTooltip('收藏'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-workflow-favorite')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.settings.favoriteWorkflowIds, ['af-template']);
    expect(find.byTooltip('取消收藏'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboard-workflow-copy')));
    await tester.pumpAndSettle();

    expect(controller.snapshot.workflow.name, 'A-F 基础模板 副本');
    expect(find.text('A-F 基础模板 副本'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dashboard-workflow-delete')));
    await tester.pumpAndSettle();

    expect(find.text('删除流程？'), findsOneWidget);
    expect(find.text('会回到基础模板，设备不会动作。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(controller.snapshot.workflow.name, 'A-F 基础模板');
    expect(find.text('A-F 基础模板'), findsWidgets);
  });
}
