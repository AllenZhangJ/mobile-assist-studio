import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 控制流回归测试，聚焦条件、子流程入参和异常恢复。
// 用例验证 Project DSL 的安全控制语义，不执行任意脚本代码。
void main() {
  test('runtime executes safe condition true and false branches', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      workflow: const WorkflowDefinition(
        id: 'condition-workflow',
        name: '条件流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['condition_true'],
          ),
          WorkflowNode(
            id: 'condition_true',
            type: WorkflowNodeType.condition,
            label: '有循环',
            next: ['tap_true', 'tap_false'],
            parameters: {'expression': 'context.loopNumber'},
          ),
          WorkflowNode(
            id: 'tap_true',
            type: WorkflowNodeType.tap,
            label: '真分支',
            next: ['condition_false'],
            parameters: {'x': 10, 'y': 20, 'label': '真'},
          ),
          WorkflowNode(
            id: 'condition_false',
            type: WorkflowNodeType.condition,
            label: '缺少标记',
            next: ['tap_wrong', 'tap_false'],
            parameters: {'expression': 'context.missingFlag'},
          ),
          WorkflowNode(
            id: 'tap_wrong',
            type: WorkflowNodeType.tap,
            label: '错误分支',
            next: ['end'],
            parameters: {'x': 99, 'y': 99, 'label': '错误'},
          ),
          WorkflowNode(
            id: 'tap_false',
            type: WorkflowNodeType.tap,
            label: '假分支',
            next: ['end'],
            parameters: {'x': 30, 'y': 40, 'label': '假'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, [
      'tap:真:10,20:80',
      'release',
      'tap:假:30,40:80',
      'release',
    ]);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll([
        'condition_true',
        'tap_true',
        'condition_false',
        'tap_false',
      ]),
    );
    expect(
      controller.snapshot.events.map((event) => event.message),
      containsAll(['第 1/1 轮：条件 有循环 通过。', '第 1/1 轮：条件 缺少标记 未通过。']),
    );
  });

  test('runtime executes registered sub workflow serially', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      subWorkflows: const {
        'nested': WorkflowDefinition(
          id: 'nested',
          name: '子流程',
          entryNodesId: 'start',
          nodes: [
            WorkflowNode(
              id: 'start',
              type: WorkflowNodeType.start,
              label: '开始',
              next: ['tap_nested'],
            ),
            WorkflowNode(
              id: 'tap_nested',
              type: WorkflowNodeType.tap,
              label: '子流程点击',
              next: ['wait_nested'],
              parameters: {'x': 11, 'y': 22, 'label': '子流程'},
            ),
            WorkflowNode(
              id: 'wait_nested',
              type: WorkflowNodeType.wait,
              label: '子流程等待',
              next: ['end'],
              parameters: {'ms': 1},
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      },
      workflow: const WorkflowDefinition(
        id: 'parent',
        name: '主流程',
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
            label: '运行子流程',
            next: ['tap_parent'],
            parameters: {'workflowId': 'nested'},
          ),
          WorkflowNode(
            id: 'tap_parent',
            type: WorkflowNodeType.tap,
            label: '主流程点击',
            next: ['end'],
            parameters: {'x': 33, 'y': 44, 'label': '主流程'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, [
      'tap:子流程:11,22:80',
      'release',
      'tap:主流程:33,44:80',
      'release',
    ]);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll(['sub_1', 'tap_nested', 'wait_nested', 'tap_parent']),
    );
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('第 1/1 轮：运行子流程 子流程。'),
    );
  });

  test('runtime passes safe input map into sub workflow context', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      subWorkflows: const {
        'nested': WorkflowDefinition(
          id: 'nested',
          name: '带参子流程',
          entryNodesId: 'start',
          nodes: [
            WorkflowNode(
              id: 'start',
              type: WorkflowNodeType.start,
              label: '开始',
              next: ['condition_input'],
            ),
            WorkflowNode(
              id: 'condition_input',
              type: WorkflowNodeType.condition,
              label: '子流程条件',
              next: ['tap_nested', 'end'],
              parameters: {'expression': 'context.inputs.shouldTap'},
            ),
            WorkflowNode(
              id: 'tap_nested',
              type: WorkflowNodeType.tap,
              label: '子流程点击',
              next: ['end'],
              parameters: {'x': 11, 'y': 22, 'label': '子流程'},
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      },
      workflow: const WorkflowDefinition(
        id: 'parent-input-map',
        name: '主流程带参',
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
            label: '运行子流程',
            next: ['end'],
            parameters: {
              'workflowId': 'nested',
              'inputMap': {'shouldTap': 'context.loopNumber'},
            },
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, ['tap:子流程:11,22:80', 'release']);
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('第 1/1 轮：条件 子流程条件 通过。'),
    );
  });

  test('runtime catch retries and routes explicit onError branch', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor(failingTapLabels: {'失败'});
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      workflow: const WorkflowDefinition(
        id: 'catch-workflow',
        name: '异常流程',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['catch_1'],
          ),
          WorkflowNode(
            id: 'catch_1',
            type: WorkflowNodeType.catchNodes,
            label: '保护',
            next: ['sub_1'],
            parameters: {'maxRetries': 1, 'onError': 'recover_tap'},
          ),
          WorkflowNode(
            id: 'sub_1',
            type: WorkflowNodeType.tap,
            label: '失败',
            next: ['end'],
            parameters: {'x': 11, 'y': 22, 'label': '失败'},
          ),
          WorkflowNode(
            id: 'recover_tap',
            type: WorkflowNodeType.tap,
            label: '恢复',
            next: ['end'],
            parameters: {'x': 44, 'y': 55, 'label': '恢复'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(controller.snapshot.executionFocus.failedNodeId, isNull);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll(['catch_1', 'recover_tap']),
    );
    expect(deviceActions.calls, [
      'tap:失败:11,22:80',
      'release',
      'tap:失败:11,22:80',
      'release',
      'tap:恢复:44,55:80',
      'release',
    ]);
    expect(
      controller.snapshot.events.map((event) => event.message),
      containsAll([
        '第 1/1 轮：异常处理 保护 已启用。',
        '异常处理 保护：sub_1 失败后重试 1/1。',
        '异常处理 保护：sub_1 已转到 recover_tap。',
      ]),
    );
  });
}
