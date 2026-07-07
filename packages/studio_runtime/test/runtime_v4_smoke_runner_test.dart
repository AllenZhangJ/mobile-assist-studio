import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';
import 'package:test/test.dart';

// V4 smoke runner 回归。
// 测试使用 fake driver 和临时 evidence，不访问真实手机或 Appium。
void main() {
  test(
    'smoke runner records screenshot and skips actions by default',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'ios-assist-smoke-runner-',
      );
      final driver = _FakeMobileDriver();
      final store = LocalRunEvidenceStore(rootDirectory: temp);

      try {
        final report = await MobileDriverSmokeRunner(
          driver: driver,
          evidenceStore: store,
        ).run(const MobileDriverSmokePlan());

        final runDirectory = Directory('${temp.path}/${report.runId}');
        final events = await _readEvents(runDirectory);
        final finished = await _readJson(
          File('${runDirectory.path}/finished.json'),
        );

        expect(report.status, 'success');
        expect(report.actionsExecuted, isFalse);
        expect(report.screenshotRef, 'screenshots/smoke-initial.png');
        expect(driver.calls, [
          'connect',
          'screenshot',
          'viewport',
          'logs',
          'disconnect',
        ]);
        expect(
          events.map((event) => event['type']),
          containsAllInOrder([
            'smokeStart',
            'smokeCapabilities',
            'smokeSession',
            'smokeScreenshot',
            'smokeActionsSkipped',
            'smokeLogs',
          ]),
        );
        expect(
          events
              .where((event) => event['type'] == 'smokeCapabilities')
              .single['appLifecycle'],
          isTrue,
        );
        expect(finished['status'], 'success');
        expect(
          await File(
            '${runDirectory.path}/screenshots/smoke-initial.png',
          ).exists(),
          isTrue,
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'smoke runner releases actions and records failed finish on action error',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'ios-assist-smoke-runner-',
      );
      final driver = _FakeMobileDriver(failTap: true);
      final store = LocalRunEvidenceStore(rootDirectory: temp);

      try {
        await expectLater(
          MobileDriverSmokeRunner(
            driver: driver,
            evidenceStore: store,
          ).run(const MobileDriverSmokePlan(allowActions: true)),
          throwsStateError,
        );

        final runDirectory = await _singleRunDirectory(temp);
        final events = await _readEvents(runDirectory);
        final finished = await _readJson(
          File('${runDirectory.path}/finished.json'),
        );

        expect(
          driver.calls,
          containsAllInOrder(['tap:195,422', 'release', 'disconnect']),
        );
        expect(finished['status'], 'failed');
        expect(
          events.map((event) => event['type']),
          containsAll(['smokeFailure', 'smokeActionRelease']),
        );
        expect(
          events
              .where((event) => event['type'] == 'smokeFailure')
              .single['message'],
          contains('tap failed'),
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'smoke runner executes a linear Project DSL workflow into evidence',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'ios-assist-smoke-runner-',
      );
      final driver = _FakeMobileDriver();
      final store = LocalRunEvidenceStore(rootDirectory: temp);

      try {
        final report =
            await MobileDriverSmokeRunner(
              driver: driver,
              evidenceStore: store,
            ).run(
              MobileDriverSmokePlan(
                allowActions: true,
                workflow: _linearSmokeWorkflow(),
                maxWait: Duration.zero,
              ),
            );

        final runDirectory = Directory('${temp.path}/${report.runId}');
        final events = await _readEvents(runDirectory);
        final workflowEvents = events
            .where((event) => event['type'] == 'smokeWorkflowStep')
            .toList(growable: false);

        expect(report.status, 'success');
        expect(driver.calls, containsAll(['tap:10,20', 'swipe', 'input:5']));
        expect(driver.calls.where((call) => call == 'release'), hasLength(3));
        expect(
          workflowEvents.map((event) => event['nodeId']),
          containsAllInOrder([
            'start',
            'snap',
            'tap',
            'wait',
            'swipe',
            'input',
            'end',
          ]),
        );
        expect(
          await File('${runDirectory.path}/screenshots/snap.png').exists(),
          isTrue,
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'smoke runner can generate a viewport based basic Project DSL workflow',
    () async {
      final temp = await Directory.systemTemp.createTemp(
        'ios-assist-smoke-runner-',
      );
      final driver = _FakeMobileDriver();
      final store = LocalRunEvidenceStore(rootDirectory: temp);

      try {
        final report =
            await MobileDriverSmokeRunner(
              driver: driver,
              evidenceStore: store,
            ).run(
              const MobileDriverSmokePlan(
                allowActions: true,
                useBasicWorkflow: true,
                maxWait: Duration.zero,
              ),
            );

        final runDirectory = Directory('${temp.path}/${report.runId}');
        final events = await _readEvents(runDirectory);
        final workflowEvents = events
            .where((event) => event['type'] == 'smokeWorkflowStep')
            .toList(growable: false);

        expect(report.status, 'success');
        expect(driver.calls, containsAll(['tap:195,422', 'swipe', 'input:16']));
        expect(
          workflowEvents.map((event) => event['nodeId']),
          containsAllInOrder([
            'start',
            'snapshot',
            'tap',
            'wait',
            'swipe',
            'input',
            'end',
          ]),
        );
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
}

// Fake mobile driver 记录调用顺序，用于验证 runner 生命周期和兜底。
final class _FakeMobileDriver implements MobileDeviceDriver {
  _FakeMobileDriver({this.failTap = false});

  final bool failTap;
  final calls = <String>[];
  var connected = false;

  @override
  MobilePlatform get platform => MobilePlatform.android;

  @override
  Future<MobileDriverCapabilityReport> capabilityReport() async {
    return const MobileDriverCapabilityReport(
      platform: MobilePlatform.android,
      screenshot: true,
      tap: true,
      swipe: true,
      input: true,
      pageSource: true,
      selectorTarget: true,
      imageTarget: false,
      ocrTarget: false,
      appLifecycle: true,
      logs: true,
      performance: false,
      remotePreview: false,
    );
  }

  @override
  Future<MobileDeviceSummary?> discoverCurrentDevice() async {
    return _device;
  }

  @override
  Future<MobileDriverSession> connect() async {
    calls.add('connect');
    connected = true;
    return const MobileDriverSession(
      sessionId: 'fake-session',
      platform: MobilePlatform.android,
      capabilities: MobileDriverCapabilityReport(
        platform: MobilePlatform.android,
        screenshot: true,
        tap: true,
        swipe: true,
        input: true,
        pageSource: true,
        selectorTarget: true,
        imageTarget: false,
        ocrTarget: false,
        appLifecycle: true,
        logs: true,
        performance: false,
        remotePreview: false,
      ),
      device: _device,
    );
  }

  @override
  Future<void> disconnect() async {
    calls.add('disconnect');
    connected = false;
  }

  @override
  Future<MobileDriverHeartbeat> heartbeat() async {
    return const MobileDriverHeartbeat(ready: true, message: 'ready');
  }

  @override
  Future<MobileScreenshot> captureScreenshot() async {
    calls.add('screenshot');
    return MobileScreenshot(
      base64Png: base64Encode([1, 2, 3, 4]),
      capturedAt: DateTime.now(),
      viewport: await _viewport(),
    );
  }

  @override
  Future<String?> getPageSource() async {
    return '<hierarchy />';
  }

  @override
  Future<void> tap(ViewportPoint point, {Duration? duration}) async {
    calls.add('tap:${point.x},${point.y}');
    if (failTap) throw StateError('tap failed');
  }

  @override
  Future<void> swipe(
    ViewportPoint from,
    ViewportPoint to, {
    Duration? duration,
  }) async {
    calls.add('swipe');
  }

  @override
  Future<void> inputText(String text) async {
    calls.add('input:${text.length}');
  }

  @override
  Future<void> launchApp(String appId) async {}

  @override
  Future<void> stopApp(String appId) async {}

  @override
  Future<void> pressHome() async {}

  @override
  Future<List<String>> collectLogs() async {
    calls.add('logs');
    return const ['W/App: log'];
  }

  @override
  Future<void> releaseActions() async {
    calls.add('release');
  }

  // 返回固定 viewport，并记录读取动作。
  Future<ViewportSize> _viewport() async {
    calls.add('viewport');
    return const ViewportSize(width: 390, height: 844);
  }

  static const _device = MobileDeviceSummary(
    platform: MobilePlatform.android,
    displayName: 'Pixel 9',
    maskedIdentifier: 'ZY22...CDEF',
    osVersion: '15',
    connectionKind: MobileConnectionKind.usb,
  );
}

// 读取 JSONL 事件文件。
Future<List<Map<String, Object?>>> _readEvents(Directory runDirectory) async {
  final file = File('${runDirectory.path}/events.jsonl');
  final lines = await file.readAsLines();
  return lines
      .where((line) => line.trim().isNotEmpty)
      .map((line) => jsonDecode(line) as Map<String, Object?>)
      .toList(growable: false);
}

// 读取单个 JSON 文件。
Future<Map<String, Object?>> _readJson(File file) async {
  return jsonDecode(await file.readAsString()) as Map<String, Object?>;
}

// 返回临时 evidence 根目录下唯一一次运行目录。
Future<Directory> _singleRunDirectory(Directory root) async {
  final runs = await root
      .list()
      .where((entity) => entity is Directory)
      .cast<Directory>()
      .toList();
  expect(runs, hasLength(1));
  return runs.single;
}

// 构造一条只含基础节点的线性 Project DSL 冒烟流程。
WorkflowDefinition _linearSmokeWorkflow() {
  return const WorkflowDefinition(
    id: 'linear-smoke',
    name: '线性冒烟',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['snap'],
      ),
      WorkflowNode(
        id: 'snap',
        type: WorkflowNodeType.snapshot,
        label: '截图',
        next: ['tap'],
      ),
      WorkflowNode(
        id: 'tap',
        type: WorkflowNodeType.tap,
        label: '点按',
        next: ['wait'],
        parameters: {'x': 10, 'y': 20},
      ),
      WorkflowNode(
        id: 'wait',
        type: WorkflowNodeType.wait,
        label: '等待',
        next: ['swipe'],
        parameters: {'ms': 20},
      ),
      WorkflowNode(
        id: 'swipe',
        type: WorkflowNodeType.swipe,
        label: '滑动',
        next: ['input'],
        parameters: {'fromX': 10, 'fromY': 20, 'toX': 10, 'toY': 80},
      ),
      WorkflowNode(
        id: 'input',
        type: WorkflowNodeType.input,
        label: '输入',
        next: ['end'],
        parameters: {'text': 'hello'},
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}
