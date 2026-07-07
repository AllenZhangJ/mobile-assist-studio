import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/workflow_dsl_test_harness.dart';

// Project DSL 模板与 Legacy 导入回归测试。
// 这些用例保证旧 A-F 序列可以稳定映射到 V2.0 Project DSL。
void main() {
  test('A-F template is valid and preserves required waits', () {
    final workflow = WorkflowDefinition.afTemplate();
    final result = workflowValidator.validate(workflow);

    expect(result.isValid, isTrue);
    expect(
      workflow.nodes.where((node) => node.type == WorkflowNodeType.tap),
      hasLength(6),
    );
    expect(
      workflow.nodes
          .where((node) => node.type == WorkflowNodeType.wait)
          .map((node) => node.parameters['ms']),
      orderedEquals([50, 50, 50, 4000, 50]),
    );
    expect(
      workflow.nodes
          .where((node) => node.type == WorkflowNodeType.tap)
          .map(
            (node) =>
                '${node.parameters['label']}:${node.parameters['x']},${node.parameters['y']}',
          ),
      orderedEquals([
        'A:92,499',
        'B:237,431',
        'C:237,431',
        'D:185,500',
        'E:186,600',
        'F:186,600',
      ]),
    );
  });

  test('imports legacy tap and wait sequence as linear workflow', () {
    final workflow = WorkflowDefinition.fromLegacySequence(
      id: 'legacy-sequence',
      name: 'Legacy Sequence',
      sequence: const [
        {'type': 'tap', 'label': 'A', 'x': 10, 'y': 20},
        {'type': 'wait', 'ms': 50},
        {'type': 'tap', 'label': 'B', 'x': 30, 'y': 40},
      ],
    );
    final validation = workflowValidator.validate(workflow);

    expect(validation.isValid, isTrue);
    expect(workflow.entryNodesId, 'start');
    expect(
      workflow.nodes.map(
        (node) => '${node.id}:${node.type.name}:${node.next.join(',')}',
      ),
      orderedEquals([
        'start:start:step_0',
        'step_0:tap:step_1',
        'step_1:wait:step_2',
        'step_2:tap:end',
        'end:end:',
      ]),
    );
    expect(workflow.nodes[1].parameters, {'label': 'A', 'x': 10, 'y': 20});
    expect(workflow.nodes[2].parameters, {'ms': 50});
  });
}
