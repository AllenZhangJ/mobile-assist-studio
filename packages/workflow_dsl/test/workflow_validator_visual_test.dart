import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/workflow_dsl_test_harness.dart';

// Project DSL 视觉节点校验回归测试。
// 视觉节点只允许一个成功分支，低置信处理归 Runtime 挂起语义。
void main() {
  test('validator checks visual branch confidence boundaries', () {
    const validWorkflow = WorkflowDefinition(
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
          label: 'Visual',
          next: ['end'],
          parameters: {'confidenceThreshold': 0.8},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const invalidWorkflow = WorkflowDefinition(
      id: 'bad-visual-workflow',
      name: 'Bad Visual Workflow',
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
          label: 'Visual',
          next: ['a', 'b'],
          parameters: {'confidenceThreshold': 1.2},
        ),
        WorkflowNode(id: 'a', type: WorkflowNodeType.end, label: 'A'),
        WorkflowNode(id: 'b', type: WorkflowNodeType.end, label: 'B'),
      ],
    );

    final validResult = workflowValidator.validate(validWorkflow);
    expect(validResult.isValid, isTrue, reason: validResult.errors.join('\n'));

    final result = workflowValidator.validate(invalidWorkflow);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains(
        'Visual Branch node visual_1 confidenceThreshold must be between 0 and 1.',
      ),
    );
    expect(
      result.errors,
      contains('Visual Branch node visual_1 can have only one success branch.'),
    );
  });

  test('validator checks visual branch targetRef shape', () {
    final valid = WorkflowDefinition(
      id: 'visual-target-ref',
      name: 'Visual Target Ref',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['visual'],
        ),
        WorkflowNode(
          id: 'visual',
          type: WorkflowNodeType.visualBranch,
          label: '找目标',
          parameters: {'targetRef': 'login_button'},
          next: ['end'],
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final invalid = WorkflowDefinition(
      id: 'visual-target-ref-invalid',
      name: 'Visual Target Ref Invalid',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['visual'],
        ),
        WorkflowNode(
          id: 'visual',
          type: WorkflowNodeType.visualBranch,
          label: '找目标',
          parameters: {'targetRef': '../bad'},
          next: ['end'],
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    expect(workflowValidator.validate(valid).isValid, isTrue);
    expect(
      workflowValidator.validate(invalid).errors,
      contains('Node visual targetRef is invalid.'),
    );
  });

  test('validator checks wait for target parameters', () {
    final valid = WorkflowDefinition(
      id: 'wait-target',
      name: 'Wait Target',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['wait_target'],
        ),
        WorkflowNode(
          id: 'wait_target',
          type: WorkflowNodeType.waitForTarget,
          label: '等目标',
          parameters: {
            'targetRef': 'login_button',
            'timeoutMs': 5000,
            'intervalMs': 500,
            'confidenceThreshold': 0.8,
          },
          next: ['end'],
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    final invalid = WorkflowDefinition(
      id: 'wait-target-invalid',
      name: 'Wait Target Invalid',
      entryNodesId: 'start',
      nodes: const [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['wait_target'],
        ),
        WorkflowNode(
          id: 'wait_target',
          type: WorkflowNodeType.waitForTarget,
          label: '等目标',
          parameters: {
            'timeoutMs': 0,
            'intervalMs': 100,
            'confidenceThreshold': 2,
          },
          next: ['a', 'b'],
        ),
        WorkflowNode(id: 'a', type: WorkflowNodeType.end, label: 'A'),
        WorkflowNode(id: 'b', type: WorkflowNodeType.end, label: 'B'),
      ],
    );

    expect(workflowValidator.validate(valid).isValid, isTrue);

    final result = workflowValidator.validate(invalid);

    expect(result.isValid, isFalse);
    expect(result.errors, contains('Node wait_target targetRef is required.'));
    expect(
      result.errors,
      contains(
        'Wait For Target node wait_target confidenceThreshold must be between 0 and 1.',
      ),
    );
    expect(
      result.errors,
      contains(
        'Wait For Target node wait_target timeoutMs must be an integer from 1 to 600000.',
      ),
    );
    expect(
      result.errors,
      contains(
        'Wait For Target node wait_target intervalMs must not exceed timeoutMs.',
      ),
    );
    expect(
      result.errors,
      contains(
        'Wait For Target node wait_target can have only one main branch.',
      ),
    );
  });
}
