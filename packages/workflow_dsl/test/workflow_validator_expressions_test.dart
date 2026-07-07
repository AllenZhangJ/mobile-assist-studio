import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/workflow_dsl_test_harness.dart';

// Project DSL 表达式白名单回归测试。
// 子流程入参和条件表达式都只能读取安全 context 字段。
void main() {
  test('validator guards sub workflow input map expressions', () {
    const validWorkflow = WorkflowDefinition(
      id: 'sub-input-valid',
      name: 'Sub Input Valid',
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
          label: '子流程',
          next: ['end'],
          parameters: {
            'workflowId': 'child',
            'inputMap': {'ready': 'context.loopNumber'},
          },
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final valid = workflowValidator.validate(validWorkflow);
    expect(valid.isValid, isTrue);

    const invalidWorkflow = WorkflowDefinition(
      id: 'sub-input-invalid',
      name: 'Sub Input Invalid',
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
          label: '子流程',
          next: ['end'],
          parameters: {
            'workflowId': 'child',
            'inputMap': {'1bad': 'context.loopNumber', 'unsafe': 'eval()'},
          },
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final invalid = workflowValidator.validate(invalidWorkflow);

    expect(invalid.isValid, isFalse);
    expect(
      invalid.errors,
      contains('Sub Workflow node sub_1 inputMap key 1bad is invalid.'),
    );
    expect(
      invalid.errors,
      contains(
        'Sub Workflow node sub_1 inputMap value for unsafe must read context.',
      ),
    );
  });

  test('validator accepts safe condition expression and two branches', () {
    const workflow = WorkflowDefinition(
      id: 'condition-workflow',
      name: 'Condition Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['condition_1'],
        ),
        WorkflowNode(
          id: 'condition_1',
          type: WorkflowNodeType.condition,
          label: 'Condition',
          next: ['true_path', 'false_path'],
          parameters: {'expression': 'context.execution.loopNumber'},
        ),
        WorkflowNode(
          id: 'true_path',
          type: WorkflowNodeType.wait,
          label: 'True',
          next: ['end'],
          parameters: {'ms': 1},
        ),
        WorkflowNode(
          id: 'false_path',
          type: WorkflowNodeType.wait,
          label: 'False',
          next: ['end'],
          parameters: {'ms': 1},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    expect(isSafeContextExpression('context.execution.loopNumber'), isTrue);
    expect(workflowValidator.validate(workflow).isValid, isTrue);
  });

  test('validator rejects unsafe condition expression and excess branches', () {
    const workflow = WorkflowDefinition(
      id: 'unsafe-condition-workflow',
      name: 'Unsafe Condition Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['condition_1'],
        ),
        WorkflowNode(
          id: 'condition_1',
          type: WorkflowNodeType.condition,
          label: 'Condition',
          next: ['a', 'b', 'c'],
          parameters: {'expression': 'Date.now()'},
        ),
        WorkflowNode(id: 'a', type: WorkflowNodeType.end, label: 'A'),
        WorkflowNode(id: 'b', type: WorkflowNodeType.end, label: 'B'),
        WorkflowNode(id: 'c', type: WorkflowNodeType.end, label: 'C'),
      ],
    );

    expect(isSafeContextExpression('Date.now()'), isFalse);
    final result = workflowValidator.validate(workflow);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('Unsafe condition expression in node condition_1.'),
    );
    expect(
      result.errors,
      contains('Condition node condition_1 can have at most two branches.'),
    );
  });
}
