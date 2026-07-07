import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

// 本地证据节点耗时聚合测试。
// 用例覆盖慢节点统计和趋势点生成。
void main() {
  // 验证节点耗时按节点聚合，并保留相关运行样本。
  test('local evidence store aggregates node duration stats', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);

    final firstRunId = await store.startRun(
      workflowName: '耗时流程',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 7, 1),
    );
    await store.recordEvent(firstRunId, {
      'type': 'stepStart',
      'nodeId': 'slow_1',
      'nodeType': 'visualBranch',
      'label': '视觉判断',
      'at': DateTime.utc(2026, 1, 7, 1, 0, 0).toIso8601String(),
    });
    await store.recordEvent(firstRunId, {
      'type': 'stepEnd',
      'nodeId': 'slow_1',
      'nodeType': 'visualBranch',
      'label': '视觉判断',
      'status': 'completed',
      'at': DateTime.utc(2026, 1, 7, 1, 0, 3).toIso8601String(),
    });
    await store.recordEvent(firstRunId, {
      'type': 'stepStart',
      'nodeId': 'fast_1',
      'nodeType': 'tap',
      'label': '点击',
      'at': DateTime.utc(2026, 1, 7, 1, 0, 4).toIso8601String(),
    });
    await store.recordEvent(firstRunId, {
      'type': 'stepEnd',
      'nodeId': 'fast_1',
      'nodeType': 'tap',
      'label': '点击',
      'status': 'completed',
      'at': DateTime.utc(2026, 1, 7, 1, 0, 5).toIso8601String(),
    });
    await store.finishRun(
      firstRunId,
      status: 'completed',
      completedLoops: 1,
      finishedAt: DateTime.utc(2026, 1, 7, 1, 0, 6),
    );

    final secondRunId = await store.startRun(
      workflowName: '耗时流程',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 7, 2),
    );
    await store.recordEvent(secondRunId, {
      'type': 'stepStart',
      'nodeId': 'slow_1',
      'nodeType': 'visualBranch',
      'label': '视觉判断',
      'at': DateTime.utc(2026, 1, 7, 2, 0, 0).toIso8601String(),
    });
    await store.recordEvent(secondRunId, {
      'type': 'stepEnd',
      'nodeId': 'slow_1',
      'nodeType': 'visualBranch',
      'label': '视觉判断',
      'status': 'paused',
      'error': 'low confidence',
      'at': DateTime.utc(2026, 1, 7, 2, 0, 5).toIso8601String(),
    });
    await store.finishRun(
      secondRunId,
      status: 'paused',
      completedLoops: 0,
      finishedAt: DateTime.utc(2026, 1, 7, 2, 0, 6),
    );

    final summary = await store.readSummary();
    await root.delete(recursive: true);

    expect(summary.nodeDurationStats, hasLength(2));
    final slow = summary.nodeDurationStats.first;
    expect(slow.nodeId, 'slow_1');
    expect(slow.nodeType, 'visualBranch');
    expect(slow.label, '视觉判断');
    expect(slow.sampleCount, 2);
    expect(slow.issueCount, 1);
    expect(slow.averageDuration, const Duration(seconds: 4));
    expect(slow.maxDuration, const Duration(seconds: 5));
    expect(slow.relatedRuns, hasLength(2));
    expect(slow.relatedRuns.first.runId, secondRunId);
    expect(slow.relatedRuns.first.duration, const Duration(seconds: 5));
    expect(slow.relatedRuns.last.runId, firstRunId);
    expect(slow.relatedRuns.last.duration, const Duration(seconds: 3));
    expect(summary.nodeDurationStats.last.nodeId, 'fast_1');
  });
  // 验证节点耗时趋势按日期生成固定窗口点。
  test('local evidence store aggregates node duration trends', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);

    // 写入一条带节点耗时的运行，供趋势统计复用。
    Future<void> writeRun({
      required DateTime startedAt,
      required Duration duration,
      required String status,
    }) async {
      final runId = await store.startRun(
        workflowName: '趋势流程',
        loops: 1,
        startedAt: startedAt,
      );
      await store.recordEvent(runId, {
        'type': 'stepStart',
        'nodeId': 'visual_1',
        'nodeType': 'visualBranch',
        'label': '视觉判断',
        'at': startedAt.toIso8601String(),
      });
      await store.recordEvent(runId, {
        'type': 'stepEnd',
        'nodeId': 'visual_1',
        'nodeType': 'visualBranch',
        'label': '视觉判断',
        'status': status,
        'error': status == 'paused' ? 'low confidence' : null,
        'at': startedAt.add(duration).toIso8601String(),
      });
      await store.finishRun(
        runId,
        status: status == 'paused' ? 'paused' : 'completed',
        completedLoops: status == 'paused' ? 0 : 1,
        finishedAt: startedAt.add(duration).add(const Duration(seconds: 1)),
      );
    }

    await writeRun(
      startedAt: DateTime.utc(2026, 1, 6, 1),
      duration: const Duration(seconds: 2),
      status: 'completed',
    );
    await writeRun(
      startedAt: DateTime.utc(2026, 1, 7, 1),
      duration: const Duration(seconds: 6),
      status: 'paused',
    );

    final summary = await store.readSummary();
    await root.delete(recursive: true);

    expect(summary.nodeDurationTrends, hasLength(1));
    final trend = summary.nodeDurationTrends.single;
    expect(trend.nodeId, 'visual_1');
    expect(trend.label, '视觉判断');
    expect(trend.sampleCount, 2);
    expect(trend.issueCount, 1);
    expect(trend.averageDuration, const Duration(seconds: 4));
    expect(trend.maxDuration, const Duration(seconds: 6));
    expect(trend.relatedRuns, hasLength(2));
    expect(trend.relatedRuns.first.duration, const Duration(seconds: 6));
    expect(trend.relatedRuns.first.status, 'paused');
    expect(trend.points, hasLength(7));
    expect(trend.points[5].day, DateTime.utc(2026, 1, 6));
    expect(trend.points[5].averageDuration, const Duration(seconds: 2));
    expect(trend.points[6].day, DateTime.utc(2026, 1, 7));
    expect(trend.points[6].averageDuration, const Duration(seconds: 6));
    expect(trend.points[6].issueCount, 1);
  });
}
