import 'dart:async';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 基础执行回归测试，聚焦串行点击、循环、焦点和安全停止。
// 视觉、控制流和证据写入分别放在独立测试文件，便于快速定位失败。
void main() {
  test('runtime controller rejects run above the safe loop ceiling', () async {
    final controller = StudioRuntimeController();

    final result = await controller.runCurrentWorkflow(loops: 1000);
    await controller.dispose();

    expect(result, isNull);
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('最多支持 999 轮。'),
    );
  });

  test('runtime controller runs A-F workflow serially', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final delays = <Duration>[];
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      delay: (duration) async => delays.add(duration),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.requestedLoops, 1);
    expect(result?.completedLoops, 1);
    expect(result?.stopped, isFalse);
    expect(deviceActions.calls, [
      'tap:A:92,499:80',
      'release',
      'tap:B:237,431:80',
      'release',
      'tap:C:237,431:80',
      'release',
      'tap:D:185,500:80',
      'release',
      'tap:E:186,600:80',
      'release',
      'tap:F:186,600:80',
      'release',
    ]);
    expect(
      delays.map((duration) => duration.inMilliseconds),
      orderedEquals([50, 50, 50, 4000, 50]),
    );
    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(controller.snapshot.executionFocus.activeNodeId, isNull);
    expect(controller.snapshot.executionFocus.failedNodeId, isNull);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll(['tap_a', 'wait_ab', 'tap_f']),
    );
  });

  test(
    'runtime controller refuses run before device actions when sub workflow is missing',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor();
      const workflow = WorkflowDefinition(
        id: 'missing-subflow-run',
        name: '缺失子流程运行',
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
            label: '缺失子流程',
            next: ['end'],
            parameters: {'workflowId': 'missing-child'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      );
      final controller = StudioRuntimeController(
        workflow: workflow,
        sessionManager: fakeSessionManager(server),
        deviceActions: deviceActions,
      );

      await controller.connectDevice();
      final result = await controller.runCurrentWorkflow(loops: 1);
      await controller.dispose();
      await server.close(force: true);

      expect(result, isNull);
      expect(deviceActions.calls, isEmpty);
      expect(controller.snapshot.runStatus, RunStatus.idle);
      expect(
        controller.snapshot.events.map((event) => event.message),
        contains(contains('不存在的子流程')),
      );
    },
  );

  test('runtime executes swipe and input nodes serially', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final delays = <Duration>[];
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      workflow: const WorkflowDefinition(
        id: 'gesture-input-workflow',
        name: 'Gesture Input Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['tap_1'],
          ),
          WorkflowNode(
            id: 'tap_1',
            type: WorkflowNodeType.tap,
            label: 'Focus Field',
            next: ['input_1'],
            parameters: {'label': 'Focus Field', 'x': 10, 'y': 20},
          ),
          WorkflowNode(
            id: 'input_1',
            type: WorkflowNodeType.input,
            label: 'Type Query',
            next: ['swipe_1'],
            parameters: {'label': 'Type Query', 'text': 'hello'},
          ),
          WorkflowNode(
            id: 'swipe_1',
            type: WorkflowNodeType.swipe,
            label: 'Swipe Up',
            next: ['wait_1'],
            parameters: {
              'label': 'Swipe Up',
              'fromX': 200,
              'fromY': 700,
              'toX': 200,
              'toY': 300,
              'durationMs': 450,
            },
          ),
          WorkflowNode(
            id: 'wait_1',
            type: WorkflowNodeType.wait,
            label: 'Settle',
            next: ['end'],
            parameters: {'ms': 50},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
      delay: (duration) async => delays.add(duration),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, [
      'tap:Focus Field:10,20:80',
      'release',
      'input:Type Query:5',
      'swipe:Swipe Up:200,700->200,300:450',
      'release',
    ]);
    expect(delays.map((duration) => duration.inMilliseconds), [50]);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll(['tap_1', 'input_1', 'swipe_1', 'wait_1']),
    );
    final eventMessages = controller.snapshot.events
        .map((event) => event.message)
        .join('\n');
    expect(eventMessages, contains('第 1/1 轮：点击 Focus Field。'));
    expect(eventMessages, contains('第 1/1 轮：输入 Type Query。'));
    expect(eventMessages, contains('第 1/1 轮：滑动 Swipe Up。'));
    expect(eventMessages, contains('第 1/1 轮：等待 50ms。'));
    expect(
      eventMessages,
      isNot(matches(RegExp(r'\b(Loop|tap|wait|swipe|input)\b'))),
    );
  });

  test('runtime executes bounded loop body serially', () async {
    final server = await sessionServer('runtime-session');
    final delays = <Duration>[];
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: FakeDeviceActionExecutor(),
      workflow: const WorkflowDefinition(
        id: 'loop-workflow',
        name: 'Loop Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['loop_1'],
          ),
          WorkflowNode(
            id: 'loop_1',
            type: WorkflowNodeType.loop,
            label: 'Loop Twice',
            next: ['wait_body', 'tap_after'],
            parameters: {'count': 2},
          ),
          WorkflowNode(
            id: 'wait_body',
            type: WorkflowNodeType.wait,
            label: 'Body Wait',
            next: ['loop_1'],
            parameters: {'ms': 25},
          ),
          WorkflowNode(
            id: 'tap_after',
            type: WorkflowNodeType.tap,
            label: 'After Loop',
            next: ['end'],
            parameters: {'label': 'After Loop', 'x': 30, 'y': 40},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
      delay: (duration) async => delays.add(duration),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(delays.map((duration) => duration.inMilliseconds), [25, 25]);
    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll(['loop_1', 'wait_body', 'tap_after']),
    );
  });

  test('runtime exposes active and completed workflow node focus', () async {
    final server = await sessionServer('runtime-session');
    final waitStarted = Completer<void>();
    final releaseWait = Completer<void>();
    late StudioRuntimeController controller;
    controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: FakeDeviceActionExecutor(),
      workflow: const WorkflowDefinition(
        id: 'focus-workflow',
        name: 'Focus Workflow',
        entryNodesId: 'start',
        nodes: [
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
            next: ['wait_1'],
            parameters: {'label': 'Login', 'x': 10, 'y': 20},
          ),
          WorkflowNode(
            id: 'wait_1',
            type: WorkflowNodeType.wait,
            label: 'Wait For Screen',
            next: ['end'],
            parameters: {'ms': 500},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
      delay: (_) async {
        if (!waitStarted.isCompleted) {
          waitStarted.complete();
        }
        await releaseWait.future;
      },
    );

    await controller.connectDevice();
    final runFuture = controller.runCurrentWorkflow(loops: 2);
    await waitStarted.future;

    expect(controller.snapshot.executionFocus.activeNodeId, 'wait_1');
    expect(controller.snapshot.executionFocus.completedNodeIds, {'tap_1'});
    expect(controller.snapshot.executionFocus.activeLoopIndex, 0);
    expect(controller.snapshot.executionFocus.totalLoops, 2);
    expect(controller.snapshot.executionFocus.runStartedAt, isNotNull);
    expect(controller.snapshot.executionFocus.completedSteps, 1);
    expect(controller.snapshot.executionFocus.totalSteps, 4);

    releaseWait.complete();
    final result = await runFuture;
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 2);
    expect(controller.snapshot.executionFocus.activeNodeId, isNull);
    expect(controller.snapshot.executionFocus.failedNodeId, isNull);
    expect(controller.snapshot.executionFocus.completedSteps, 4);
    expect(controller.snapshot.executionFocus.totalSteps, 4);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll(['tap_1', 'wait_1']),
    );
  });

  test('runtime controller stops after current atomic wait', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    late StudioRuntimeController controller;
    var stopRequested = false;
    controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      delay: (duration) async {
        if (!stopRequested) {
          stopRequested = true;
          await controller.stopRun();
        }
      },
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 2);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.requestedLoops, 2);
    expect(result?.completedLoops, 0);
    expect(result?.stopped, isTrue);
    expect(deviceActions.calls, ['tap:A:92,499:80', 'release']);
    expect(controller.snapshot.runStatus, RunStatus.idle);
  });

  test('runtime uses imported workflow and default tap duration', () async {
    final config = StudioProjectConfig.fromJson({
      'appium': {
        'capabilities': {
          'platformName': 'iOS',
          'appium:automationName': 'XCUITest',
          'appium:udid': 'TEST_DEVICE',
        },
      },
      'run': {'tapDurationMs': 123},
      'sequence': [
        {'type': 'tap', 'label': 'A', 'x': 10, 'y': 20},
        {'type': 'wait', 'ms': 50},
        {'type': 'tap', 'label': 'B', 'x': 30, 'y': 40},
      ],
    });
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server, config: config.deviceSession),
      deviceActions: deviceActions,
      workflow: config.workflow,
      defaultTapDurationMs: config.tapDurationMs,
      delay: (_) async {},
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, [
      'tap:A:10,20:123',
      'release',
      'tap:B:30,40:123',
      'release',
    ]);
  });
}
