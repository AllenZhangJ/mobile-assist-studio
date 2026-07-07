import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_mac/studio_mac.dart';
import 'package:studio_runtime/studio_runtime.dart';

import 'support/studio_widget_harness.dart';

// Monitor 运行详情回归测试，聚焦问题分析、视觉证据链和脱敏摘要。
// 用例只读取本地运行详情 fake，不连接真实设备、不展示原始路径。
void main() {
  testWidgets('monitor opens local run detail with issue analysis', (
    tester,
  ) async {
    String? copiedSummary;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final data = Map<String, Object?>.from(call.arguments as Map);
          copiedSummary = data['text'] as String?;
          return null;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final entry = RunHistoryEntry(
      runId: 'run-2026-01-02T03-04-05Z',
      workflowName: '失败流程',
      status: 'failed',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 2, 3, 4, 8),
    );
    final detail = RunDetail(
      entry: entry,
      events: [
        RunEvidenceEvent(
          type: 'smokeStart',
          status: null,
          nodeId: null,
          nodeType: null,
          label: null,
          loopIndex: null,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 2, 3, 4, 5),
          platform: 'android',
          actionsAllowed: true,
        ),
        RunEvidenceEvent(
          type: 'smokeSession',
          status: null,
          nodeId: null,
          nodeType: null,
          label: null,
          loopIndex: null,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 2, 3, 4, 5),
          platform: 'android',
          deviceName: 'Pixel 9',
          maskedDeviceId: 'ZY22...CDEF',
          osVersion: '15',
          connectionKind: 'usb',
        ),
        RunEvidenceEvent(
          type: 'smokeLogs',
          status: null,
          nodeId: null,
          nodeType: null,
          label: null,
          loopIndex: null,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 2, 3, 4, 5),
          platform: 'android',
          logCount: 4,
        ),
        RunEvidenceEvent(
          type: 'stepStart',
          status: null,
          nodeId: 'condition_1',
          nodeType: 'condition',
          label: null,
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 2, 3, 4, 6),
        ),
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'failed',
          nodeId: 'condition_1',
          nodeType: 'condition',
          label: null,
          loopIndex: 0,
          error: '条件置信度过低。',
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 2, 3, 4, 7),
        ),
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'ok',
          nodeId: 'snapshot_1',
          nodeType: 'snapshot',
          label: '截图证据',
          loopIndex: 0,
          error: null,
          screenshotPath: 'screenshots/snapshot_1-loop-1.png',
          at: DateTime.utc(2026, 1, 2, 3, 4, 8),
        ),
        RunEvidenceEvent(
          type: 'subWorkflowStart',
          status: 'running',
          nodeId: 'sub_1',
          nodeType: 'subWorkflow',
          label: '登录子流程',
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 2, 3, 4, 8),
          inputCount: 2,
          inputNames: const ['loopNumber', 'hasShot'],
        ),
      ],
    );
    final report = detail.report;
    final reportExporter = FakeRunReportExporter({
      'run-2026-01-02T03-04-05Z': RunReportExportResult(
        runId: 'run-2026-01-02T03-04-05Z',
        fileName: 'run-2026-01-02T03-04-05Z-report.json',
        relativePath: 'exports/run-2026-01-02T03-04-05Z-report.json',
        exportedAt: DateTime.utc(2026, 1, 2, 3, 4, 9),
      ),
    });
    final controller = StudioRuntimeController(
      runDetailReader: FakeRunDetailReader({
        'run-2026-01-02T03-04-05Z': detail,
      }),
      runReportReader: FakeRunReportReader({
        'run-2026-01-02T03-04-05Z': report,
      }),
      runReportExporter: reportExporter,
      runEvidenceAssetReader: const FakeRunEvidenceAssetReader({
        'run-2026-01-02T03-04-05Z/screenshots/snapshot_1-loop-1.png':
            onePixelPngBase64,
      }),
    );
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runHistory: RunHistorySummary(
        totalRuns: 1,
        completedRuns: 0,
        failedRuns: 1,
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
    expect(find.text('失败流程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('copy-run-detail-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('copy-run-report-json')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('export-run-report-json')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('copy-run-detail-summary')));
    await tester.pumpAndSettle();

    expect(copiedSummary, isNotNull);
    expect(copiedSummary, contains('iOS Assist Studio 运行摘要'));
    expect(copiedSummary, contains('流程：失败流程'));
    expect(copiedSummary, contains('状态：失败'));
    expect(copiedSummary, contains('问题节点：条件'));
    expect(copiedSummary, contains('原因：条件置信度过低。'));
    expect(copiedSummary, contains('路径：1/2 步，问题 1，截图 1'));
    expect(copiedSummary, isNot(contains('screenshots/')));
    expect(copiedSummary, isNot(contains('127.0.0.1')));
    expect(copiedSummary, isNot(contains('session')));
    expect(copiedSummary, isNot(contains('WDA')));
    expect(copiedSummary, isNot(contains('condition_1')));
    expect(find.text('已复制摘要。'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('copy-run-report-json')));
    await tester.pumpAndSettle();

    expect(copiedSummary, isNotNull);
    final copiedReport = copiedSummary!;
    final decodedReport = jsonDecode(copiedReport) as Map<String, Object?>;
    final overview = decodedReport['overview'] as Map<String, Object?>;
    final issue = decodedReport['issue'] as Map<String, Object?>;
    final platform = decodedReport['platform'] as Map<String, Object?>;
    expect(overview['workflowName'], '失败流程');
    expect(overview['status'], 'failed');
    expect(overview['screenshotCount'], 1);
    expect(issue['category'], 'Low Confidence');
    expect(platform['platform'], 'android');
    expect(platform['deviceName'], 'Pixel 9');
    expect(platform['maskedDeviceId'], 'ZY22...CDEF');
    expect(platform['logCount'], 4);
    expect(copiedReport, isNot(contains('/Users')));
    expect(copiedReport, isNot(contains('127.0.0.1')));
    expect(copiedReport, isNot(contains('session')));

    await tester.tap(find.byKey(const ValueKey('export-run-report-json')));
    await tester.pumpAndSettle();

    expect(reportExporter.exportedRunIds, ['run-2026-01-02T03-04-05Z']);
    expect(
      find.text('报告已存：exports/run-2026-01-02T03-04-05Z-report.json'),
      findsOneWidget,
    );
    expect(find.textContaining('/Users'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);

    expect(
      find.byKey(const ValueKey('run-local-report-panel')),
      findsOneWidget,
    );
    expect(find.text('本地报告'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-failure-analysis')), findsOneWidget);
    expect(find.text('问题分析'), findsOneWidget);
    expect(find.text('低置信'), findsWidgets);
    expect(
      find.byKey(const ValueKey('run-issue-recommendations')),
      findsOneWidget,
    );
    expect(find.text('处理建议'), findsOneWidget);
    expect(find.text('先看画面'), findsOneWidget);
    expect(find.textContaining('条件 判断不够确定'), findsOneWidget);
    expect(find.text('看证据'), findsOneWidget);
    expect(find.textContaining('已有 1 张截图'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-ai-explanation')), findsOneWidget);
    expect(find.text('智能解释'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('run-ai-explain-failure')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('run-ai-explain-failure')));
    await tester.pumpAndSettle();

    expect(find.text('视觉判断没有稳定命中。'), findsOneWidget);
    expect(find.textContaining('原因：条件置信度过低。'), findsOneWidget);
    expect(controller.snapshot.aiAuditLog.last.toolId, 'explainRunFailure');
    expect(find.textContaining('/Users'), findsNothing);
    expect(find.textContaining('127.0.0.1'), findsNothing);
    expect(find.textContaining('session'), findsNothing);
    expect(find.byKey(const ValueKey('run-execution-metrics')), findsOneWidget);
    expect(find.text('路径摘要'), findsOneWidget);
    expect(find.text('步数'), findsOneWidget);
    expect(find.text('1/2'), findsWidgets);
    expect(find.text('问题'), findsWidgets);
    expect(find.text('截图'), findsWidgets);
    expect(find.text('平台'), findsWidgets);
    expect(find.text('安卓'), findsOneWidget);
    expect(find.text('日志'), findsWidgets);
    expect(find.text('4'), findsWidgets);
    expect(find.text('设备'), findsWidgets);
    expect(find.text('Pixel 9'), findsOneWidget);
    expect(find.textContaining('Android 已带日志摘要'), findsOneWidget);
    expect(find.text('最慢节点'), findsOneWidget);
    expect(find.text('最慢耗时'), findsOneWidget);
    expect(find.text('问题节点'), findsWidgets);
    expect(find.text('节点类型'), findsOneWidget);
    expect(find.text('条件'), findsWidgets);
    expect(find.text('证据'), findsOneWidget);
    expect(find.text('1 张截图'), findsWidgets);
    expect(
      find.byKey(const ValueKey('run-evidence-filmstrip')),
      findsOneWidget,
    );
    expect(find.text('证据条'), findsOneWidget);
    expect(find.text('1 张截图'), findsWidgets);
    expect(find.text('condition_1'), findsNothing);
    expect(find.text('条件置信度过低。'), findsWidgets);
    expect(find.text('条件'), findsWidgets);
    expect(find.text('第 1 轮'), findsWidgets);
    expect(find.text('1s'), findsWidgets);
    expect(find.text('截图证据'), findsWidgets);
    expect(find.text('查看'), findsWidgets);
    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-snapshot_1-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('screenshot-evidence-image-snapshot_1-0')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('run-related-events')), findsOneWidget);
    expect(find.text('相关事件'), findsOneWidget);
    expect(find.byKey(const ValueKey('run-event-filter-all')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('run-event-filter-nodes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-event-filter-issues')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-event-filter-screenshots')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-event-row-stepEnd-condition_1-0-failed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-event-row-stepEnd-snapshot_1-0-ok')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('run-event-row-subWorkflowStart-sub_1-0-running'),
      ),
      findsOneWidget,
    );
    expect(find.text('传参 2 项：loopNumber、hasShot'), findsOneWidget);
    expect(find.text('子流程'), findsWidgets);

    final issueEventFilter = find.byKey(
      const ValueKey('run-event-filter-issues'),
    );
    await tester.scrollUntilVisible(
      issueEventFilter,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(issueEventFilter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('run-event-row-stepEnd-condition_1-0-failed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-event-row-stepEnd-snapshot_1-0-ok')),
      findsNothing,
    );

    final screenshotEventFilter = find.byKey(
      const ValueKey('run-event-filter-screenshots'),
    );
    await tester.tap(screenshotEventFilter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('run-event-row-stepEnd-condition_1-0-failed')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('run-event-row-stepEnd-snapshot_1-0-ok')),
      findsOneWidget,
    );

    expect(find.byKey(const ValueKey('run-trace-filter-all')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('run-trace-filter-issues')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-trace-filter-screenshots')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-trace-row-condition_1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-trace-row-snapshot_1-0')),
      findsOneWidget,
    );

    final issueTraceFilter = find.byKey(
      const ValueKey('run-trace-filter-issues'),
    );
    await tester.scrollUntilVisible(
      issueTraceFilter,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(issueTraceFilter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('run-trace-row-condition_1-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('run-trace-row-snapshot_1-0')),
      findsNothing,
    );

    final screenshotTraceFilter = find.byKey(
      const ValueKey('run-trace-filter-screenshots'),
    );
    await tester.tap(screenshotTraceFilter);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('run-trace-row-condition_1-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('run-trace-row-snapshot_1-0')),
      findsOneWidget,
    );

    final filmstripToggle = find.byKey(
      const ValueKey('evidence-filmstrip-toggle-snapshot_1-0'),
    );
    await tester.scrollUntilVisible(
      filmstripToggle,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(filmstripToggle);
    await tester.pumpAndSettle();

    expect(find.text('隐藏'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-snapshot_1-0')),
      findsOneWidget,
    );

    await tester.tap(filmstripToggle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('evidence-filmstrip-image-snapshot_1-0')),
      findsNothing,
    );

    final evidenceToggle = find.byKey(
      const ValueKey('screenshot-evidence-toggle-snapshot_1-0'),
    );
    await tester.scrollUntilVisible(
      evidenceToggle,
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(evidenceToggle);
    await tester.pumpAndSettle();

    expect(find.text('隐藏'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('screenshot-evidence-image-snapshot_1-0')),
      findsOneWidget,
    );
  });

  testWidgets('monitor opens paused run detail with issue analysis', (
    tester,
  ) async {
    final entry = RunHistoryEntry(
      runId: 'run-2026-01-03T03-04-05Z',
      workflowName: '暂停流程',
      status: 'paused',
      loops: 1,
      completedLoops: 0,
      startedAt: DateTime.utc(2026, 1, 3, 3, 4, 5),
      finishedAt: DateTime.utc(2026, 1, 3, 3, 4, 8),
    );
    final detail = RunDetail(
      entry: entry,
      events: [
        RunEvidenceEvent(
          type: 'stepStart',
          status: null,
          nodeId: 'visual_1',
          nodeType: 'visualBranch',
          label: '查屏幕',
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 3, 3, 4, 6),
        ),
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'paused',
          nodeId: 'visual_1',
          nodeType: 'visualBranch',
          label: '查屏幕',
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 3, 3, 4, 7),
          visualEvidence: const RunVisualEvidence(
            rule: 'latest_screenshot_presence',
            screenshotAvailable: false,
            confidence: 0,
            confidenceThreshold: 0.8,
            result: false,
            action: 'pause',
            reason: '最新截图缺失或置信度不足。',
            selectedNext: null,
          ),
        ),
      ],
    );
    final report = detail.report;
    final controller = StudioRuntimeController(
      runDetailReader: FakeRunDetailReader({
        'run-2026-01-03T03-04-05Z': detail,
      }),
      runReportReader: FakeRunReportReader({
        'run-2026-01-03T03-04-05Z': report,
      }),
    );
    final preview = StudioRuntimeSnapshot.initial().copyWith(
      runHistory: RunHistorySummary(
        totalRuns: 1,
        completedRuns: 0,
        failedRuns: 0,
        pausedRuns: 1,
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
    expect(find.text('暂停流程'), findsWidgets);
    expect(
      find.byKey(const ValueKey('run-local-report-panel')),
      findsOneWidget,
    );
    expect(find.text('本地报告'), findsOneWidget);
    expect(find.text('视觉复盘'), findsOneWidget);
    expect(find.text('问题分析'), findsOneWidget);
    expect(find.text('暂停'), findsWidgets);
    expect(find.text('问题节点'), findsWidgets);
    expect(find.text('查屏幕'), findsWidgets);
    expect(find.text('看图'), findsWidgets);
    expect(
      find.byKey(const ValueKey('run-issue-recommendations')),
      findsOneWidget,
    );
    expect(find.text('处理建议'), findsOneWidget);
    expect(find.text('人工确认'), findsOneWidget);
    expect(find.textContaining('查屏幕 已暂停'), findsOneWidget);
    expect(find.text('先补截图'), findsOneWidget);
    expect(find.text('查规则'), findsOneWidget);
    expect(find.text('visualBranch'), findsNothing);
    expect(
      find.byKey(const ValueKey('run-visual-evidence-chain')),
      findsOneWidget,
    );
    expect(find.text('视觉证据'), findsOneWidget);
    expect(find.text('最新截图'), findsOneWidget);
    expect(find.text('缺失'), findsOneWidget);
    expect(find.text('0.0% / 80.0%'), findsOneWidget);
    expect(find.text('暂停确认'), findsOneWidget);
    expect(find.text('最新截图缺失或置信度不足。'), findsOneWidget);
    expect(find.text('运行已暂停，等待人工处理。'), findsWidgets);
  });
}
