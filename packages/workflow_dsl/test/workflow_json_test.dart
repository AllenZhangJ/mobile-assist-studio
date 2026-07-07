import 'package:test/test.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

import 'support/workflow_dsl_test_harness.dart';

// Project DSL JSON 解析与序列化回归测试。
// Source View、Workflow Store 和 Runtime 依赖这里保持同一真源格式。
void main() {
  test('serializes workflow definition as project DSL JSON', () {
    final workflow = WorkflowDefinition.afTemplate();
    final json = workflow.toJson();
    final nodes = json['nodes'];

    expect(json['id'], 'af-template');
    expect(json['entryNodesId'], 'start');
    expect(nodes, isA<List<Object?>>());
    final nodeList = nodes! as List<Object?>;
    expect(nodeList.first, {
      'id': 'start',
      'type': 'start',
      'label': '开始',
      'next': ['tap_a'],
    });
    expect(nodeList[1], {
      'id': 'tap_a',
      'type': 'tap',
      'label': '点击 A',
      'next': ['wait_ab'],
      'parameters': {'label': 'A', 'x': 92, 'y': 499},
    });
  });

  test('round trips workflow definition from project DSL JSON', () {
    final source = WorkflowDefinition.afTemplate();
    final restored = WorkflowDefinition.fromJson(source.toJson());

    expect(restored.id, source.id);
    expect(restored.name, source.name);
    expect(restored.entryNodesId, source.entryNodesId);
    expect(
      restored.nodes.map((node) => node.toJson()),
      source.nodes.map((node) => node.toJson()),
    );
    expect(workflowValidator.validate(restored).isValid, isTrue);
  });

  test('round trips visual node position metadata', () {
    const workflow = WorkflowDefinition(
      id: 'layout-workflow',
      name: 'Layout Workflow',
      entryNodesId: 'start',
      nodes: [
        WorkflowNode(
          id: 'start',
          type: WorkflowNodeType.start,
          label: '开始',
          next: ['tap_1'],
          visual: WorkflowNodeVisual(x: 48, y: 64),
        ),
        WorkflowNode(
          id: 'tap_1',
          type: WorkflowNodeType.tap,
          label: 'Tap',
          next: ['end'],
          parameters: {'x': 10, 'y': 20},
          visual: WorkflowNodeVisual(x: 160.5, y: 260.25),
        ),
        WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
      ],
    );

    final restored = WorkflowDefinition.fromJson(workflow.toJson());

    expect(restored.nodes[0].visual?.x, 48);
    expect(restored.nodes[0].visual?.y, 64);
    expect(restored.nodes[1].visual?.x, 160.5);
    expect(restored.nodes[1].visual?.y, 260.25);
    expect(workflowValidator.validate(restored).isValid, isTrue);
  });

  test('rejects unsupported workflow node type from JSON', () {
    expect(
      () => WorkflowDefinition.fromJson({
        'id': 'bad',
        'name': 'Bad Workflow',
        'entryNodesId': 'start',
        'nodes': [
          {'id': 'start', 'type': 'script', 'label': 'Script'},
        ],
      }),
      throwsFormatException,
    );
  });
}
