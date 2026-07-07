import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/workflow_dsl_test_harness.dart';

// Project DSL 结构校验回归测试。
// 这里只覆盖图结构和通用元数据，不混入具体节点参数细节。
void main() {
  test('validator rejects missing node references', () {
    final workflow = WorkflowDefinition(
      id: 'broken',
      name: 'Broken workflow',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['missing'],
        ),
      ],
    );

    final result = workflowValidator.validate(workflow);
    expect(result.isValid, isFalse);
    expect(result.errors.single, contains('missing'));
  });

  test('validator rejects direct self references', () {
    const workflow = WorkflowDefinition(
      id: 'self-reference',
      name: 'Self Reference',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['wait_self'],
        ),
        WorkflowNode(
          id: 'wait_self',
          type: WorkflowNodeType.wait,
          label: '自环等待',
          next: ['wait_self'],
          parameters: {'ms': 100},
        ),
      ],
    );

    final result = workflowValidator.validate(workflow);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('Nodes wait_self cannot reference itself.'));
  });

  test('validator rejects catch onError self reference', () {
    const workflow = WorkflowDefinition(
      id: 'catch-self-reference',
      name: 'Catch Self Reference',
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
          label: '异常保护',
          next: ['end'],
          parameters: {'maxRetries': 1, 'onError': 'catch_1'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final result = workflowValidator.validate(workflow);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('Catch node catch_1 cannot reference itself onError.'),
    );
  });

  test('validator rejects partial visual node positions', () {
    final workflow = WorkflowDefinition(
      id: 'partial-layout',
      name: 'Partial Layout',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          visual: WorkflowNodeVisual(x: 48),
        ),
      ],
    );

    final result = workflowValidator.validate(workflow);

    expect(result.isValid, isFalse);
    expect(result.errors.single, contains('both x and y'));
  });

  test('validator rejects invalid entry and terminal structure', () {
    const workflow = WorkflowDefinition(
      id: 'bad-entry-terminal',
      name: 'Bad Entry Terminal',
      entryNodesId: 'tap_entry',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['tap_entry', 'end'],
        ),
        WorkflowNode(
          id: 'tap_entry',
          type: WorkflowNodeType.tap,
          label: '错误入口',
          next: ['end'],
          parameters: {'x': 10, 'y': 20},
        ),
        WorkflowNode(
          id: 'end',
          type: WorkflowNodeType.end,
          label: '结束',
          next: ['tap_entry'],
        ),
      ],
    );

    final result = workflowValidator.validate(workflow);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('Entry node tap_entry must be a Start node.'),
    );
    expect(
      result.errors,
      contains('Start node start can have only one main branch.'),
    );
    expect(
      result.errors,
      contains('End node end cannot have outgoing branches.'),
    );
  });
}
