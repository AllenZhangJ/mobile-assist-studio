import 'dart:io';

import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// V4 Target Library 回归测试。
// 用例保护目标持久化、引用诊断、删除保护和坐标目标执行语义。
void main() {
  test('local target library store writes and reads valid targets', () async {
    final directory = await Directory.systemTemp.createTemp('target-store-');
    final file = File('${directory.path}/targets/target.library.json');
    final store = LocalTargetLibraryStore(file: file);
    final target = RuntimeTargetDefinition.coordinate(
      id: 'login_button',
      label: '登录按钮',
      x: 120,
      y: 240,
      viewportWidth: 390,
      viewportHeight: 844,
    );

    await store.saveTargets([target]);
    final restored = store.loadTargetsSync();
    await directory.delete(recursive: true);

    expect(restored, hasLength(1));
    expect(restored.single.toJson(), target.toJson());
  });

  test('local target library store ignores invalid target files', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bad-target-store-',
    );
    final file = File('${directory.path}/targets/target.library.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '{"version":1,"targets":[{"id":"bad","kind":"coordinate","label":"坏","payload":{"x":1}}]}',
    );
    final store = LocalTargetLibraryStore(file: file);

    final restored = store.loadTargetsSync();
    await directory.delete(recursive: true);

    expect(restored, isEmpty);
  });

  test('local target asset store writes and reads image templates', () async {
    final directory = await Directory.systemTemp.createTemp('target-assets-');
    final store = LocalTargetAssetStore(projectDirectory: directory);
    final template = fixturePngBase64(width: 2, height: 2);

    final imageRef = await store.saveImageTemplateBase64(
      targetId: 'login_button',
      imageBase64: template,
    );
    final restored = await store.readImageTemplateBase64(imageRef);
    final unsafe = await store.readImageTemplateBase64('../secret.png');
    await directory.delete(recursive: true);

    expect(imageRef, 'targets/images/login_button.png');
    expect(restored, template);
    expect(unsafe, isNull);
  });

  test('target validator rejects unsafe image references', () {
    final issues = const TargetLibraryValidator().validate([
      const RuntimeTargetDefinition(
        id: 'bad_image',
        kind: RuntimeTargetKind.image,
        label: '坏图片',
        payload: <String, Object?>{'imageRef': '../secret.png'},
      ),
    ]);

    expect(
      issues.map((issue) => issue.message),
      contains('Target bad_image imageRef is unsafe.'),
    );
  });

  test('runtime creates image target from local template asset', () async {
    final directory = await Directory.systemTemp.createTemp(
      'image-target-command-',
    );
    final controller = StudioRuntimeController(
      targetAssetStore: LocalTargetAssetStore(projectDirectory: directory),
    );
    final template = fixturePngBase64(width: 2, height: 2);

    final target = await controller.createImageTargetFromTemplate(
      label: 'Login Button',
      imageBase64: template,
    );
    final imageRef = target?.payload['imageRef']?.toString();
    final restored = imageRef == null
        ? null
        : await LocalTargetAssetStore(
            projectDirectory: directory,
          ).readImageTemplateBase64(imageRef);
    await controller.dispose();
    await directory.delete(recursive: true);

    expect(target, isNotNull);
    expect(target!.kind, RuntimeTargetKind.image);
    expect(target.payload.containsKey('imageBase64'), isFalse);
    expect(imageRef, startsWith('targets/images/login-button-'));
    expect(restored, template);
  });

  test('runtime tests image target against latest screenshot only', () async {
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
    final server = await sessionServer('target-test-session');
    final actions = FakeDeviceActionExecutor(screenshotBase64: screenshot);
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: actions,
    );
    final target = RuntimeTargetDefinition(
      id: 'login_image',
      kind: RuntimeTargetKind.image,
      label: '登录图',
      payload: <String, Object?>{
        'imageRef': 'targets/images/login.png',
        'imageBase64': template,
      },
    );

    await controller.connectDevice();
    await controller.captureScreenshot(reason: 'target-test');
    await controller.upsertTarget(target);
    final result = await controller.testTargetAgainstLatestScreenshot(
      'login_image',
      confidenceThreshold: 0.99,
    );
    await controller.dispose();
    await server.close(force: true);

    expect(result?.status, TargetResolutionStatus.matched);
    expect(result?.point?.x, 2);
    expect(result?.point?.y, 2);
    expect(actions.calls, ['screenshot']);
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('已找到目标：登录图。'),
    );
  });

  test('runtime target commands protect referenced target deletion', () async {
    final controller = StudioRuntimeController();
    final target = RuntimeTargetDefinition.coordinate(
      id: 'confirm_button',
      label: '确认',
      x: 10,
      y: 20,
    );
    final workflow = const WorkflowDefinition(
      id: 'target-workflow',
      name: '目标流程',
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
          label: '点确认',
          next: ['end'],
          parameters: {'targetRef': 'confirm_button'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final targetSaved = await controller.upsertTarget(target);
    final workflowSaved = await controller.updateWorkflow(workflow);
    final deleted = await controller.deleteTarget('confirm_button');
    await controller.dispose();

    expect(targetSaved, isTrue);
    expect(workflowSaved, isTrue);
    expect(deleted, isFalse);
    expect(controller.snapshot.targetLibrary.count, 1);
    expect(
      controller.snapshot.events.map((event) => event.message),
      contains('当前流程正在使用该目标。'),
    );
  });

  test('runtime rejects workflow that references missing target', () async {
    final controller = StudioRuntimeController();
    const workflow = WorkflowDefinition(
      id: 'missing-target-workflow',
      name: '缺目标流程',
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
          label: '点目标',
          next: ['end'],
          parameters: {'targetRef': 'missing_target'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final saved = await controller.updateWorkflow(workflow);
    await controller.dispose();

    expect(saved, isFalse);
    expect(controller.snapshot.workflow.id, isNot('missing-target-workflow'));
    expect(
      controller.snapshot.events.map((event) => event.message).join('\n'),
      contains('不存在的目标'),
    );
  });

  test('runtime executes coordinate target tap through targetRef', () async {
    final server = await sessionServer('target-runtime-session');
    final deviceActions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: deviceActions,
    );
    final target = RuntimeTargetDefinition.coordinate(
      id: 'login_button',
      label: '登录按钮',
      x: 101,
      y: 202,
    );
    const workflow = WorkflowDefinition(
      id: 'coordinate-target-run',
      name: '坐标目标运行',
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
          parameters: {'targetRef': 'login_button', 'durationMs': 90},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    await controller.upsertTarget(target);
    await controller.updateWorkflow(workflow);
    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(deviceActions.calls, ['tap:登录按钮:101,202:90', 'release']);
    expect(controller.snapshot.runStatus, RunStatus.idle);
  });

  test('runtime executes region target tap through target resolver', () async {
    final server = await sessionServer('region-target-session');
    final actions = FakeDeviceActionExecutor();
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: actions,
    );
    const target = RuntimeTargetDefinition(
      id: 'pay_area',
      kind: RuntimeTargetKind.region,
      label: '支付区',
      payload: <String, Object?>{'x': 10, 'y': 20, 'width': 30, 'height': 40},
    );
    const workflow = WorkflowDefinition(
      id: 'region-target-run',
      name: '区域目标运行',
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
          label: '点支付区',
          next: ['end'],
          parameters: {'targetRef': 'pay_area', 'durationMs': 90},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    await controller.upsertTarget(target);
    await controller.updateWorkflow(workflow);
    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(actions.calls, ['screenshot', 'tap:支付区:25,40:90', 'release']);
    expect(controller.snapshot.runStatus, RunStatus.idle);
  });

  test('runtime executes selector target tap through target resolver', () async {
    final server = await sessionServer('selector-target-session');
    final actions = FakeDeviceActionExecutor(
      pageSourceXml:
          '<hierarchy><node text="确认" bounds="[20,30][120,70]" clickable="true" /></hierarchy>',
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: actions,
    );
    const target = RuntimeTargetDefinition(
      id: 'confirm_button',
      kind: RuntimeTargetKind.selector,
      label: '确认按钮',
      payload: <String, Object?>{'selector': 'text=确认'},
    );
    const workflow = WorkflowDefinition(
      id: 'selector-target-run',
      name: '元素目标运行',
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
          label: '点确认',
          next: ['end'],
          parameters: {'targetRef': 'confirm_button', 'durationMs': 90},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    await controller.upsertTarget(target);
    await controller.updateWorkflow(workflow);
    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(actions.calls, [
      'screenshot',
      'source:selector-target-session',
      'tap:确认按钮:70,50:90',
      'release',
    ]);
    expect(controller.snapshot.runStatus, RunStatus.idle);
  });

  test('runtime executes text target tap through target resolver', () async {
    final server = await sessionServer('text-target-session');
    final actions = FakeDeviceActionExecutor(
      pageSourceXml:
          '<hierarchy><node text="立即支付" bounds="[40,80][180,132]" /></hierarchy>',
    );
    final controller = StudioRuntimeController(
      sessionManager: fakeSessionManager(server),
      deviceActions: actions,
    );
    const target = RuntimeTargetDefinition(
      id: 'pay_text',
      kind: RuntimeTargetKind.text,
      label: '支付文案',
      payload: <String, Object?>{'query': '立即支付'},
    );
    const workflow = WorkflowDefinition(
      id: 'text-target-run',
      name: '文本目标运行',
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
          label: '点支付',
          next: ['end'],
          parameters: {'targetRef': 'pay_text', 'durationMs': 90},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    await controller.upsertTarget(target);
    await controller.updateWorkflow(workflow);
    await controller.connectDevice();
    final result = await controller.runCurrentWorkflow(loops: 1);
    await controller.dispose();
    await server.close(force: true);

    expect(result?.completedLoops, 1);
    expect(actions.calls, [
      'screenshot',
      'source:text-target-session',
      'tap:支付文案:110,106:90',
      'release',
    ]);
    expect(controller.snapshot.runStatus, RunStatus.idle);
  });
}
