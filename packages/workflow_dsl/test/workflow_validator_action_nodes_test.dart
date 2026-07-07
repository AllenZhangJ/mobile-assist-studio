import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/workflow_dsl_test_harness.dart';

// Project DSL 动作节点校验回归测试。
// 动作节点必须提供可执行参数，并保持单主线出口。
void main() {
  test('validator checks tap wait and snapshot executable parameters', () {
    const validWorkflow = WorkflowDefinition(
      id: 'basic-actions',
      name: 'Basic Actions',
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
          parameters: {'x': 10, 'y': 20, 'durationMs': 80},
        ),
        WorkflowNode(
          id: 'wait_1',
          type: WorkflowNodeType.wait,
          label: 'Wait',
          next: ['snapshot_1'],
          parameters: {'ms': 300},
        ),
        WorkflowNode(
          id: 'snapshot_1',
          type: WorkflowNodeType.snapshot,
          label: 'Snapshot',
          next: ['end'],
          parameters: {'saveEvidence': true},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const invalidWorkflow = WorkflowDefinition(
      id: 'bad-basic-actions',
      name: 'Bad Basic Actions',
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
          next: ['wait_1', 'end'],
          parameters: {'x': 0.5, 'durationMs': -1},
        ),
        WorkflowNode(
          id: 'wait_1',
          type: WorkflowNodeType.wait,
          label: 'Wait',
          next: ['snapshot_1', 'end'],
          parameters: {'ms': -10},
        ),
        WorkflowNode(
          id: 'snapshot_1',
          type: WorkflowNodeType.snapshot,
          label: 'Snapshot',
          next: ['end', 'tap_1'],
          parameters: {'saveEvidence': 'yes'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final validResult = workflowValidator.validate(validWorkflow);
    expect(validResult.isValid, isTrue, reason: validResult.errors.join('\n'));

    final result = workflowValidator.validate(invalidWorkflow);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('Tap node tap_1 x must be an integer.'));
    expect(result.errors, contains('Tap node tap_1 y must be an integer.'));
    expect(
      result.errors,
      contains('Tap node tap_1 durationMs must be non-negative.'),
    );
    expect(
      result.errors,
      contains('Tap node tap_1 can have only one main branch.'),
    );
    expect(
      result.errors,
      contains('Wait node wait_1 ms must be non-negative.'),
    );
    expect(
      result.errors,
      contains('Wait node wait_1 can have only one main branch.'),
    );
    expect(
      result.errors,
      contains('Snapshot node snapshot_1 saveEvidence must be a boolean.'),
    );
    expect(
      result.errors,
      contains('Snapshot node snapshot_1 can have only one main branch.'),
    );
  });

  test('validator checks swipe and input executable parameters', () {
    const validWorkflow = WorkflowDefinition(
      id: 'gesture-input',
      name: 'Gesture Input',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['input_1'],
        ),
        WorkflowNode(
          id: 'input_1',
          type: WorkflowNodeType.input,
          label: 'Type Query',
          next: ['swipe_1'],
          parameters: {'text': 'hello'},
        ),
        WorkflowNode(
          id: 'swipe_1',
          type: WorkflowNodeType.swipe,
          label: 'Swipe Up',
          next: ['end'],
          parameters: {
            'fromX': 200,
            'fromY': 700,
            'toX': 200,
            'toY': 300,
            'durationMs': 450,
          },
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const invalidWorkflow = WorkflowDefinition(
      id: 'bad-gesture-input',
      name: 'Bad Gesture Input',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['input_1'],
        ),
        WorkflowNode(
          id: 'input_1',
          type: WorkflowNodeType.input,
          label: 'Type Query',
          next: ['swipe_1', 'end'],
          parameters: {},
        ),
        WorkflowNode(
          id: 'swipe_1',
          type: WorkflowNodeType.swipe,
          label: 'Swipe Up',
          next: ['end'],
          parameters: {
            'fromX': 200,
            'fromY': 'bad',
            'toX': 200,
            'durationMs': -1,
          },
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final validResult = workflowValidator.validate(validWorkflow);
    expect(validResult.isValid, isTrue, reason: validResult.errors.join('\n'));

    final result = workflowValidator.validate(invalidWorkflow);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('Input node input_1 text is required.'));
    expect(
      result.errors,
      contains('Input node input_1 can have only one main branch.'),
    );
    expect(
      result.errors,
      contains('Swipe node swipe_1 fromY must be an integer.'),
    );
    expect(
      result.errors,
      contains('Swipe node swipe_1 toY must be an integer.'),
    );
    expect(
      result.errors,
      contains('Swipe node swipe_1 durationMs must be non-negative.'),
    );
  });

  test('validator allows tap targetRef without raw coordinates', () {
    const workflow = WorkflowDefinition(
      id: 'tap-target-ref',
      name: 'Tap Target Ref',
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
          label: 'Tap Target',
          next: ['end'],
          parameters: {'targetRef': 'login_button', 'confidenceThreshold': 0.9},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const invalidWorkflow = WorkflowDefinition(
      id: 'bad-tap-target-ref',
      name: 'Bad Tap Target Ref',
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
          label: 'Tap Target',
          next: ['end'],
          parameters: {'targetRef': 'bad target', 'confidenceThreshold': 1.2},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final result = workflowValidator.validate(workflow);
    final invalidResult = workflowValidator.validate(invalidWorkflow);

    expect(result.isValid, isTrue, reason: result.errors.join('\n'));
    expect(invalidResult.isValid, isFalse);
    expect(invalidResult.errors, contains('Node tap_1 targetRef is invalid.'));
    expect(
      invalidResult.errors,
      contains('Tap node tap_1 confidenceThreshold must be between 0 and 1.'),
    );
  });
}
