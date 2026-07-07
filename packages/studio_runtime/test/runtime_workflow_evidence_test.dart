import 'dart:convert';
import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 证据写入回归测试，聚焦运行元数据、事件流和截图文件。
// 用例只写入系统临时目录，完成后立即清理本地证据。
void main() {
  test(
    'local evidence store writes run metadata, events and finish file',
    () async {
      final root = await Directory.systemTemp.createTemp('studio-evidence-');
      final store = LocalRunEvidenceStore(rootDirectory: root);

      final runId = await store.startRun(
        workflowName: 'Workflow',
        loops: 2,
        startedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      await store.recordEvent(runId, {'type': 'stepStart', 'nodeId': 'tap_a'});
      await store.finishRun(
        runId,
        status: 'completed',
        completedLoops: 2,
        finishedAt: DateTime.utc(2026, 1, 2, 3, 5),
      );

      final runDirectory = Directory('${root.path}/$runId');
      final metadata =
          jsonDecode(
                await File('${runDirectory.path}/metadata.json').readAsString(),
              )
              as Map<String, Object?>;
      final events = await File(
        '${runDirectory.path}/events.jsonl',
      ).readAsLines();
      final finished =
          jsonDecode(
                await File('${runDirectory.path}/finished.json').readAsString(),
              )
              as Map<String, Object?>;

      expect(metadata['workflowName'], 'Workflow');
      expect(metadata['loops'], 2);
      expect(events, hasLength(1));
      expect(jsonDecode(events.single), containsPair('nodeId', 'tap_a'));
      expect(finished['status'], 'completed');
      expect(finished['completedLoops'], 2);
      final summary = await store.readSummary();
      expect(summary.totalRuns, 1);
      expect(summary.completedRuns, 1);
      expect(summary.pausedRuns, 0);
      expect(summary.successRate, 1);
      expect(summary.dailyRuns, hasLength(7));
      expect(summary.dailyRuns.last.day, DateTime.utc(2026, 1, 2));
      expect(summary.dailyRuns.last.totalRuns, 1);
      expect(summary.dailyRuns.last.completedRuns, 1);
      expect(summary.dailyRuns.last.issueRuns, 0);
      expect(summary.recentRuns.single.workflowName, 'Workflow');

      await root.delete(recursive: true);
    },
  );

  test('runtime writes evidence for workflow execution', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final server = await sessionServer('runtime-session');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: FakeDeviceActionExecutor(),
      evidenceStore: store,
      runHistoryReader: store,
      delay: (_) async {},
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    final runDirectories = await root
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    final runDirectory = runDirectories.single;
    final eventLines = await File(
      '${runDirectory.path}/events.jsonl',
    ).readAsLines();
    final eventTypes = eventLines
        .map((line) => jsonDecode(line) as Map<String, Object?>)
        .map((event) => event['type'])
        .toList();
    final finished =
        jsonDecode(
              await File('${runDirectory.path}/finished.json').readAsString(),
            )
            as Map<String, Object?>;

    expect(result?.completedLoops, 1);
    expect(eventTypes.first, 'runStart');
    expect(eventTypes, contains('stepStart'));
    expect(eventTypes, contains('stepEnd'));
    expect(eventTypes.last, 'runEnd');
    expect(finished['status'], 'completed');
    expect(controller.snapshot.runHistory.totalRuns, 1);
    expect(controller.snapshot.runHistory.completedRuns, 1);

    await root.delete(recursive: true);
  });

  test('runtime writes screenshot evidence for snapshot node', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final server = await sessionServer('runtime-session');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: FakeDeviceActionExecutor(
        screenshotBase64: base64Encode([9, 8, 7]),
      ),
      evidenceStore: store,
      runHistoryReader: store,
      runDetailReader: store,
      workflow: const WorkflowDefinition(
        id: 'snapshot-workflow',
        name: 'Screenshot Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['snapshot_1'],
          ),
          WorkflowNode(
            id: 'snapshot_1',
            type: WorkflowNodeType.snapshot,
            label: 'Screenshot Evidence',
            next: ['end'],
            parameters: {'saveEvidence': true},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
      delay: (_) async {},
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    final runId = controller.snapshot.runHistory.recentRuns.single.runId;
    final detail = await store.readDetail(runId);
    final snapshotTrace = detail!.nodeTraces.single;
    final screenshotPath = snapshotTrace.screenshotPath;
    final screenshotFile = File('${root.path}/$runId/$screenshotPath');
    final screenshotBytes = await screenshotFile.readAsBytes();
    await root.delete(recursive: true);

    expect(result?.completedLoops, 1);
    expect(snapshotTrace.nodeId, 'snapshot_1');
    expect(screenshotPath, 'screenshots/snapshot_1-loop-1.png');
    expect(screenshotBytes, [9, 8, 7]);
  });
}
