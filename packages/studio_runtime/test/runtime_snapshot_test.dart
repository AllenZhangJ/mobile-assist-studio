// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 初始快照和只读摘要回归。
// 每个文件只覆盖一个 Runtime 子域，保持失败定位清晰。
void main() {
  test('initial runtime snapshot is disconnected, idle and workflow-valid', () {
    final snapshot = StudioRuntimeSnapshot.initial();

    expect(snapshot.connectionStatus, ConnectionStatus.disconnected);
    expect(snapshot.runStatus, RunStatus.idle);
    expect(snapshot.workflowIsValid, isTrue);
    expect(snapshot.workflow.name, 'A-F 基础模板');
    expect(snapshot.settings.evidenceMaxRuns, 20);
    expect(snapshot.settings.evidenceMaxAgeDays, 7);
    expect(snapshot.events, isNotEmpty);
  });

  test('runtime snapshot exposes registered sub workflow summaries', () {
    final controller = StudioRuntimeController(
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
              next: ['end'],
            ),
            WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
          ],
        ),
      },
    );

    final summary = controller.snapshot.subWorkflows.single;
    expect(summary.workflowId, 'nested');
    expect(summary.name, '子流程');
    expect(summary.nodeCount, 2);
    expect(summary.isValid, isTrue);
  });
}
