// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 子流程本地存储和项目命令测试。
// 用例覆盖注册、当前流程转子流程、删除和引用保护。
void main() {
  // 验证空闲时可注册子流程并写入本地 store。
  test('runtime controller registers sub workflow while idle', () async {
    final directory = await Directory.systemTemp.createTemp(
      'sub-workflow-register-',
    );
    final store = LocalSubWorkflowStore(
      file: File('${directory.path}/workflows/sub.workflows.json'),
    );
    final controller = StudioRuntimeController(subWorkflowStore: store);
    const workflow = WorkflowDefinition(
      id: 'local-child',
      name: '本地子流程',
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
          parameters: {'ms': 300},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final registered = await controller.registerSubWorkflow(workflow);
    final restored = store.loadSubWorkflowsSync();
    await controller.dispose();
    await directory.delete(recursive: true);

    expect(registered, isTrue);
    expect(controller.snapshot.subWorkflows, hasLength(1));
    final summary = controller.snapshot.subWorkflows.single;
    expect(summary.workflowId, 'local-child');
    expect(summary.name, '本地子流程');
    expect(summary.nodeCount, 3);
    expect(summary.isValid, isTrue);
    expect(restored['local-child']?.toJson(), workflow.toJson());
    expect(controller.snapshot.events.last.message, contains('子流程已添加：本地子流程'));
  });

  // 验证当前 workflow 可转存为子流程并重置主流程。
  test(
    'runtime controller registers current workflow as sub workflow',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sub-workflow-current-',
      );
      final store = LocalSubWorkflowStore(
        file: File('${directory.path}/workflows/sub.workflows.json'),
      );
      const workflow = WorkflowDefinition(
        id: 'current-main',
        name: '当前流程',
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
      final controller = StudioRuntimeController(
        workflow: workflow,
        subWorkflowStore: store,
      );

      final registered = await controller
          .registerCurrentWorkflowAsSubWorkflow();
      final summary = controller.snapshot.subWorkflows.single;
      final restored = store.loadSubWorkflowsSync();
      await controller.dispose();
      await directory.delete(recursive: true);

      expect(registered, isTrue);
      expect(summary.workflowId, startsWith('current-main-sub-'));
      expect(summary.name, '当前流程 子流程');
      expect(summary.nodeCount, 3);
      expect(restored[summary.workflowId]?.name, '当前流程 子流程');
      expect(controller.snapshot.workflow.id, 'current-main');
    },
  );

  // 验证未被引用的子流程可从本地 store 删除。
  test(
    'runtime controller deletes unused sub workflow from local store',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sub-workflow-delete-',
      );
      final store = LocalSubWorkflowStore(
        file: File('${directory.path}/workflows/sub.workflows.json'),
      );
      const workflow = WorkflowDefinition(
        id: 'unused-child',
        name: '可删子流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['end'],
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      final controller = StudioRuntimeController(
        subWorkflowStore: store,
        subWorkflows: const {'unused-child': workflow},
      );

      final deleted = await controller.deleteSubWorkflow('unused-child');
      final restored = store.loadSubWorkflowsSync();
      await controller.dispose();
      await directory.delete(recursive: true);

      expect(deleted, isTrue);
      expect(controller.snapshot.subWorkflows, isEmpty);
      expect(restored, isEmpty);
      expect(controller.snapshot.events.last.message, '子流程已删除。');
    },
  );

  // 验证被当前流程引用的子流程不能删除。
  test(
    'runtime controller refuses to delete referenced sub workflow',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'sub-workflow-delete-ref-',
      );
      final store = LocalSubWorkflowStore(
        file: File('${directory.path}/workflows/sub.workflows.json'),
      );
      const child = WorkflowDefinition(
        id: 'referenced-child',
        name: '被用子流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['end'],
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      const parent = WorkflowDefinition(
        id: 'parent-flow',
        name: '父流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['sub_1'],
          ),
          WorkflowNode(
            id: 'sub_1',
            type: WorkflowNodeType.subWorkflow,
            label: '子流程',
            next: ['end'],
            parameters: {'workflowId': 'referenced-child'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      final controller = StudioRuntimeController(
        workflow: parent,
        subWorkflowStore: store,
        subWorkflows: const {'referenced-child': child},
      );

      final deleted = await controller.deleteSubWorkflow('referenced-child');
      await controller.dispose();
      await directory.delete(recursive: true);

      expect(deleted, isFalse);
      expect(controller.snapshot.subWorkflows, hasLength(1));
      expect(controller.snapshot.events.last.message, '当前流程正在使用该子流程。');
    },
  );
}
