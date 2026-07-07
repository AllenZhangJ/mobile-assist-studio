// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime workflow 项目命令和本地 workflow store 测试。
// 用例保护 Project DSL 保存、复制、重置和运行中写入边界。
void main() {
  // 验证空闲时可更新当前 workflow，并刷新运行时快照。
  test('runtime controller updates workflow while idle', () async {
    final controller = StudioRuntimeController();
    final workflow = WorkflowDefinition(
      id: 'recorded',
      name: 'Recorded Session',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['tap_1'],
        ),
        WorkflowNode(
          id: 'tap_1',
          type: WorkflowNodeType.tap,
          label: 'Tap Login',
          next: ['end'],
          parameters: {'label': 'Tap Login', 'x': 92, 'y': 499},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final updated = await controller.updateWorkflow(workflow);
    await controller.dispose();

    expect(updated, isTrue);
    expect(controller.snapshot.workflow.name, 'Recorded Session');
    expect(controller.snapshot.workflowIsValid, isTrue);
    expect(controller.snapshot.events.last.message, contains('流程已更新'));
  });

  // 验证收藏、复制和重置当前 workflow 会同步本地存储。
  test('runtime controller manages current workflow project actions', () async {
    final directory = await Directory.systemTemp.createTemp(
      'workflow-actions-',
    );
    final workflowStore = LocalWorkflowStore(
      file: File('${directory.path}/workflows/current.workflow.json'),
    );
    final settingsStore = LocalStudioSettingsStore(
      file: File('${directory.path}/settings/studio.settings.json'),
    );
    final controller = StudioRuntimeController(
      workflowStore: workflowStore,
      settingsStore: settingsStore,
    );

    final favoriteSaved = await controller.toggleCurrentWorkflowFavorite();
    final duplicateSaved = await controller.duplicateCurrentWorkflow();
    final copiedWorkflow = controller.snapshot.workflow;
    final deleteSaved = await controller.resetCurrentWorkflowToTemplate();
    final restoredWorkflow = workflowStore.loadWorkflowSync();
    final restoredSettings = settingsStore.loadSettingsSync();
    await controller.dispose();
    await directory.delete(recursive: true);

    expect(favoriteSaved, isTrue);
    expect(duplicateSaved, isTrue);
    expect(copiedWorkflow.id, startsWith('af-template-copy-'));
    expect(copiedWorkflow.name, 'A-F 基础模板 副本');
    expect(deleteSaved, isTrue);
    expect(restoredWorkflow?.id, 'af-template');
    expect(controller.snapshot.workflow.name, 'A-F 基础模板');
    expect(restoredSettings.favoriteWorkflowIds, ['af-template']);
  });

  // 验证当前 workflow store 能完整保存和读取 Project DSL。
  test('local workflow store writes and reads project DSL', () async {
    final directory = await Directory.systemTemp.createTemp('workflow-store-');
    final file = File('${directory.path}/workflows/current.workflow.json');
    final store = LocalWorkflowStore(file: file);
    final workflow = WorkflowDefinition.afTemplate();

    await store.saveWorkflow(workflow);
    final restored = store.loadWorkflowSync();
    await directory.delete(recursive: true);

    expect(restored, isNotNull);
    expect(restored!.name, workflow.name);
    expect(restored.toJson(), workflow.toJson());
  });

  // 验证子流程 store 只持久化合法 Project DSL 列表。
  test(
    'local sub workflow store writes and reads valid project DSL list',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sub-workflow-store-',
      );
      final file = File('${directory.path}/workflows/sub.workflows.json');
      final store = LocalSubWorkflowStore(file: file);
      const child = WorkflowDefinition(
        id: 'child-flow',
        name: '子流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['wait'],
          ),
          WorkflowNode(
            id: 'wait',
            type: WorkflowNodeType.wait,
            label: '等待',
            next: ['end'],
            parameters: {'ms': 200},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );

      await store.saveSubWorkflows(const {'child-flow': child});
      final restored = store.loadSubWorkflowsSync();
      await directory.delete(recursive: true);

      expect(restored, hasLength(1));
      expect(restored['child-flow']?.toJson(), child.toJson());
    },
  );

  // 验证运行中不能改写 workflow，避免执行图漂移。
  test('runtime controller refuses workflow update while running', () async {
    final server = await sessionServer('workflow-update-session');
    final delayStarted = Completer<void>();
    final releaseDelay = Completer<void>();
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: FakeDeviceActionExecutor(),
      delay: (duration) async {
        if (!delayStarted.isCompleted) {
          delayStarted.complete();
        }
        await releaseDelay.future;
      },
    );

    await controller.connectDevice();
    final runFuture = controller.runCurrentWorkflow(loops: 1);
    await delayStarted.future;
    final updated = await controller.updateWorkflow(
      const WorkflowDefinition(
        id: 'blocked',
        name: 'Blocked Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(id: 'start', type: WorkflowNodeType.start, label: '开始'),
        ],
      ),
    );
    releaseDelay.complete();
    await runFuture;
    await controller.dispose();
    await server.close(force: true);

    expect(updated, isFalse);
    expect(controller.snapshot.workflow.name, isNot('Blocked Workflow'));
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('运行中不能修改流程。'),
    );
  });

  // 验证无效 workflow 更新会被拒绝并保留旧快照。
  test('runtime controller rejects invalid workflow update', () async {
    final controller = StudioRuntimeController();
    final originalName = controller.snapshot.workflow.name;

    final updated = await controller.updateWorkflow(
      const WorkflowDefinition(
        id: 'invalid',
        name: 'Invalid Workflow',
        entryNodesId: 'missing',
        nodes: [
          WorkflowNode(id: 'start', type: WorkflowNodeType.start, label: '开始'),
        ],
      ),
    );
    await controller.dispose();

    expect(updated, isFalse);
    expect(controller.snapshot.workflow.name, originalName);
    expect(controller.snapshot.workflowIsValid, isTrue);
    expect(controller.snapshot.events.last.message, contains('流程未保存'));
  });
}
