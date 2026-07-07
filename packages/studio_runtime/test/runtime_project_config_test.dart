// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 项目配置恢复和 legacy 导入测试。
// 用例确认持久化 Project DSL 优先于旧 sequence 配置。
void main() {
  // 验证项目配置优先恢复已持久化 workflow。
  test(
    'project config restores persisted workflow before legacy sequence',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'project-workflow-',
      );
      final configDirectory = Directory('${directory.path}/config');
      await configDirectory.create(recursive: true);
      final configFile = File(
        '${configDirectory.path}/connected-device.sequence.json',
      );
      await configFile.writeAsString(
        jsonEncode({
          'appium': {
            'capabilities': {
              'platformName': 'iOS',
              'appium:automationName': 'XCUITest',
            },
          },
          'sequence': [
            {'type': 'tap', 'label': 'Legacy A', 'x': 1, 'y': 2},
          ],
        }),
      );
      final persistedWorkflow = const WorkflowDefinition(
        id: 'persisted',
        name: 'Persisted Workflow',
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
      await LocalWorkflowStore(
        file: File('${directory.path}/workflows/current.workflow.json'),
      ).saveWorkflow(persistedWorkflow);

      final config = StudioProjectConfig.load(configFile.path);
      final controller = StudioRuntimeController.fromProjectConfig(config);
      await controller.dispose();
      await directory.delete(recursive: true);

      expect(controller.snapshot.workflow.name, 'Persisted Workflow');
    },
  );

  // 验证项目配置能恢复已持久化子流程。
  test('project config restores persisted sub workflows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'project-sub-workflows-',
    );
    final configDirectory = Directory('${directory.path}/config');
    await configDirectory.create(recursive: true);
    final configFile = File(
      '${configDirectory.path}/connected-device.sequence.json',
    );
    await configFile.writeAsString(
      jsonEncode({
        'appium': {
          'capabilities': {
            'platformName': 'iOS',
            'appium:automationName': 'XCUITest',
          },
        },
        'sequence': [
          {'type': 'tap', 'label': 'Legacy A', 'x': 1, 'y': 2},
        ],
      }),
    );
    const child = WorkflowDefinition(
      id: 'saved-child',
      name: '已保存子流程',
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
          parameters: {'ms': 120},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    await LocalSubWorkflowStore(
      file: File('${directory.path}/workflows/sub.workflows.json'),
    ).saveSubWorkflows(const {'saved-child': child});

    final config = StudioProjectConfig.load(configFile.path);
    final controller = StudioRuntimeController.fromProjectConfig(config);
    await controller.dispose();
    await directory.delete(recursive: true);

    expect(controller.snapshot.subWorkflows, hasLength(1));
    expect(controller.snapshot.subWorkflows.single.workflowId, 'saved-child');
    expect(controller.snapshot.subWorkflows.single.name, '已保存子流程');
    expect(controller.snapshot.subWorkflows.single.isValid, isTrue);
  });

  // 验证找不到项目配置时返回脱敏的专用原因。
  test('project config discovery reports missing config', () async {
    final directory = await Directory.systemTemp.createTemp(
      'project-config-missing-',
    );

    expect(
      () => StudioProjectConfig.discoverFrom(startDirectories: [directory]),
      throwsA(
        isA<StudioProjectConfigDiscoveryException>()
            .having(
              (error) => error.reason,
              'reason',
              StudioProjectConfigDiscoveryReason.notFound,
            )
            .having(
              (error) => error.toString(),
              'message',
              isNot(contains('/')),
            ),
      ),
    );

    await directory.delete(recursive: true);
  });

  // 验证配置位置存在但不可读时返回权限类原因。
  test('project config discovery reports unreadable config', () async {
    final directory = await Directory.systemTemp.createTemp(
      'project-config-unreadable-',
    );
    await Directory(
      '${directory.path}/config/connected-device.sequence.json',
    ).create(recursive: true);

    expect(
      () => StudioProjectConfig.discoverFrom(startDirectories: [directory]),
      throwsA(
        isA<StudioProjectConfigDiscoveryException>().having(
          (error) => error.reason,
          'reason',
          StudioProjectConfigDiscoveryReason.notReadable,
        ),
      ),
    );

    await directory.delete(recursive: true);
  });

  // 验证 legacy 配置可导入 Appium、capability 和 A-F 序列。
  test('project config imports Appium endpoint, capabilities and sequence', () {
    final config = StudioProjectConfig.fromJson({
      'appium': {
        'hostname': '127.0.0.1',
        'port': 7777,
        'path': '/',
        'connectionRetryTimeout': 123000,
        'executable': '/tmp/appium',
        'serverLogLevel': 'warn',
        'capabilities': {
          'platformName': 'iOS',
          'appium:automationName': 'XCUITest',
          'appium:deviceName': 'iPhone',
          'appium:platformVersion': '18.1',
          'appium:udid': 'REDACTED_DEVICE_ID',
          'appium:noReset': true,
        },
      },
      'run': {'tapDurationMs': 123},
      'sequence': [
        {'type': 'tap', 'label': 'A', 'x': 10, 'y': 20},
        {'type': 'wait', 'ms': 50},
        {'type': 'tap', 'label': 'B', 'x': 30, 'y': 40},
      ],
    });

    expect(config.appiumServer.port, 7777);
    expect(config.appiumServer.timeout, const Duration(milliseconds: 123000));
    expect(config.appiumProcess.executable, '/tmp/appium');
    expect(config.appiumProcess.logLevel, 'warn');
    expect(config.deviceSession.requiresAppiumTunnel, isTrue);
    expect(config.tapDurationMs, 123);
    final request = config.deviceSession.toSessionRequest().toJson();
    final capabilities =
        (request['capabilities'] as Map<String, Object?>)['alwaysMatch']
            as Map<String, Object?>;
    expect(capabilities['appium:udid'], 'REDACTED_DEVICE_ID');
    expect(
      config.workflow.nodes
          .where((node) => node.type == WorkflowNodeType.tap)
          .map(
            (node) =>
                '${node.parameters['label']}:${node.parameters['x']},${node.parameters['y']}',
          ),
      orderedEquals(['A:10,20', 'B:30,40']),
    );
  });

  // 验证从深层启动目录发现项目配置后使用项目内 Appium。
  test('project config discovery resolves local Appium executable', () async {
    final directory = await Directory.systemTemp.createTemp(
      'project-config-discovery-',
    );
    final configDirectory = Directory('${directory.path}/config');
    final nestedDirectory = Directory(
      '${directory.path}/apps/studio_mac/build/macos/Build/Products/Debug',
    );
    final appiumFile = File('${directory.path}/node_modules/.bin/appium');
    await configDirectory.create(recursive: true);
    await nestedDirectory.create(recursive: true);
    await appiumFile.parent.create(recursive: true);
    await appiumFile.writeAsString('#!/usr/bin/env node\n');
    final configFile = File(
      '${configDirectory.path}/connected-device.sequence.json',
    );
    await configFile.writeAsString(
      jsonEncode({
        'appium': {
          'hostname': '127.0.0.1',
          'port': 4723,
          'capabilities': {
            'platformName': 'iOS',
            'appium:automationName': 'XCUITest',
          },
        },
        'sequence': [
          {'type': 'tap', 'label': 'A', 'x': 1, 'y': 2},
        ],
      }),
    );

    final config = StudioProjectConfig.discoverFrom(
      startDirectories: [nestedDirectory],
    );
    await directory.delete(recursive: true);

    expect(config.sourcePath, configFile.absolute.path);
    expect(config.appiumProcess.executable, appiumFile.absolute.path);
  });
}
