import 'dart:convert';
import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 视觉节点回归测试，聚焦低置信挂起、系统弹窗和视觉证据链。
// 用例只使用 fake Appium session 与本地临时证据目录，不连接真实设备。
void main() {
  test('runtime pauses visual branch when confidence is too low', () async {
    final server = await sessionServer('runtime-session');
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: FakeDeviceActionExecutor(),
      workflow: const WorkflowDefinition(
        id: 'failing-workflow',
        name: 'Failing Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['visual_1'],
          ),
          WorkflowNode(
            id: 'visual_1',
            type: WorkflowNodeType.visualBranch,
            label: '需要截图',
            next: ['end'],
            parameters: {'confidenceThreshold': 0.85},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.resolvePause();
    await controller.dispose();
    await server.close(force: true);

    expect(result?.paused, isTrue);
    expect(result?.completedLoops, 0);
    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(controller.snapshot.executionFocus.activeNodeId, isNull);
    expect(controller.snapshot.executionFocus.failedNodeId, 'visual_1');
    expect(controller.snapshot.executionFocus.completedNodeIds, isEmpty);
    expect(
      controller.snapshot.events.map((event) => event.message),
      containsAll(['第 1/1 轮：视觉判断 需要截图 置信度不足，已暂停。', '暂停已解除，任务已安全收口。']),
    );
  });

  test('runtime resolve pause only closes paused state', () async {
    final server = await sessionServer('runtime-session');
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: FakeDeviceActionExecutor(),
      workflow: const WorkflowDefinition(
        id: 'visual-workflow',
        name: 'Visual Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['visual_1'],
          ),
          WorkflowNode(
            id: 'visual_1',
            type: WorkflowNodeType.visualBranch,
            label: '查屏幕',
            next: ['tap_1'],
            parameters: {'confidenceThreshold': 0.85},
          ),
          WorkflowNode(
            id: 'tap_1',
            type: WorkflowNodeType.tap,
            label: '继续',
            next: ['end'],
            parameters: {'label': '继续', 'x': 10, 'y': 20},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);

    expect(result?.paused, isTrue);
    expect(controller.snapshot.runStatus, RunStatus.paused);
    expect(controller.snapshot.executionFocus.failedNodeId, 'visual_1');

    await controller.resolvePause();
    await controller.dispose();
    await server.close(force: true);

    expect(controller.snapshot.runStatus, RunStatus.idle);
    expect(controller.snapshot.executionFocus.activeNodeId, isNull);
    expect(controller.snapshot.executionFocus.failedNodeId, 'visual_1');
    expect(controller.snapshot.executionFocus.completedNodeIds, isEmpty);
  });

  test(
    'runtime executes visual branch after snapshot evidence exists',
    () async {
      final server = await sessionServer('runtime-session');
      final deviceActions = FakeDeviceActionExecutor(
        screenshotBase64: base64Encode([1, 2, 3]),
      );
      final controller = StudioRuntimeController(
        sessionManager: fakeSessionManager(server),
        deviceActions: deviceActions,
        workflow: const WorkflowDefinition(
          id: 'visual-workflow',
          name: 'Visual Workflow',
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
              label: '截图',
              next: ['visual_1'],
              parameters: {'saveEvidence': false},
            ),
            WorkflowNode(
              id: 'visual_1',
              type: WorkflowNodeType.visualBranch,
              label: '已有截图',
              next: ['tap_1'],
              parameters: {'confidenceThreshold': 0.8},
            ),
            WorkflowNode(
              id: 'tap_1',
              type: WorkflowNodeType.tap,
              label: '继续',
              next: ['end'],
              parameters: {'x': 12, 'y': 34, 'label': '继续'},
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
      expect(result?.paused, isFalse);
      expect(
        controller.snapshot.latestScreenshotBase64,
        base64Encode([1, 2, 3]),
      );
      expect(deviceActions.calls, [
        'screenshot',
        'source:runtime-session',
        'tap:继续:12,34:80',
        'release',
      ]);
      expect(
        controller.snapshot.executionFocus.completedNodeIds,
        containsAll(['snapshot_1', 'visual_1', 'tap_1']),
      );
      expect(
        controller.snapshot.events.map((event) => event.message),
        contains('第 1/1 轮：视觉判断 已有截图 通过。'),
      );
    },
  );

  test('runtime persists visual evidence chain for visual branch', () async {
    final root = await Directory.systemTemp.createTemp('studio-evidence-');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor(
      screenshotBase64: base64Encode([1, 2, 3]),
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      evidenceStore: store,
      runHistoryReader: store,
      runDetailReader: store,
      workflow: const WorkflowDefinition(
        id: 'visual-evidence-workflow',
        name: 'Visual Evidence Workflow',
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
            label: '截图',
            next: ['visual_1'],
            parameters: {'saveEvidence': false},
          ),
          WorkflowNode(
            id: 'visual_1',
            type: WorkflowNodeType.visualBranch,
            label: '已有截图',
            next: ['end'],
            parameters: {'confidenceThreshold': 0.8},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    final summary = await store.readSummary();
    final detail = await store.readDetail(summary.recentRuns.single.runId);
    await root.delete(recursive: true);

    expect(result?.completedLoops, 1);
    expect(detail, isNotNull);
    expect(detail!.visualEvidenceEvents, hasLength(1));
    final visual = detail.visualEvidenceEvents.single.visualEvidence!;
    expect(visual.rule, 'latest_screenshot_presence');
    expect(visual.screenshotAvailable, isTrue);
    expect(visual.confidence, 1.0);
    expect(visual.confidenceThreshold, 0.8);
    expect(visual.result, isTrue);
    expect(visual.action, 'continue');
    expect(visual.reason, '最新截图可用，置信度已达标。');
    expect(visual.selectedNext, 'end');
  });

  test('runtime pauses visual branch when known iOS popup is detected', () async {
    final root = await Directory.systemTemp.createTemp('studio-popup-');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor(
      screenshotBase64: base64Encode([1, 2, 3]),
      pageSourceXml:
          '<App><Alert name="Developer App is not trusted"><Button name="OK"/></Alert></App>',
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      evidenceStore: store,
      runHistoryReader: store,
      runDetailReader: store,
      workflow: const WorkflowDefinition(
        id: 'known-popup-workflow',
        name: 'Known Popup Workflow',
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
            label: '截图',
            next: ['visual_1'],
            parameters: {'saveEvidence': false},
          ),
          WorkflowNode(
            id: 'visual_1',
            type: WorkflowNodeType.visualBranch,
            label: '查弹窗',
            next: ['tap_1'],
            parameters: {'confidenceThreshold': 0.8},
          ),
          WorkflowNode(
            id: 'tap_1',
            type: WorkflowNodeType.tap,
            label: '不应执行',
            next: ['end'],
            parameters: {'x': 12, 'y': 34, 'label': '不应执行'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    final summary = await store.readSummary();
    final detail = await store.readDetail(summary.recentRuns.single.runId);
    await controller.resolvePause();
    await controller.dispose();
    await server.close(force: true);
    await root.delete(recursive: true);

    expect(result?.paused, isTrue);
    expect(result?.completedLoops, 0);
    expect(deviceActions.calls, ['screenshot', 'source:runtime-session']);
    expect(controller.snapshot.executionFocus.failedNodeId, 'visual_1');
    expect(detail, isNotNull);
    final visual = detail!.visualEvidenceEvents.single.visualEvidence!;
    expect(visual.rule, 'known_ios_developer_trust_popup');
    expect(visual.result, isFalse);
    expect(visual.action, 'pause');
    expect(visual.reason, contains('开发者信任'));
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('第 1/1 轮：发现系统弹窗，已暂停。'),
    );
  });

  test(
    'runtime visual branch resolves image target through target resolver',
    () async {
      final root = await Directory.systemTemp.createTemp('studio-vision-');
      final store = LocalRunEvidenceStore(rootDirectory: root);
      final server = await sessionServer('runtime-session');
      final screenshot = fixturePngBase64(
        width: 5,
        height: 5,
        colorAt: (x, y) => x >= 1 && x <= 2 && y >= 1 && y <= 2
            ? const [255, 0, 0]
            : const [0, 0, 0],
      );
      final template = fixturePngBase64(
        width: 2,
        height: 2,
        colorAt: (x, y) => const [255, 0, 0],
      );
      final deviceActions = FakeDeviceActionExecutor(
        screenshotBase64: screenshot,
      );
      final controller = StudioRuntimeController(
        sessionManager: fakeSessionManager(server),
        deviceActions: deviceActions,
        evidenceStore: store,
        runHistoryReader: store,
        runDetailReader: store,
        targets: [_imageTarget(template)],
        workflow: const WorkflowDefinition(
          id: 'image-target-workflow',
          name: 'Image Target Workflow',
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
              label: '截图',
              next: ['visual_1'],
              parameters: {'saveEvidence': false},
            ),
            WorkflowNode(
              id: 'visual_1',
              type: WorkflowNodeType.visualBranch,
              label: '找图标',
              next: ['end'],
              parameters: {
                'targetRef': 'login_button',
                'confidenceThreshold': 0.99,
              },
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      );

      await controller.connectDevice();
      final result = await controller.runCurrentWorkflow(loops: 1);
      final summary = await store.readSummary();
      final detail = await store.readDetail(summary.recentRuns.single.runId);
      await controller.dispose();
      await server.close(force: true);
      await root.delete(recursive: true);

      expect(result?.completedLoops, 1);
      expect(deviceActions.calls, ['screenshot', 'source:runtime-session']);
      expect(
        controller.snapshot.executionFocus.completedNodeIds,
        contains('visual_1'),
      );
      final visual = detail!.visualEvidenceEvents.single.visualEvidence!;
      expect(visual.rule, 'target_image');
      expect(visual.confidence, 1);
      expect(visual.reason, '已找到目标。');
      expect(visual.result, isTrue);
    },
  );

  test(
    'runtime visual branch pauses when image target confidence is low',
    () async {
      final server = await sessionServer('runtime-session');
      final screenshot = fixturePngBase64(width: 4, height: 4);
      final template = fixturePngBase64(
        width: 2,
        height: 2,
        colorAt: (x, y) => const [0, 0, 255],
      );
      final deviceActions = FakeDeviceActionExecutor(
        screenshotBase64: screenshot,
      );
      final controller = StudioRuntimeController(
        sessionManager: fakeSessionManager(server),
        deviceActions: deviceActions,
        targets: [_imageTarget(template)],
        workflow: const WorkflowDefinition(
          id: 'low-image-target-workflow',
          name: 'Low Image Target Workflow',
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
              label: '截图',
              next: ['visual_1'],
              parameters: {'saveEvidence': false},
            ),
            WorkflowNode(
              id: 'visual_1',
              type: WorkflowNodeType.visualBranch,
              label: '找按钮',
              next: ['end'],
              parameters: {
                'targetRef': 'login_button',
                'confidenceThreshold': 0.99,
              },
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      );

      await controller.connectDevice();
      final result = await controller.runCurrentWorkflow(loops: 1);
      await controller.resolvePause();
      await controller.dispose();
      await server.close(force: true);

      expect(result?.paused, isTrue);
      expect(result?.completedLoops, 0);
      expect(controller.snapshot.executionFocus.failedNodeId, 'visual_1');
      expect(deviceActions.calls, ['screenshot', 'source:runtime-session']);
      expect(
        controller.snapshot.events.map((event) => event.message),
        contains('第 1/1 轮：视觉判断 找按钮 目标未确认，已暂停。'),
      );
    },
  );

  test('runtime waits for target and continues after match', () async {
    final root = await Directory.systemTemp.createTemp('studio-wait-target-');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final server = await sessionServer('runtime-session');
    final screenshot = fixturePngBase64(
      width: 5,
      height: 5,
      colorAt: (x, y) => x >= 2 && x <= 3 && y >= 2 && y <= 3
          ? const [0, 255, 0]
          : const [0, 0, 0],
    );
    final template = fixturePngBase64(
      width: 2,
      height: 2,
      colorAt: (x, y) => const [0, 255, 0],
    );
    final deviceActions = FakeDeviceActionExecutor(
      screenshotBase64: screenshot,
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      evidenceStore: store,
      runHistoryReader: store,
      runDetailReader: store,
      targets: [_imageTarget(template)],
      workflow: const WorkflowDefinition(
        id: 'wait-target-workflow',
        name: 'Wait Target Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['wait_target'],
          ),
          WorkflowNode(
            id: 'wait_target',
            type: WorkflowNodeType.waitForTarget,
            label: '等登录',
            next: ['tap_1'],
            parameters: {
              'targetRef': 'login_button',
              'timeoutMs': 1000,
              'intervalMs': 250,
              'confidenceThreshold': 0.99,
            },
          ),
          WorkflowNode(
            id: 'tap_1',
            type: WorkflowNodeType.tap,
            label: '继续',
            next: ['end'],
            parameters: {'x': 12, 'y': 34, 'label': '继续'},
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    final summary = await store.readSummary();
    final detail = await store.readDetail(summary.recentRuns.single.runId);
    await controller.dispose();
    await server.close(force: true);
    await root.delete(recursive: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, ['screenshot', 'tap:继续:12,34:80', 'release']);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      containsAll(['wait_target', 'tap_1']),
    );
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('第 1/1 轮：目标 登录按钮 已出现。'),
    );
    final visual = detail!.visualEvidenceEvents.single.visualEvidence!;
    expect(visual.rule, 'target_image');
    expect(visual.result, isTrue);
    expect(visual.reason, '已找到目标。');
  });

  test('runtime waits for selector target and continues after match', () async {
    final server = await sessionServer('runtime-session');
    final deviceActions = FakeDeviceActionExecutor(
      pageSourceXml:
          '<AppiumAUT><XCUIElementTypeButton label="登录" x="10" y="20" width="80" height="44" /></AppiumAUT>',
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      targets: const [
        RuntimeTargetDefinition(
          id: 'login_button',
          kind: RuntimeTargetKind.selector,
          label: '登录按钮',
          payload: <String, Object?>{'selector': 'label=登录'},
        ),
      ],
      workflow: const WorkflowDefinition(
        id: 'wait-selector-target-workflow',
        name: 'Wait Selector Target Workflow',
        entryNodesId: 'start',
        nodes: [
          WorkflowNode(
            id: 'start',
            type: WorkflowNodeType.start,
            label: '开始',
            next: ['wait_target'],
          ),
          WorkflowNode(
            id: 'wait_target',
            type: WorkflowNodeType.waitForTarget,
            label: '等登录',
            next: ['end'],
            parameters: {
              'targetRef': 'login_button',
              'timeoutMs': 1000,
              'intervalMs': 250,
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
    expect(deviceActions.calls, ['screenshot', 'source:runtime-session']);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      contains('wait_target'),
    );
  });

  test(
    'runtime pauses wait for target after low confidence attempts',
    () async {
      final server = await sessionServer('runtime-session');
      final screenshot = fixturePngBase64(width: 4, height: 4);
      final template = fixturePngBase64(
        width: 2,
        height: 2,
        colorAt: (x, y) => const [0, 0, 255],
      );
      final deviceActions = FakeDeviceActionExecutor(
        screenshotBase64: screenshot,
      );
      final controller = StudioRuntimeController(
        sessionManager: fakeSessionManager(server),
        deviceActions: deviceActions,
        delay: (_) async {},
        targets: [_imageTarget(template)],
        workflow: const WorkflowDefinition(
          id: 'wait-target-low-workflow',
          name: 'Wait Target Low Workflow',
          entryNodesId: 'start',
          nodes: [
            WorkflowNode(
              id: 'start',
              type: WorkflowNodeType.start,
              label: '开始',
              next: ['wait_target'],
            ),
            WorkflowNode(
              id: 'wait_target',
              type: WorkflowNodeType.waitForTarget,
              label: '等登录',
              next: ['end'],
              parameters: {
                'targetRef': 'login_button',
                'timeoutMs': 1000,
                'intervalMs': 500,
                'confidenceThreshold': 0.99,
              },
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      );

      await controller.connectDevice();
      final result = await controller.runCurrentWorkflow(loops: 1);
      await controller.resolvePause();
      await controller.dispose();
      await server.close(force: true);

      expect(result?.paused, isTrue);
      expect(result?.completedLoops, 0);
      expect(deviceActions.calls, ['screenshot', 'screenshot']);
      expect(controller.snapshot.executionFocus.failedNodeId, 'wait_target');
      expect(
        controller.snapshot.events.map((event) => event.message),
        contains('第 1/1 轮：目标 登录按钮 未确认，已暂停。'),
      );
    },
  );

  test('runtime taps image target through target resolver', () async {
    final root = await Directory.systemTemp.createTemp('studio-tap-target-');
    final store = LocalRunEvidenceStore(rootDirectory: root);
    final server = await sessionServer('runtime-session');
    final screenshot = fixturePngBase64(
      width: 5,
      height: 5,
      colorAt: (x, y) => x >= 1 && x <= 2 && y >= 1 && y <= 2
          ? const [255, 0, 0]
          : const [0, 0, 0],
    );
    final template = fixturePngBase64(
      width: 2,
      height: 2,
      colorAt: (x, y) => const [255, 0, 0],
    );
    final deviceActions = FakeDeviceActionExecutor(
      screenshotBase64: screenshot,
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      evidenceStore: store,
      runHistoryReader: store,
      runDetailReader: store,
      targets: [_imageTarget(template)],
      workflow: const WorkflowDefinition(
        id: 'tap-image-target-workflow',
        name: 'Tap Image Target Workflow',
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
            label: '点登录',
            next: ['end'],
            parameters: {
              'targetRef': 'login_button',
              'confidenceThreshold': 0.99,
            },
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    final summary = await store.readSummary();
    final detail = await store.readDetail(summary.recentRuns.single.runId);
    await controller.dispose();
    await server.close(force: true);
    await root.delete(recursive: true);

    expect(result?.completedLoops, 1);
    expect(result?.paused, isFalse);
    expect(deviceActions.calls, ['screenshot', 'tap:登录按钮:2,2:80', 'release']);
    expect(
      controller.snapshot.executionFocus.completedNodeIds,
      contains('tap_1'),
    );
    final visualEvents = detail!.visualEvidenceEvents;
    expect(visualEvents, hasLength(1));
    expect(visualEvents.single.type, 'targetResolution');
    final visual = visualEvents.single.visualEvidence!;
    expect(visual.rule, 'target_image');
    expect(visual.result, isTrue);
    expect(visual.action, 'tap');
    expect(visual.reason, '已找到目标。');
    final tapTrace = detail.nodeTraces
        .where((trace) => trace.nodeId == 'tap_1')
        .single;
    expect(tapTrace.status, 'ok');
  });

  test('runtime taps image target from local template asset ref', () async {
    final root = await Directory.systemTemp.createTemp('studio-tap-asset-');
    final assetStore = LocalTargetAssetStore(projectDirectory: root);
    final server = await sessionServer('runtime-session');
    final screenshot = fixturePngBase64(
      width: 5,
      height: 5,
      colorAt: (x, y) => x >= 2 && x <= 3 && y >= 2 && y <= 3
          ? const [0, 255, 0]
          : const [0, 0, 0],
    );
    final template = fixturePngBase64(
      width: 2,
      height: 2,
      colorAt: (x, y) => const [0, 255, 0],
    );
    final imageRef = await assetStore.saveImageTemplateBase64(
      targetId: 'login_button',
      imageBase64: template,
    );
    final deviceActions = FakeDeviceActionExecutor(
      screenshotBase64: screenshot,
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      targetAssetStore: assetStore,
      targets: [
        RuntimeTargetDefinition(
          id: 'login_button',
          kind: RuntimeTargetKind.image,
          label: '登录按钮',
          payload: <String, Object?>{'imageRef': imageRef},
        ),
      ],
      workflow: const WorkflowDefinition(
        id: 'tap-image-asset-workflow',
        name: 'Tap Image Asset Workflow',
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
            label: '点登录',
            next: ['end'],
            parameters: {
              'targetRef': 'login_button',
              'confidenceThreshold': 0.99,
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
    await root.delete(recursive: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, ['screenshot', 'tap:登录按钮:3,3:80', 'release']);
  });

  test('runtime pauses image target tap when confidence is low', () async {
    final server = await sessionServer('runtime-session');
    final screenshot = fixturePngBase64(width: 4, height: 4);
    final template = fixturePngBase64(
      width: 2,
      height: 2,
      colorAt: (x, y) => const [0, 0, 255],
    );
    final deviceActions = FakeDeviceActionExecutor(
      screenshotBase64: screenshot,
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
      targets: [_imageTarget(template)],
      workflow: const WorkflowDefinition(
        id: 'tap-image-target-low-workflow',
        name: 'Tap Image Target Low Workflow',
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
            label: '点登录',
            next: ['end'],
            parameters: {
              'targetRef': 'login_button',
              'confidenceThreshold': 0.99,
            },
          ),
          WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
        ],
      ),
    );

    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.resolvePause();
    await controller.dispose();
    await server.close(force: true);

    expect(result?.paused, isTrue);
    expect(result?.completedLoops, 0);
    expect(deviceActions.calls, ['screenshot']);
    expect(controller.snapshot.executionFocus.failedNodeId, 'tap_1');
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('第 1/1 轮：目标 登录按钮 未确认，已暂停。'),
    );
  });
}

RuntimeTargetDefinition _imageTarget(String templateBase64) {
  return RuntimeTargetDefinition(
    id: 'login_button',
    kind: RuntimeTargetKind.image,
    label: '登录按钮',
    payload: <String, Object?>{
      'imageRef': 'targets/login-button.png',
      'imageBase64': templateBase64,
    },
  );
}
