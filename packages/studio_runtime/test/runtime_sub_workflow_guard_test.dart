// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 子流程控制器防护测试。
// 用例验证非法引用在保存、注册和执行前被拦截。
void main() {
  // 验证主流程更新会拒绝不存在的子流程引用。
  test(
    'runtime controller rejects workflow update with missing sub workflow reference',
    () async {
      final controller = StudioRuntimeController();
      const workflow = WorkflowDefinition(
        id: 'main-with-missing-child',
        name: '主流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['sub'],
          ),
          WorkflowNode(
            id: 'sub',
            type: WorkflowNodeType.subWorkflow,
            label: '子流程',
            next: ['end'],
            parameters: {'workflowId': 'missing-child'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );

      final updated = await controller.updateWorkflow(workflow);
      await controller.dispose();

      expect(updated, isFalse);
      expect(controller.snapshot.workflow.id, isNot('main-with-missing-child'));
      expect(controller.snapshot.events.last.message, contains('不存在的子流程'));
    },
  );

  // 验证注册子流程时会拒绝缺失的嵌套引用。
  test(
    'runtime controller rejects sub workflow registration with missing nested reference',
    () async {
      final controller = StudioRuntimeController();
      const workflow = WorkflowDefinition(
        id: 'child-with-missing-nested',
        name: '子流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['sub'],
          ),
          WorkflowNode(
            id: 'sub',
            type: WorkflowNodeType.subWorkflow,
            label: '嵌套子流程',
            next: ['end'],
            parameters: {'workflowId': 'missing-nested'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );

      final registered = await controller.registerSubWorkflow(workflow);
      await controller.dispose();

      expect(registered, isFalse);
      expect(controller.snapshot.subWorkflows, isEmpty);
      expect(controller.snapshot.events.last.message, contains('不存在的子流程'));
    },
  );

  // 验证执行前会拦截子流程链缺失，避免启动设备动作。
  test(
    'runtime controller rejects run when nested sub workflow reference is missing',
    () async {
      const childA = WorkflowDefinition(
        id: 'child-a',
        name: '子流程 A',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['sub'],
          ),
          WorkflowNode(
            id: 'sub',
            type: WorkflowNodeType.subWorkflow,
            label: '缺失嵌套',
            next: ['end'],
            parameters: {'workflowId': 'missing-nested'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      const workflow = WorkflowDefinition(
        id: 'main-with-broken-child',
        name: '主流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['sub'],
          ),
          WorkflowNode(
            id: 'sub',
            type: WorkflowNodeType.subWorkflow,
            label: '运行 A',
            next: ['end'],
            parameters: {'workflowId': 'child-a'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor();
      final controller = StudioRuntimeController(
        workflow: workflow,
        subWorkflows: const {'child-a': childA},
        sessionManager: fakeSessionManager(server),
        deviceActions: deviceActions,
      );
      await controller.connectDevice();

      final result = await controller.runCurrentWorkflow(loops: 1);
      await controller.dispose();
      await server.close(force: true);

      expect(result, isNull);
      expect(
        deviceActions.calls.where((call) => call.startsWith('tap:')),
        isEmpty,
      );
      expect(
        controller.snapshot.events.map((event) => event.message),
        contains(contains('子流程链缺少：missing-nested')),
      );
    },
  );

  // 验证控制器拒绝注册自引用子流程。
  test('runtime controller rejects self-referencing sub workflow', () async {
    final controller = StudioRuntimeController();
    const workflow = WorkflowDefinition(
      id: 'self-child',
      name: '自引用',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['sub'],
        ),
        WorkflowNode(
          id: 'sub',
          type: WorkflowNodeType.subWorkflow,
          label: '自己',
          next: ['end'],
          parameters: {'workflowId': 'self-child'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final registered = await controller.registerSubWorkflow(workflow);
    await controller.dispose();

    expect(registered, isFalse);
    expect(controller.snapshot.subWorkflows, isEmpty);
    expect(controller.snapshot.events.last.message, contains('不能引用自己'));
  });

  // 验证控制器拒绝形成循环引用的子流程。
  test(
    'runtime controller rejects recursive sub workflow registration',
    () async {
      const childAOriginal = WorkflowDefinition(
        id: 'child-a',
        name: '子流程 A',
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
      const childB = WorkflowDefinition(
        id: 'child-b',
        name: '子流程 B',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['sub'],
          ),
          WorkflowNode(
            id: 'sub',
            type: WorkflowNodeType.subWorkflow,
            label: '回 A',
            next: ['end'],
            parameters: {'workflowId': 'child-a'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      const childARecursive = WorkflowDefinition(
        id: 'child-a',
        name: '子流程 A',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['sub'],
          ),
          WorkflowNode(
            id: 'sub',
            type: WorkflowNodeType.subWorkflow,
            label: '去 B',
            next: ['end'],
            parameters: {'workflowId': 'child-b'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      final controller = StudioRuntimeController(
        subWorkflows: const {'child-a': childAOriginal, 'child-b': childB},
      );

      final registered = await controller.registerSubWorkflow(childARecursive);
      await controller.dispose();

      expect(registered, isFalse);
      expect(controller.snapshot.events.last.message, contains('循环引用'));
      expect(
        controller.snapshot.subWorkflows
            .firstWhere((summary) => summary.workflowId == 'child-a')
            .referencedWorkflowIds,
        isEmpty,
      );
    },
  );
}
