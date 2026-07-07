import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

// 本地证据保留和运行历史刷新测试。
// 用例只读写临时目录，不连接 Appium、不启动设备会话。
void main() {
  // 验证证据存储只保留最近运行，旧目录会被滚动清理。
  test('local evidence store keeps only the newest runs', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root, maxRuns: 2);

    await store.startRun(
      workflowName: 'Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.startRun(
      workflowName: 'Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 2),
    );
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await store.startRun(
      workflowName: 'Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 3),
    );

    final runDirectories = await root
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    expect(runDirectories, hasLength(2));
    expect(
      runDirectories.map((directory) => directory.path),
      everyElement(isNot(contains('2026-01-01'))),
    );

    await root.delete(recursive: true);
  });

  // 验证只读取历史时也会应用保留策略，避免重启后旧证据继续出现在 Monitor。
  test(
    'local evidence store applies retention before reading summary',
    () async {
      final root = await Directory.systemTemp.createTemp('studio-evidence-');
      final store = LocalRunEvidenceStore(rootDirectory: root, maxRuns: 3);

      await store.startRun(
        workflowName: 'Run 1',
        loops: 1,
        startedAt: DateTime.utc(2026, 1, 1),
      );
      await store.startRun(
        workflowName: 'Run 2',
        loops: 1,
        startedAt: DateTime.utc(2026, 1, 2),
      );
      await store.startRun(
        workflowName: 'Run 3',
        loops: 1,
        startedAt: DateTime.utc(2026, 1, 3),
      );
      final restored = LocalRunEvidenceStore(rootDirectory: root, maxRuns: 2);

      final summary = await restored.readSummary(limit: 10);
      final runDirectories = await root
          .list()
          .where((entity) => entity is Directory)
          .cast<Directory>()
          .toList();

      expect(summary.totalRuns, 2);
      expect(runDirectories, hasLength(2));
      expect(
        summary.recentRuns.map((entry) => entry.runId),
        isNot(contains('run-2026-01-01T00-00-00-000Z')),
      );

      await root.delete(recursive: true);
    },
  );

  // 验证 Runtime 可从证据读取器刷新本地运行历史。
  test('runtime refreshes run history from evidence reader', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final runId = await store.startRun(
      workflowName: 'Workflow',
      loops: 1,
      startedAt: DateTime.utc(2026, 1, 2),
    );
    await store.finishRun(
      runId,
      status: 'completed',
      completedLoops: 1,
      finishedAt: DateTime.utc(2026, 1, 2, 0, 1),
    );
    final controller = StudioRuntimeController(runHistoryReader: store);

    await controller.refreshRunHistory();
    await controller.dispose();

    expect(controller.snapshot.runHistory.totalRuns, 1);
    expect(controller.snapshot.runHistory.completedRuns, 1);
    expect(
      controller.snapshot.runHistory.recentRuns.single.status,
      'completed',
    );

    await root.delete(recursive: true);
  });
}
