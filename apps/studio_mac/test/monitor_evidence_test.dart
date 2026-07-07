// ignore_for_file: unused_import, unnecessary_import

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';

import 'support/studio_widget_harness.dart';

// Monitor 截图证据回归测试，聚焦截图 reveal、胶片和回放。
// 用例只读取本地 evidence fake，不展示路径、不连接真实设备。
void main() {
  testWidgets('run detail honors screenshot reveal preference', (tester) async {
    final entry = RunHistoryEntry(
      runId: 'run-2026-01-04T03-04-05Z',
      workflowName: 'Evidence Workflow',
      status: 'completed',
      loops: 1,
      completedLoops: 1,
      startedAt: DateTime.utc(2026, 1, 4, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 4, 3, 4, 8),
    );
    final detail = RunDetail(
      entry: entry,
      events: [
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'ok',
          nodeId: 'snapshot_1',
          nodeType: 'snapshot',
          label: null,
          loopIndex: 0,
          error: null,
          screenshotPath: 'screenshots/snapshot_1-loop-1.png',
          at: DateTime.utc(2026, 1, 4, 3, 4, 7),
        ),
      ],
    );
    final controller = StudioRuntimeController(
      settings: StudioSettings(revealScreenshotsByDefault: true),
      runDetailReader: FakeRunDetailReader({
        'run-2026-01-04T03-04-05Z': detail,
      }),
      runEvidenceAssetReader: const FakeRunEvidenceAssetReader({
        'run-2026-01-04T03-04-05Z/screenshots/snapshot_1-loop-1.png':
            onePixelPngBase64,
      }),
    );
    final preview =
        StudioRuntimeSnapshot.initial(
          settings: StudioSettings(revealScreenshotsByDefault: true),
        ).copyWith(
          runHistory: RunHistorySummary(
            totalRuns: 1,
            completedRuns: 1,
            failedRuns: 0,
            pausedRuns: 0,
            stoppedRuns: 0,
            dailyRuns: const <RunHistoryDay>[],
            recentRuns: [entry],
          ),
        );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-记录')));
    await tester.pump(const Duration(milliseconds: 250));
    final detailButton = find.byKey(ValueKey('run-detail-${entry.runId}'));
    await tester.scrollUntilVisible(
      detailButton,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(
      find.byKey(const ValueKey('monitor-page-scroll')),
      const Offset(0, -96),
    );
    await tester.pumpAndSettle();
    await tester.tap(detailButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('run-detail-drawer')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-snapshot_1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('screenshot-evidence-image-snapshot_1-0')),
      findsOneWidget,
    );
    expect(find.text('隐藏'), findsWidgets);
    expect(find.text('snapshot_1'), findsNothing);
    expect(find.text('截图'), findsWidgets);

    await controller.dispose();
  });

  testWidgets('run detail replays screenshot evidence by index', (
    tester,
  ) async {
    final entry = RunHistoryEntry(
      runId: 'run-2026-01-05T03-04-05Z',
      workflowName: '截图流程',
      status: 'completed',
      loops: 2,
      completedLoops: 2,
      startedAt: DateTime.utc(2026, 1, 5, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 5, 3, 4, 11),
    );
    final detail = RunDetail(
      entry: entry,
      events: [
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'ok',
          nodeId: 'snapshot_1',
          nodeType: 'snapshot',
          label: '首张截图',
          loopIndex: 0,
          error: null,
          screenshotPath: 'screenshots/snapshot_1-loop-1.png',
          at: DateTime.utc(2026, 1, 5, 3, 4, 7),
        ),
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'ok',
          nodeId: 'snapshot_2',
          nodeType: 'snapshot',
          label: '第二张',
          loopIndex: 1,
          error: null,
          screenshotPath: 'screenshots/snapshot_2-loop-2.png',
          at: DateTime.utc(2026, 1, 5, 3, 4, 10),
        ),
      ],
    );
    final controller = StudioRuntimeController(
      runDetailReader: FakeRunDetailReader({
        'run-2026-01-05T03-04-05Z': detail,
      }),
      runEvidenceAssetReader: const FakeRunEvidenceAssetReader({
        'run-2026-01-05T03-04-05Z/screenshots/snapshot_1-loop-1.png':
            onePixelPngBase64,
        'run-2026-01-05T03-04-05Z/screenshots/snapshot_2-loop-2.png':
            onePixelPngBase64,
      }),
    );
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runHistory: RunHistorySummary(
        totalRuns: 1,
        completedRuns: 1,
        failedRuns: 0,
        pausedRuns: 0,
        stoppedRuns: 0,
        dailyRuns: const <RunHistoryDay>[],
        recentRuns: [entry],
      ),
    );

    await tester.pumpWidget(
      StudioMacApp(
        controllerFactory: () => controller,
        previewScreenshot: preview,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('nav-记录')));
    await tester.pump(const Duration(milliseconds: 250));
    final detailButton = find.byKey(ValueKey('run-detail-${entry.runId}'));
    await tester.scrollUntilVisible(
      detailButton,
      120,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('monitor-page-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(
      find.byKey(const ValueKey('monitor-page-scroll')),
      const Offset(0, -96),
    );
    await tester.pumpAndSettle();
    await tester.tap(detailButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('run-evidence-replay')), findsNothing);
    expect(find.text('2 张截图'), findsWidgets);
    expect(find.text('首张截图'), findsWidgets);
    expect(find.text('第二张'), findsWidgets);
    expect(find.textContaining('screenshots/'), findsNothing);

    final firstToggle = find.byKey(
      const ValueKey('evidence-filmstrip-toggle-snapshot_1-0'),
    );
    await tester.scrollUntilVisible(
      firstToggle,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(firstToggle);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('run-evidence-replay')), findsOneWidget);
    expect(find.text('截图回放'), findsOneWidget);
    expect(find.text('第 1/2 张'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-snapshot_1-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('evidence-replay-next')));
    await tester.pumpAndSettle();

    expect(find.text('第 2/2 张'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-snapshot_1-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-snapshot_2-1')),
      findsOneWidget,
    );
    expect(find.textContaining('screenshots/'), findsNothing);

    await controller.dispose();
  });
}
