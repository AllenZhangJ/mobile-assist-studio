import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

// 本地证据摘要和失败聚类测试。
// 用例验证 Monitor 统计输入，不暴露设备标识或原始 WebDriver 数据。
void main() {
  // 验证暂停运行会进入摘要、趋势和问题分类。
  test('local evidence store summarizes paused runs', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final completedRunId = await store.startRun(
      workflowName: 'Completed Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 1),
    );
    await store.finishRun(
      completedRunId,
      status: 'completed',
      completedLoops: 1,
      finishedAt: DateTime.utc(2026, 1, 1, 0, 1),
    );
    final pausedRunId = await store.startRun(
      workflowName: 'Paused Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 2),
    );
    await store.recordEvent(pausedRunId, {
      'type': 'stepStart',
      'nodeId': 'visual_1',
      'nodeType': 'visualBranch',
      'label': 'Check Screen',
      'loopIndex': 0,
    });
    await store.recordEvent(pausedRunId, {
      'type': 'stepEnd',
      'status': 'paused',
      'nodeId': 'visual_1',
      'nodeType': 'visualBranch',
      'label': 'Check Screen',
      'loopIndex': 0,
    });
    await store.finishRun(
      pausedRunId,
      status: 'paused',
      completedLoops: 0,
      finishedAt: DateTime.utc(2026, 1, 2, 0, 1),
    );

    final summary = await store.readSummary();
    await root.delete(recursive: true);

    expect(summary.totalRuns, 2);
    expect(summary.completedRuns, 1);
    expect(summary.pausedRuns, 1);
    expect(summary.failedRuns, 0);
    expect(summary.stoppedRuns, 0);
    expect(summary.averageDuration, const Duration(minutes: 1));
    expect(summary.dailyRuns, hasLength(7));
    expect(summary.dailyRuns.last.day, DateTime.utc(2026, 1, 2));
    expect(summary.dailyRuns.last.totalRuns, 1);
    expect(summary.dailyRuns.last.pausedRuns, 1);
    expect(summary.dailyRuns30, hasLength(30));
    expect(summary.dailyRuns30.first.day, DateTime.utc(2025, 12, 4));
    expect(summary.dailyRuns30.last.day, DateTime.utc(2026, 1, 2));
    expect(summary.dailyRuns30[28].completedRuns, 1);
    expect(summary.dailyRuns90, hasLength(90));
    expect(summary.dailyRuns90.first.day, DateTime.utc(2025, 10, 5));
    expect(summary.dailyRuns90.last.issueRuns, 1);
    expect(summary.issueCategories, hasLength(1));
    expect(summary.issueCategories.single.category, 'Paused');
    expect(summary.issueCategories.single.count, 1);
    expect(summary.issueCategories.single.relatedRuns, hasLength(1));
    expect(
      summary.issueCategories.single.relatedRuns.single.workflowName,
      'Paused Workflow',
    );
    expect(summary.issueCategories.single.relatedRuns.single.status, 'paused');
    expect(summary.failureClusters, hasLength(1));
    expect(summary.failureClusters.single.category, 'Paused');
    expect(summary.failureClusters.single.nodeId, 'visual_1');
    expect(summary.failureClusters.single.count, 1);
    expect(summary.failureClusters.single.workflowCount, 1);
    expect(summary.failureClusters.single.relatedRuns, hasLength(1));
    expect(
      summary.failureClusters.single.relatedRuns.single.workflowName,
      'Paused Workflow',
    );
    expect(summary.dailyRuns.last.issueRuns, 1);
    expect(summary.recentRuns.first.status, 'paused');
  });
  // 验证相同失败原因会聚合为本地问题簇。
  test('local evidence store aggregates failure clusters', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);

    // 写入一条失败运行，供失败聚类统计复用。
    Future<void> writeFailedRun({
      required String workflowName,
      required DateTime startedAt,
      required String reason,
    }) async {
      final runId = await store.startRun(
        workflowName: workflowName,
        loops: 1,
        startedAt: startedAt,
      );
      await store.recordEvent(runId, {
        'type': 'stepStart',
        'nodeId': 'visual_1',
        'nodeType': 'visualBranch',
        'label': '查屏幕',
        'at': startedAt.add(const Duration(seconds: 1)).toIso8601String(),
      });
      await store.recordEvent(runId, {
        'type': 'stepEnd',
        'status': 'failed',
        'nodeId': 'visual_1',
        'nodeType': 'visualBranch',
        'label': '查屏幕',
        'error': reason,
        'at': startedAt.add(const Duration(seconds: 3)).toIso8601String(),
      });
      await store.finishRun(
        runId,
        status: 'failed',
        completedLoops: 0,
        finishedAt: startedAt.add(const Duration(seconds: 4)),
      );
    }

    await writeFailedRun(
      workflowName: '流程甲',
      startedAt: DateTime.utc(2026, 1, 7, 1),
      reason: 'low confidence from /Users/example/private.png',
    );
    await writeFailedRun(
      workflowName: '流程乙',
      startedAt: DateTime.utc(2026, 1, 7, 2),
      reason: 'low confidence latest screen',
    );

    final summary = await store.readSummary();
    await root.delete(recursive: true);

    expect(summary.failureClusters, hasLength(1));
    expect(summary.issueCategories, hasLength(1));
    expect(summary.issueCategories.single.category, 'Low Confidence');
    expect(summary.issueCategories.single.count, 2);
    expect(summary.issueCategories.single.relatedRuns, hasLength(2));
    expect(
      summary.issueCategories.single.relatedRuns.first.workflowName,
      '流程乙',
    );
    expect(summary.issueCategories.single.relatedRuns.last.workflowName, '流程甲');
    final cluster = summary.failureClusters.single;
    expect(cluster.category, 'Low Confidence');
    expect(cluster.nodeId, 'visual_1');
    expect(cluster.nodeType, 'visualBranch');
    expect(cluster.label, '查屏幕');
    expect(cluster.count, 2);
    expect(cluster.workflowCount, 2);
    expect(cluster.recentReason, 'low confidence latest screen');
    expect(cluster.recentAt, DateTime.utc(2026, 1, 7, 2));
    expect(cluster.relatedRuns, hasLength(2));
    expect(cluster.relatedRuns.first.workflowName, '流程乙');
    expect(cluster.relatedRuns.first.status, 'failed');
    expect(cluster.relatedRuns.last.workflowName, '流程甲');
  });
}
