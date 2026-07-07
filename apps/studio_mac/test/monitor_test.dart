import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';

// Monitor Overview 回归测试，聚焦本地运行记录、趋势和筛选复制。
// 详情分析和截图证据分别放在 monitor_detail_test 与 monitor_evidence_test。
void main() {
  testWidgets('renders monitor run history shell', (tester) async {
    await tester.pumpWidget(const StudioMacApp());

    await tester.tap(find.byKey(const ValueKey('nav-记录')));
    await tester.pumpAndSettle();

    expect(find.text('总数'), findsOneWidget);
    expect(find.text('成功率'), findsOneWidget);
    expect(find.text('暂停'), findsWidgets);
    expect(find.text('7日趋势'), findsOneWidget);
    expect(find.text('状态分布'), findsOneWidget);
    expect(find.text('失败趋势'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('最近记录'),
      find.byKey(const ValueKey('monitor-page-scroll')),
      const Offset(0, -220),
      maxIteration: 8,
    );
    expect(find.text('最近记录'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
  });

  testWidgets('monitor exposes v4 acceptance command shortcuts', (
    tester,
  ) async {
    String? copiedCommand;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            copiedCommand = arguments['text'] as String?;
            return null;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final preview = StudioRuntimeSnapshot.initial().copyWith(
      mobileRuntime: MobileRuntimeSummary(
        platform: MobilePlatform.ios,
        resourceState: MobileResourceState.idle,
        capabilities: MobileDriverCapabilityReport.none.copyWith(
          platform: MobilePlatform.ios,
        ),
      ),
      runHistory: RunHistorySummary(
        totalRuns: 3,
        completedRuns: 2,
        failedRuns: 1,
        pausedRuns: 0,
        stoppedRuns: 0,
        dailyRuns: const [],
        recentRuns: [
          RunHistoryEntry(
            runId: 'run-v4-local-ok',
            workflowName: '验收流程',
            status: 'completed',
            loops: 1,
            completedLoops: 1,
            startedAt: DateTime.utc(2026, 1, 9),
            finishedAt: DateTime.utc(2026, 1, 9, 0, 0, 3),
          ),
        ],
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-记录')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('V4 验收'),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
      maxIteration: 8,
    );

    expect(find.text('V4 验收'), findsOneWidget);
    expect(find.text('待终验'), findsOneWidget);
    expect(find.text('当前平台'), findsOneWidget);
    expect(find.text('iOS'), findsOneWidget);
    expect(find.text('3 条'), findsOneWidget);
    expect(find.text('1 条'), findsOneWidget);
    expect(find.text('跑全量'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monitor-copy-v4-full-smoke')));
    await tester.pumpAndSettle();
    expect(copiedCommand, 'npm run v4:smoke:full');

    await tester.tap(
      find.byKey(const ValueKey('monitor-copy-v4-password-smoke')),
    );
    await tester.pumpAndSettle();
    expect(copiedCommand, 'npm run v4:smoke:full:password-stdin');

    await tester.tap(
      find.byKey(const ValueKey('monitor-copy-v4-android-smoke')),
    );
    await tester.pumpAndSettle();
    expect(copiedCommand, 'npm run v4:android-smoke:full');

    await tester.tap(
      find.byKey(const ValueKey('monitor-copy-v4-acceptance-audit')),
    );
    await tester.pumpAndSettle();
    expect(copiedCommand, 'npm run v4:acceptance-audit');
  });

  testWidgets('monitor renders local trend and status distribution', (
    tester,
  ) async {
    String? copiedRunsSummary;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final arguments = call.arguments as Map<Object?, Object?>;
            copiedRunsSummary = arguments['text'] as String?;
            return null;
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final entry = RunHistoryEntry(
      runId: 'run-2026-01-07T03-04-05Z',
      workflowName: '趋势流程',
      status: 'completed',
      loops: 2,
      completedLoops: 2,
      startedAt: DateTime.utc(2026, 1, 7, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 7, 3, 4, 8),
    );
    final failedEntry = RunHistoryEntry(
      runId: 'run-2026-01-04T03-04-05Z',
      workflowName: '失败流程',
      status: 'failed',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 4, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 4, 3, 4, 8),
    );
    final pausedEntry = RunHistoryEntry(
      runId: 'run-2026-01-06T03-04-05Z',
      workflowName: '暂停流程',
      status: 'paused',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 6, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 6, 3, 4, 8),
    );
    List<RunHistoryDay> trendDays(int count) {
      final anchor = DateTime.utc(2026, 1, 7);
      final completedDays = {
        DateTime.utc(2026, 1, 2),
        DateTime.utc(2026, 1, 7),
      };
      final failedDays = {DateTime.utc(2026, 1, 4)};
      final pausedDays = {DateTime.utc(2026, 1, 6)};
      return List.generate(count, (index) {
        final day = anchor.subtract(Duration(days: count - 1 - index));
        final completedRuns = completedDays.contains(day) ? 1 : 0;
        final failedRuns = failedDays.contains(day) ? 1 : 0;
        final pausedRuns = pausedDays.contains(day) ? 1 : 0;
        final stoppedRuns = index == 0 ? 1 : 0;
        return RunHistoryDay(
          day: day,
          totalRuns: completedRuns + failedRuns + pausedRuns + stoppedRuns,
          completedRuns: completedRuns,
          failedRuns: failedRuns,
          pausedRuns: pausedRuns,
          stoppedRuns: stoppedRuns,
        );
      });
    }

    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runHistory: RunHistorySummary(
        totalRuns: 4,
        completedRuns: 2,
        failedRuns: 1,
        pausedRuns: 1,
        stoppedRuns: 1,
        dailyRuns: trendDays(7),
        averageDuration: const Duration(seconds: 3),
        dailyRuns30: trendDays(30),
        dailyRuns90: trendDays(90),
        issueCategories: const [
          RunIssueCategoryCount(category: '低置信', count: 1),
          RunIssueCategoryCount(category: '暂停', count: 1),
        ],
        nodeDurationStats: [
          RunNodeDurationStat(
            nodeId: 'visual_1',
            nodeType: 'visualBranch',
            label: '视觉判断',
            sampleCount: 3,
            issueCount: 1,
            averageDuration: Duration(seconds: 4),
            maxDuration: Duration(seconds: 7),
            relatedRuns: [
              RunNodeDurationRun(
                runId: pausedEntry.runId,
                workflowName: pausedEntry.workflowName,
                status: pausedEntry.status,
                duration: Duration(seconds: 7),
                happenedAt: pausedEntry.startedAt,
              ),
            ],
          ),
        ],
        nodeDurationTrends: [
          RunNodeDurationTrend(
            nodeId: 'visual_1',
            nodeType: 'visualBranch',
            label: '视觉判断',
            averageDuration: const Duration(seconds: 4),
            maxDuration: const Duration(seconds: 7),
            sampleCount: 3,
            issueCount: 1,
            relatedRuns: [
              RunNodeDurationRun(
                runId: failedEntry.runId,
                workflowName: failedEntry.workflowName,
                status: failedEntry.status,
                duration: const Duration(seconds: 7),
                happenedAt: failedEntry.startedAt,
              ),
            ],
            points: [
              for (var index = 0; index < 7; index++)
                RunNodeDurationTrendPoint(
                  day: DateTime.utc(2026, 1, index + 1),
                  averageDuration: index == 6
                      ? const Duration(seconds: 7)
                      : const Duration(seconds: 3),
                  sampleCount: 1,
                  issueCount: index == 6 ? 1 : 0,
                ),
            ],
          ),
        ],
        failureClusters: [
          RunFailureCluster(
            category: 'Low Confidence',
            nodeId: 'visual_1',
            nodeType: 'visualBranch',
            label: '查屏幕',
            count: 2,
            workflowCount: 2,
            recentReason: '低置信',
            recentAt: DateTime.utc(2026, 1, 7, 3),
            relatedRuns: [
              RunFailureClusterRun(
                runId: failedEntry.runId,
                workflowName: failedEntry.workflowName,
                status: failedEntry.status,
                happenedAt: failedEntry.startedAt,
              ),
              RunFailureClusterRun(
                runId: pausedEntry.runId,
                workflowName: pausedEntry.workflowName,
                status: pausedEntry.status,
                happenedAt: pausedEntry.startedAt,
              ),
            ],
          ),
        ],
        recentRuns: [entry, failedEntry, pausedEntry],
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-记录')));
    await tester.pumpAndSettle();

    expect(find.text('7日趋势'), findsOneWidget);
    expect(find.text('均耗时'), findsOneWidget);
    expect(find.text('3s'), findsOneWidget);
    expect(find.byKey(const ValueKey('monitor-trend-thirty')), findsOneWidget);
    expect(find.byKey(const ValueKey('monitor-trend-ninety')), findsOneWidget);
    expect(find.text('状态分布'), findsOneWidget);
    expect(find.text('失败趋势'), findsOneWidget);
    expect(find.text('失败 1'), findsWidgets);
    expect(find.text('暂停 1'), findsWidgets);
    expect(find.text('已停 1'), findsWidgets);
    expect(find.text('常见问题'), findsOneWidget);
    expect(find.text('低置信 · 查屏幕'), findsOneWidget);
    expect(find.text('2 次'), findsOneWidget);
    expect(find.textContaining('2 流程'), findsOneWidget);
    expect(find.textContaining('2 记录'), findsOneWidget);
    expect(find.text('问题分类'), findsOneWidget);
    expect(find.text('耗时节点'), findsOneWidget);
    expect(find.text('视觉判断'), findsOneWidget);
    expect(find.text('均'), findsOneWidget);
    expect(find.text('峰'), findsOneWidget);
    expect(find.text('样本'), findsOneWidget);
    expect(find.text('4s'), findsOneWidget);
    expect(find.text('7s'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('node-duration-runs-visual_1')),
      findsOneWidget,
    );
    expect(find.text('低置信'), findsOneWidget);
    expect(find.text('完成'), findsWidgets);
    expect(find.text('失败'), findsWidgets);
    expect(find.text('暂停'), findsWidgets);
    expect(find.text('已停'), findsWidgets);
    expect(find.text('1/7'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('monitor-trend-thirty')));
    await tester.pumpAndSettle();

    expect(find.text('30日趋势'), findsOneWidget);
    expect(find.text('12/9'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('monitor-trend-ninety')));
    await tester.pumpAndSettle();

    expect(find.text('90日趋势'), findsOneWidget);
    expect(find.text('10/10'), findsWidgets);

    await tester.dragUntilVisible(
      find.text('耗时趋势'),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -180),
      maxIteration: 6,
    );
    expect(find.text('耗时趋势'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('node-duration-trend-runs-visual_1')),
      findsOneWidget,
    );

    await tester.dragUntilVisible(
      find.text('最近记录'),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
      maxIteration: 8,
    );
    expect(find.text('趋势流程'), findsOneWidget);
    expect(find.text('失败流程'), findsWidgets);
    expect(find.text('暂停流程'), findsOneWidget);

    await tester.dragUntilVisible(
      find.byKey(
        const ValueKey('failure-cluster-runs-Low Confidence-visual_1'),
      ),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 220),
      maxIteration: 8,
    );
    await tester.drag(
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 180),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(
        const ValueKey('failure-cluster-runs-Low Confidence-visual_1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('monitor-related-runs-banner')),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
      maxIteration: 8,
    );
    expect(find.textContaining('低置信 · 查屏幕 · 2 条'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('monitor-drilldown-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('monitor-run-compare-panel')),
      findsOneWidget,
    );
    expect(find.textContaining('深挖摘要 · 低置信 · 查屏幕'), findsOneWidget);
    expect(find.text('关联流程：失败流程、暂停流程'), findsOneWidget);
    expect(find.text('运行对比'), findsOneWidget);
    expect(find.text('2 连续问题'), findsOneWidget);
    expect(find.text('最近变化'), findsOneWidget);
    expect(find.text('失败 -> 暂停'), findsOneWidget);
    expect(find.textContaining('暂停流程 · 暂停'), findsWidgets);
    expect(find.text('失败流程'), findsOneWidget);
    expect(find.text('趋势流程'), findsNothing);
    expect(find.text('暂停流程'), findsWidgets);
    expect(find.textContaining('run-2026'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('monitor-related-runs-clear')),
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('monitor-related-runs-clear')));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('耗时趋势'),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 220),
      maxIteration: 8,
    );
    await tester.drag(
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, 160),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('node-duration-trend-runs-visual_1')),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('monitor-duration-drilldown-panel')),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
      maxIteration: 8,
    );
    expect(find.textContaining('耗时深挖 · 视觉判断'), findsOneWidget);
    expect(find.text('峰值日'), findsOneWidget);
    expect(find.text('峰值'), findsOneWidget);
    expect(find.text('问题日'), findsOneWidget);
    expect(find.text('最近'), findsWidgets);
    expect(find.text('7s'), findsWidgets);
    expect(find.textContaining('1 次 · 问题'), findsOneWidget);
    expect(find.textContaining('run-2026'), findsNothing);

    final relatedRunsClear = find.byKey(
      const ValueKey('monitor-related-runs-clear'),
    );
    await Scrollable.ensureVisible(
      tester.element(relatedRunsClear),
      alignment: 0.3,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(relatedRunsClear);
    await tester.pumpAndSettle();

    final issuesFilter = find.byKey(const ValueKey('monitor-filter-issues'));
    await Scrollable.ensureVisible(
      tester.element(issuesFilter),
      alignment: 0.3,
      duration: Duration.zero,
    );
    await tester.pumpAndSettle();
    await tester.tap(issuesFilter);
    await tester.pumpAndSettle();

    expect(find.text('趋势流程'), findsNothing);
    expect(find.text('失败流程'), findsOneWidget);
    expect(find.text('暂停流程'), findsOneWidget);

    final completedFilter = find.byKey(
      const ValueKey('monitor-filter-completed'),
    );
    await tester.scrollUntilVisible(
      completedFilter,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(completedFilter);
    await tester.pumpAndSettle();

    expect(find.text('趋势流程'), findsOneWidget);
    expect(find.text('失败流程'), findsNothing);
    expect(find.text('暂停流程'), findsNothing);

    final allFilter = find.byKey(const ValueKey('monitor-filter-all'));
    await tester.scrollUntilVisible(
      allFilter,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(allFilter);
    await tester.pumpAndSettle();

    final runSearch = find.byKey(const ValueKey('monitor-run-search'));
    await tester.scrollUntilVisible(
      runSearch,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(runSearch, '暂停');
    await tester.pumpAndSettle();

    expect(find.text('趋势流程'), findsNothing);
    expect(find.text('失败流程'), findsNothing);
    expect(find.text('暂停流程'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('monitor-copy-runs-summary')));
    await tester.pumpAndSettle();

    expect(copiedRunsSummary, contains('运行记录摘要'));
    expect(copiedRunsSummary, contains('筛选：全部'));
    expect(copiedRunsSummary, contains('搜索：暂停'));
    expect(copiedRunsSummary, contains('数量：1'));
    expect(copiedRunsSummary, contains('暂停 · 暂停流程 · 0/1 轮'));
    expect(copiedRunsSummary, isNot(contains('趋势流程')));
    expect(copiedRunsSummary, isNot(contains('失败流程')));
    expect(copiedRunsSummary, isNot(contains('run-2026')));
    expect(copiedRunsSummary, isNot(contains('/Users/')));
    expect(copiedRunsSummary, isNot(contains('127.0.0.1')));

    await tester.tap(find.byTooltip('清空搜索'));
    await tester.pumpAndSettle();

    expect(find.text('趋势流程'), findsOneWidget);
    expect(find.text('失败流程'), findsOneWidget);
    expect(find.text('暂停流程'), findsOneWidget);
  });

  // 验证问题分类可进入最近记录筛选，不读取详情或截图。
  testWidgets('monitor issue category filters related local runs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    final completedEntry = RunHistoryEntry(
      runId: 'run-completed-local',
      workflowName: '完成流程',
      status: 'completed',
      loops: 1,
      completedLoops: 1,
      startedAt: DateTime.utc(2026, 1, 8, 3),
      finishedAt: DateTime.utc(2026, 1, 8, 3, 0, 2),
    );
    final failedEntry = RunHistoryEntry(
      runId: 'run-failed-local',
      workflowName: '失败流程',
      status: 'failed',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 8, 4),
      finishedAt: DateTime.utc(2026, 1, 8, 4, 0, 2),
    );
    final otherFailedEntry = RunHistoryEntry(
      runId: 'run-other-failed-local',
      workflowName: '其他失败',
      status: 'failed',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 8, 4, 30),
      finishedAt: DateTime.utc(2026, 1, 8, 4, 30, 2),
    );
    final pausedEntry = RunHistoryEntry(
      runId: 'run-paused-local',
      workflowName: '暂停流程',
      status: 'paused',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 8, 5),
      finishedAt: DateTime.utc(2026, 1, 8, 5, 0, 2),
    );
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runHistory: RunHistorySummary(
        totalRuns: 4,
        completedRuns: 1,
        failedRuns: 2,
        pausedRuns: 1,
        stoppedRuns: 0,
        dailyRuns: const [],
        issueCategories: [
          RunIssueCategoryCount(
            category: 'Low Confidence',
            count: 1,
            relatedRuns: [
              RunIssueCategoryRun(
                runId: failedEntry.runId,
                workflowName: failedEntry.workflowName,
                status: failedEntry.status,
                happenedAt: failedEntry.startedAt,
              ),
            ],
          ),
          RunIssueCategoryCount(category: 'Paused', count: 1),
        ],
        recentRuns: [
          completedEntry,
          failedEntry,
          otherFailedEntry,
          pausedEntry,
        ],
      ),
    );

    await tester.pumpWidget(StudioMacApp(previewScreenshot: preview));

    await tester.tap(find.byKey(const ValueKey('nav-记录')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('issue-category-runs-Low Confidence')),
    );
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.byKey(const ValueKey('monitor-related-runs-banner')),
      find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
      const Offset(0, -220),
      maxIteration: 8,
    );

    expect(find.textContaining('分类 · 低置信 · 1 条'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('monitor-drilldown-panel')),
      findsOneWidget,
    );
    expect(find.textContaining('深挖摘要 · 分类 · 低置信'), findsOneWidget);
    expect(find.text('关联流程：失败流程'), findsOneWidget);
    expect(find.text('失败流程'), findsOneWidget);
    expect(find.text('其他失败'), findsNothing);
    expect(find.text('完成流程'), findsNothing);
    expect(find.text('暂停流程'), findsNothing);
    expect(find.textContaining('run-failed-local'), findsNothing);
  });
}
