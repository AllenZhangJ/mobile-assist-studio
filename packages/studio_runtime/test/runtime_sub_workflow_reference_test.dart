// ignore_for_file: unused_import, unnecessary_import

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/runtime_test_harness.dart';

// Runtime 子流程引用校验测试。
// 用例只验证引用图完整性，不启动 Runtime 执行。
void main() {
  // 验证引用校验能发现缺失子流程和自引用。
  test('workflow reference validator reports missing and self references', () {
    const workflow = WorkflowDefinition(
      id: 'self-parent',
      name: '引用检查',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['missing'],
        ),
        WorkflowNode(
          id: 'missing',
          type: WorkflowNodeType.subWorkflow,
          label: '缺失',
          next: ['self'],
          parameters: {'workflowId': 'missing-child'},
        ),
        WorkflowNode(
          id: 'self',
          type: WorkflowNodeType.subWorkflow,
          label: '自己',
          next: ['end'],
          parameters: {'workflowId': 'self-parent'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final issues = WorkflowReferenceValidator.validate(
      workflow,
      availableSubWorkflowIds: const {'known-child'},
    );

    expect(issues, hasLength(2));
    expect(issues.first.nodeId, 'missing');
    expect(issues.first.message, contains('missing workflow missing-child'));
    expect(issues.first.displayMessage, contains('不存在的子流程'));
    expect(issues.last.nodeId, 'self');
    expect(issues.last.message, contains('cannot reference itself'));
    expect(issues.last.displayMessage, contains('不能引用自己'));
  });

  // 验证引用校验能发现直接循环引用。
  test('workflow reference validator reports recursive references', () {
    const workflow = WorkflowDefinition(
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

    final issues = WorkflowReferenceValidator.validate(
      workflow,
      availableSubWorkflowIds: const {'child-a', 'child-b'},
      referencesByWorkflowId: const {
        'child-b': {'child-a'},
      },
    );

    expect(issues, hasLength(1));
    expect(issues.single.nodeId, 'sub');
    expect(issues.single.workflowId, 'child-b');
    expect(issues.single.message, contains('recursive workflow reference'));
    expect(issues.single.displayMessage, contains('循环引用'));
  });

  // 验证引用校验能发现子流程链上的间接缺失。
  test('workflow reference validator reports missing nested references', () {
    const workflow = WorkflowDefinition(
      id: 'main',
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

    final issues = WorkflowReferenceValidator.validate(
      workflow,
      availableSubWorkflowIds: const {'child-a'},
      referencesByWorkflowId: const {
        'child-a': {'missing-child'},
      },
    );

    expect(issues, hasLength(1));
    expect(issues.single.nodeId, 'sub');
    expect(issues.single.workflowId, 'child-a');
    expect(issues.single.message, contains('missing nested workflow'));
    expect(issues.single.displayMessage, contains('子流程链缺少'));
  });
}
