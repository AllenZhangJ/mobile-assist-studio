import 'dart:convert';
import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

// 本地证据详情读取测试。
// 用例覆盖失败分析、截图证据和暂停详情。
void main() {
  // 验证失败运行详情包含分析、指标、截图和安全路径限制。
  test('local evidence store reads run detail and failure summary', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);

    final runId = await store.startRun(
      workflowName: 'Failing Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 6).toIso8601String(),
      'type': 'stepStart',
      'nodeId': 'condition_1',
      'nodeType': 'condition',
      'label': 'Check Ready',
      'loopIndex': 0,
    });
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 7).toIso8601String(),
      'type': 'stepEnd',
      'status': 'failed',
      'nodeId': 'condition_1',
      'nodeType': 'condition',
      'label': 'Check Ready',
      'loopIndex': 0,
      'error': 'Condition confidence was too low.',
    });
    final screenshotPath = await store.recordScreenshot(
      runId,
      fileName: 'snapshot_1-loop-1.png',
      base64Png: base64Encode([1, 2, 3, 4]),
    );
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 8).toIso8601String(),
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': 'snapshot_1',
      'nodeType': 'snapshot',
      'label': 'Screenshot Evidence',
      'loopIndex': 0,
      'screenshotPath': screenshotPath,
    });
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 8).toIso8601String(),
      'type': 'subWorkflowStart',
      'status': 'running',
      'nodeId': 'sub_1',
      'nodeType': 'subWorkflow',
      'label': 'Login Subflow',
      'loopIndex': 0,
      'inputCount': 2,
      'inputNames': ['loopNumber', 'hasShot'],
    });
    await store.finishRun(
      runId,
      status: 'failed',
      completedLoops: 0,
      finishedAt: DateTime.utc(2026, 1, 2, 3, 4, 8),
    );

    final detail = await store.readDetail(runId);
    final screenshotFile = File('${root.path}/$runId/$screenshotPath');
    final screenshotExists = await screenshotFile.exists();
    final screenshotBytes = await screenshotFile.readAsBytes();
    final loadedScreenshotBytes = await store.readScreenshot(
      runId,
      screenshotPath!,
    );
    final rejectedParentPath = await store.readScreenshot(
      runId,
      '../metadata.json',
    );
    final rejectedWrongDirectory = await store.readScreenshot(
      runId,
      'metadata.json',
    );
    await root.delete(recursive: true);

    expect(detail, isNotNull);
    expect(detail!.entry.workflowName, 'Failing Workflow');
    expect(detail.entry.status, 'failed');
    expect(detail.nodeEvents, hasLength(3));
    expect(detail.nodeTraces, hasLength(2));
    expect(detail.failureAnalysis.category, 'Low Confidence');
    expect(detail.failureAnalysis.failedNodeId, 'condition_1');
    expect(detail.failureAnalysis.failedNodeLabel, 'Check Ready');
    expect(detail.failureAnalysis.failedNodeType, 'condition');
    expect(detail.failureAnalysis.failedLoopIndex, 0);
    expect(detail.failureAnalysis.failedDuration, const Duration(seconds: 1));
    expect(detail.failureAnalysis.screenshotEvidenceCount, 1);
    expect(detail.metrics.totalSteps, 2);
    expect(detail.metrics.completedSteps, 1);
    expect(detail.metrics.failedSteps, 1);
    expect(detail.metrics.pausedSteps, 0);
    expect(detail.metrics.runningSteps, 0);
    expect(detail.metrics.issueSteps, 1);
    expect(detail.metrics.screenshotEvidenceCount, 1);
    expect(detail.metrics.slowestNodeId, 'condition_1');
    expect(detail.metrics.slowestNodeLabel, 'Check Ready');
    expect(detail.metrics.slowestNodeType, 'condition');
    expect(detail.metrics.slowestDuration, const Duration(seconds: 1));
    final subWorkflowEvent = detail.events.firstWhere(
      (event) => event.type == 'subWorkflowStart',
    );
    expect(subWorkflowEvent.hasInputSummary, isTrue);
    expect(subWorkflowEvent.inputCount, 2);
    expect(subWorkflowEvent.inputNames, ['loopNumber', 'hasShot']);
    expect(detail.screenshotEvidenceRefs, hasLength(1));
    expect(detail.screenshotEvidenceRefs.single.nodeId, 'snapshot_1');
    expect(detail.screenshotEvidenceRefs.single.nodeType, 'snapshot');
    expect(detail.screenshotEvidenceRefs.single.label, 'Screenshot Evidence');
    expect(detail.screenshotEvidenceRefs.single.loopIndex, 0);
    expect(detail.screenshotEvidenceRefs.single.status, 'ok');
    expect(
      detail.screenshotEvidenceRefs.single.relativePath,
      'screenshots/snapshot_1-loop-1.png',
    );
    final conditionTrace = detail.nodeTraces.firstWhere(
      (trace) => trace.nodeId == 'condition_1',
    );
    expect(conditionTrace.status, 'failed');
    expect(conditionTrace.duration, const Duration(seconds: 1));
    final snapshotTrace = detail.nodeTraces.firstWhere(
      (trace) => trace.nodeId == 'snapshot_1',
    );
    expect(snapshotTrace.screenshotPath, 'screenshots/snapshot_1-loop-1.png');
    expect(screenshotExists, isTrue);
    expect(screenshotBytes, [1, 2, 3, 4]);
    expect(loadedScreenshotBytes, [1, 2, 3, 4]);
    expect(rejectedParentPath, isNull);
    expect(rejectedWrongDirectory, isNull);
    expect(detail.failedNodeId, 'condition_1');
    expect(detail.failureReason, 'Condition confidence was too low.');
    expect(detail.duration, const Duration(seconds: 3));
  });
  // 验证暂停运行详情能定位暂停节点并生成友好原因。
  test('local evidence store reads paused run detail', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);

    final runId = await store.startRun(
      workflowName: 'Paused Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 6).toIso8601String(),
      'type': 'stepStart',
      'nodeId': 'visual_1',
      'nodeType': 'visualBranch',
      'label': 'Check Screen',
      'loopIndex': 0,
    });
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 7).toIso8601String(),
      'type': 'stepEnd',
      'status': 'paused',
      'nodeId': 'visual_1',
      'nodeType': 'visualBranch',
      'label': 'Check Screen',
      'loopIndex': 0,
    });
    await store.finishRun(
      runId,
      status: 'paused',
      completedLoops: 0,
      finishedAt: DateTime.utc(2026, 1, 2, 3, 4, 8),
    );

    final detail = await store.readDetail(runId);
    await root.delete(recursive: true);

    expect(detail, isNotNull);
    expect(detail!.entry.status, 'paused');
    expect(detail.pausedNodeId, 'visual_1');
    expect(detail.failedNodeId, isNull);
    expect(detail.failureReason, 'Execution paused for manual intervention.');
    expect(detail.failureAnalysis.category, 'Paused');
    expect(detail.failureAnalysis.failedNodeId, 'visual_1');
    expect(detail.failureAnalysis.failedNodeLabel, 'Check Screen');
    expect(detail.failureAnalysis.failedNodeType, 'visualBranch');
    expect(detail.failureAnalysis.failedDuration, const Duration(seconds: 1));
  });

  // 验证本地报告聚合 Airtest 风格复盘所需的核心字段。
  test('local evidence store reads local run report summary', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);

    final runId = await store.startRun(
      workflowName: 'Visual Workflow',
      loops: 2,
      startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 6).toIso8601String(),
      'type': 'stepStart',
      'nodeId': 'visual_1',
      'nodeType': 'visualBranch',
      'label': '检查弹窗',
      'loopIndex': 0,
    });
    final screenshotPath = await store.recordScreenshot(
      runId,
      fileName: 'visual_1-loop-1.png',
      base64Png: base64Encode([9, 8, 7, 6]),
    );
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 8).toIso8601String(),
      'type': 'stepEnd',
      'status': 'paused',
      'nodeId': 'visual_1',
      'nodeType': 'visualBranch',
      'label': '检查弹窗',
      'loopIndex': 0,
      'screenshotPath': screenshotPath,
      'visualRule': '目标出现',
      'screenshotAvailable': true,
      'confidence': 0.41,
      'confidenceThreshold': 0.8,
      'result': false,
      'visualAction': 'pause',
      'visualReason': '置信度不足',
      'selectedNext': 'pause',
    });
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 2, 3, 4, 9).toIso8601String(),
      'type': 'subWorkflowStart',
      'status': 'running',
      'nodeId': 'sub_1',
      'nodeType': 'subWorkflow',
      'label': '子流程',
      'inputCount': 1,
      'inputNames': ['safeFlag'],
    });
    await store.finishRun(
      runId,
      status: 'paused',
      completedLoops: 1,
      finishedAt: DateTime.utc(2026, 1, 2, 3, 4, 10),
    );

    final report = await store.readReport(runId);
    final controller = StudioRuntimeController(evidenceStore: store);
    final controllerReport = await controller.readRunReport(runId);
    await controller.dispose();
    await root.delete(recursive: true);

    expect(report, isNotNull);
    expect(controllerReport, isNotNull);
    expect(report!.overview.workflowName, 'Visual Workflow');
    expect(report.overview.status, 'paused');
    expect(report.overview.loops, 2);
    expect(report.overview.completedLoops, 1);
    expect(report.overview.duration, const Duration(seconds: 5));
    expect(report.overview.totalSteps, 1);
    expect(report.overview.pausedSteps, 1);
    expect(report.overview.visualCheckCount, 1);
    expect(report.overview.screenshotCount, 1);
    expect(report.issue.category, 'Paused');
    expect(report.issue.nodeId, 'visual_1');
    expect(report.issue.duration, const Duration(seconds: 2));
    expect(report.timeline, hasLength(1));
    expect(report.timeline.single.status, 'paused');
    expect(report.timeline.single.screenshotPath, screenshotPath);
    expect(report.visualChecks, hasLength(1));
    expect(report.visualChecks.single.rule, '目标出现');
    expect(report.visualChecks.single.confidence, 0.41);
    expect(report.visualChecks.single.confidenceThreshold, 0.8);
    expect(report.visualChecks.single.reason, '置信度不足');
    expect(report.screenshots, hasLength(1));
    expect(report.screenshots.single.relativePath, screenshotPath);
    expect(report.logSummary.totalEvents, 3);
    expect(report.logSummary.visualEvents, 1);
    expect(report.logSummary.screenshotEvents, 1);
    expect(report.logSummary.inputSummaryEvents, 1);

    final json = report.toJson();
    expect(json['overview'], isA<Map<String, Object?>>());
    expect(json.toString(), isNot(contains(root.path)));
  });

  // 验证报告导出数据会过滤路径、设备号和长 session。
  test('local run report sanitizes paths device ids and unsafe screenshots', () {
    const secretDevice = '11112222-3333444455556666';
    const secretSession = '0123456789abcdef0123456789abcdef';
    final detail = RunDetail(
      entry: RunHistoryEntry(
        runId: 'run-20260102T030405Z',
        workflowName: 'Report /Users/example/private',
        status: 'failed',
        loops: 1,
        completedLoops: 0,
        startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
        finishedAt: DateTime.utc(2026, 1, 2, 3, 4, 8),
      ),
      events: <RunEvidenceEvent>[
        RunEvidenceEvent(
          type: 'stepStart',
          status: null,
          nodeId: 'tap_1',
          nodeType: 'tap',
          label: 'Tap /Users/example/secret',
          loopIndex: 0,
          error: null,
          screenshotPath: null,
          at: DateTime.utc(2026, 1, 2, 3, 4, 6),
        ),
        RunEvidenceEvent(
          type: 'stepEnd',
          status: 'failed',
          nodeId: 'tap_1',
          nodeType: 'tap',
          label: 'Tap /Users/example/secret',
          loopIndex: 0,
          error:
              'Driver failed at /Users/example/app for $secretDevice session $secretSession',
          screenshotPath: '/Users/example/private.png',
          at: DateTime.utc(2026, 1, 2, 3, 4, 7),
          visualEvidence: const RunVisualEvidence(
            rule: 'file://local/private-source.xml',
            screenshotAvailable: true,
            confidence: 0.2,
            confidenceThreshold: 0.8,
            result: false,
            action: 'pause',
            reason: 'See /Users/example/debug.log',
            selectedNext: 'manual',
          ),
        ),
      ],
    );

    final report = detail.report;
    final exported = jsonEncode(report.toJson());

    expect(report.screenshots, isEmpty);
    expect(report.timeline.single.screenshotPath, isNull);
    expect(report.issue.reason, contains('[path]'));
    expect(report.issue.reason, contains('[device]'));
    expect(report.issue.reason, contains('[id]'));
    expect(exported, isNot(contains('/Users')));
    expect(exported, isNot(contains('file://')));
    expect(exported, isNot(contains(secretDevice)));
    expect(exported, isNot(contains(secretSession)));
  });

  // 验证本地报告可以导出为脱敏 JSON 文件，并由 Controller 统一入口调用。
  test('local evidence store exports sanitized report json file', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);

    final runId = await store.startRun(
      workflowName: '导出流程 /Users/private/project',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 4, 3, 4, 5),
    );
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 4, 3, 4, 5).toIso8601String(),
      'type': 'smokeStart',
      'platform': 'android',
      'actionsAllowed': true,
    });
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 4, 3, 4, 5).toIso8601String(),
      'type': 'smokeSession',
      'platform': 'android',
      'device': {
        'platform': 'android',
        'name': 'Pixel 9',
        'id': 'ZY22...CDEF',
        'version': '15',
        'connection': 'usb',
      },
    });
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 4, 3, 4, 6).toIso8601String(),
      'type': 'smokeLogs',
      'platform': 'android',
      'count': 2,
      'lines': ['W/App: device ZY22ABCDEF wrote /Users/local/file'],
    });
    await store.recordEvent(runId, {
      'at': DateTime.utc(2026, 1, 4, 3, 4, 6).toIso8601String(),
      'type': 'stepEnd',
      'status': 'failed',
      'nodeId': 'tap_1',
      'nodeType': 'tap',
      'label': '点击 /Users/private/button',
      'loopIndex': 0,
      'error':
          'driver http://127.0.0.1:4723/session failed on 11112222-3333444455556666',
    });
    await store.finishRun(
      runId,
      status: 'failed',
      completedLoops: 0,
      finishedAt: DateTime.utc(2026, 1, 4, 3, 4, 8),
    );

    final exported = await store.exportReport(runId);
    final controller = StudioRuntimeController(evidenceStore: store);
    final controllerExport = await controller.exportRunReport(runId);
    await controller.dispose();
    final exportedFile = File('${root.path}/$runId/${exported!.relativePath}');
    final exportedText = await exportedFile.readAsString();
    final decoded = jsonDecode(exportedText) as Map<String, Object?>;
    final overview = decoded['overview'] as Map<String, Object?>;
    final issue = decoded['issue'] as Map<String, Object?>;
    final platform = decoded['platform'] as Map<String, Object?>;
    final unsafeExport = await store.exportReport('../metadata');
    await root.delete(recursive: true);

    expect(exported, isNotNull);
    expect(exported.fileName, '$runId-report.json');
    expect(exported.relativePath, 'exports/$runId-report.json');
    expect(controllerExport, isNotNull);
    expect(controllerExport!.relativePath, 'exports/$runId-report.json');
    expect(unsafeExport, isNull);
    expect(overview['workflowName'], '导出流程 [path]');
    expect(issue['reason'], contains('[local-driver]'));
    expect(issue['reason'], contains('[device]'));
    expect(platform['platform'], 'android');
    expect(platform['deviceName'], 'Pixel 9');
    expect(platform['maskedDeviceId'], 'ZY22...CDEF');
    expect(platform['osVersion'], '15');
    expect(platform['connectionKind'], 'usb');
    expect(platform['actionsAllowed'], isTrue);
    expect(platform['logCount'], 2);
    expect(platform['hint'], contains('Android'));
    expect(exportedText, isNot(contains(root.path)));
    expect(exportedText, isNot(contains('/Users')));
    expect(exportedText, isNot(contains('127.0.0.1')));
    expect(exportedText, isNot(contains('11112222-3333444455556666')));
  });
}
