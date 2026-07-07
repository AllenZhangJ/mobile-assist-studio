import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/workflow_dsl_test_harness.dart';

// Project DSL 控制节点校验回归测试。
// Catch、Sub Workflow 和 Loop 是流程编排核心，分支数量必须受控。
void main() {
  test('validator checks catch onError and retry boundaries', () {
    const validWorkflow = WorkflowDefinition(
      id: 'catch-workflow',
      name: 'Catch Workflow',
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
          label: 'Catch',
          next: ['main'],
          parameters: {'maxRetries': 1, 'onError': 'recover'},
        ),
        WorkflowNode(
          id: 'main',
          type: WorkflowNodeType.wait,
          label: 'Main',
          next: ['end'],
          parameters: {'ms': 1},
        ),
        WorkflowNode(
          id: 'recover',
          type: WorkflowNodeType.wait,
          label: 'Recover',
          next: ['end'],
          parameters: {'ms': 1},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const invalidWorkflow = WorkflowDefinition(
      id: 'bad-catch-workflow',
      name: 'Bad Catch Workflow',
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
          label: 'Catch',
          next: ['main', 'extra'],
          parameters: {'maxRetries': -1, 'onError': 'missing'},
        ),
        WorkflowNode(
          id: 'main',
          type: WorkflowNodeType.wait,
          label: 'Main',
          parameters: {'ms': 1},
        ),
        WorkflowNode(
          id: 'extra',
          type: WorkflowNodeType.wait,
          label: 'Extra',
          parameters: {'ms': 1},
        ),
      ],
    );

    final validResult = workflowValidator.validate(validWorkflow);
    expect(validResult.isValid, isTrue, reason: validResult.errors.join('\n'));

    final result = workflowValidator.validate(invalidWorkflow);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('Catch node catch_1 maxRetries must be non-negative.'),
    );
    expect(
      result.errors,
      contains('Catch node catch_1 can have only one main branch.'),
    );
    expect(
      result.errors,
      contains('Catch node catch_1 references missing onError node.'),
    );
  });

  test('validator checks sub workflow id and branch boundaries', () {
    const validWorkflow = WorkflowDefinition(
      id: 'sub-workflow-host',
      name: 'Sub Workflow Host',
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
          label: 'Run Nested',
          next: ['end'],
          parameters: {'workflowId': 'nested'},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const invalidWorkflow = WorkflowDefinition(
      id: 'bad-sub-workflow-host',
      name: 'Bad Sub Workflow Host',
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
          label: 'Run Nested',
          next: ['a', 'b'],
          parameters: {'workflowId': ''},
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
      contains('Sub Workflow node sub_1 workflowId is required.'),
    );
    expect(
      result.errors,
      contains('Sub Workflow node sub_1 can have only one main branch.'),
    );
  });

  test('validator checks bounded loop parameters and branches', () {
    const validWorkflow = WorkflowDefinition(
      id: 'loop-workflow',
      name: 'Loop Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['loop_1'],
        ),
        WorkflowNode(
          id: 'loop_1',
          type: WorkflowNodeType.loop,
          label: 'Loop Twice',
          next: ['wait_body', 'end'],
          parameters: {'count': 2},
        ),
        WorkflowNode(
          id: 'wait_body',
          type: WorkflowNodeType.wait,
          label: 'Body Wait',
          next: ['loop_1'],
          parameters: {'ms': 10},
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );
    const invalidWorkflow = WorkflowDefinition(
      id: 'bad-loop-workflow',
      name: 'Bad Loop Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['loop_bad'],
        ),
        WorkflowNode(
          id: 'loop_bad',
          type: WorkflowNodeType.loop,
          label: 'Loop Bad',
          next: ['a', 'b', 'c'],
          parameters: {'count': -1},
        ),
        WorkflowNode(id: 'a', type: WorkflowNodeType.end, label: 'A'),
        WorkflowNode(id: 'b', type: WorkflowNodeType.end, label: 'B'),
        WorkflowNode(id: 'c', type: WorkflowNodeType.end, label: 'C'),
      ],
    );

    final validResult = workflowValidator.validate(validWorkflow);
    expect(validResult.isValid, isTrue, reason: validResult.errors.join('\n'));

    final result = workflowValidator.validate(invalidWorkflow);

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('Loop node loop_bad count must be an integer from 0 to 1000.'),
    );
    expect(
      result.errors,
      contains('Loop node loop_bad can have at most two branches.'),
    );
  });
}
