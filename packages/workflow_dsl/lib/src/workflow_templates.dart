part of '../workflow_dsl.dart';

// _afTemplate 构建内置 A-F 基础工作流。
// 该模板保持旧 CLI 序列兼容，是 V2.0 的第一套基础模板。
WorkflowDefinition _afTemplate() {
  final nodes = <WorkflowNode>[
    const WorkflowNode(
      id: 'start',
      type: WorkflowNodeType.start,
      label: '开始',
      next: ['tap_a'],
    ),
    const WorkflowNode(
      id: 'tap_a',
      type: WorkflowNodeType.tap,
      label: '点击 A',
      next: ['wait_ab'],
      parameters: {'label': 'A', 'x': 92, 'y': 499},
    ),
    const WorkflowNode(
      id: 'wait_ab',
      type: WorkflowNodeType.wait,
      label: '等待 50ms',
      next: ['tap_b'],
      parameters: {'ms': 50},
    ),
    const WorkflowNode(
      id: 'tap_b',
      type: WorkflowNodeType.tap,
      label: '点击 B',
      next: ['wait_bc'],
      parameters: {'label': 'B', 'x': 237, 'y': 431},
    ),
    const WorkflowNode(
      id: 'wait_bc',
      type: WorkflowNodeType.wait,
      label: '等待 50ms',
      next: ['tap_c'],
      parameters: {'ms': 50},
    ),
    const WorkflowNode(
      id: 'tap_c',
      type: WorkflowNodeType.tap,
      label: '点击 C',
      next: ['wait_cd'],
      parameters: {'label': 'C', 'x': 237, 'y': 431},
    ),
    const WorkflowNode(
      id: 'wait_cd',
      type: WorkflowNodeType.wait,
      label: '等待 50ms',
      next: ['tap_d'],
      parameters: {'ms': 50},
    ),
    const WorkflowNode(
      id: 'tap_d',
      type: WorkflowNodeType.tap,
      label: '点击 D',
      next: ['wait_de'],
      parameters: {'label': 'D', 'x': 185, 'y': 500},
    ),
    const WorkflowNode(
      id: 'wait_de',
      type: WorkflowNodeType.wait,
      label: '等待 4000ms',
      next: ['tap_e'],
      parameters: {'ms': 4000},
    ),
    const WorkflowNode(
      id: 'tap_e',
      type: WorkflowNodeType.tap,
      label: '点击 E',
      next: ['wait_ef'],
      parameters: {'label': 'E', 'x': 186, 'y': 600},
    ),
    const WorkflowNode(
      id: 'wait_ef',
      type: WorkflowNodeType.wait,
      label: '等待 50ms',
      next: ['tap_f'],
      parameters: {'ms': 50},
    ),
    const WorkflowNode(
      id: 'tap_f',
      type: WorkflowNodeType.tap,
      label: '点击 F',
      next: ['end'],
      parameters: {'label': 'F', 'x': 186, 'y': 600},
    ),
    const WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
  ];
  return WorkflowDefinition(
    id: 'af-template',
    name: 'A-F 基础模板',
    entryNodesId: 'start',
    nodes: nodes,
  );
}

// _fromLegacySequence 把旧线性 sequence 包装为 Project DSL。
// 当前只兼容 tap 和 wait，复杂图必须走 V2.0 DSL。
WorkflowDefinition _fromLegacySequence({
  required String id,
  required String name,
  required List<Object?> sequence,
}) {
  final nodes = <WorkflowNode>[
    WorkflowNode(
      id: 'start',
      type: WorkflowNodeType.start,
      label: '开始',
      next: sequence.isEmpty ? const ['end'] : const ['step_0'],
    ),
  ];

  for (var index = 0; index < sequence.length; index += 1) {
    final rawStep = sequence[index];
    if (rawStep is! Map<String, Object?>) {
      throw ArgumentError('Legacy sequence step $index must be an object.');
    }
    final next = index == sequence.length - 1 ? 'end' : 'step_${index + 1}';
    final type = rawStep['type']?.toString();
    switch (type) {
      case 'tap':
        nodes.add(
          WorkflowNode(
            id: 'step_$index',
            type: WorkflowNodeType.tap,
            label: rawStep['label']?.toString() ?? 'Tap ${index + 1}',
            next: [next],
            parameters: <String, Object?>{
              'label': rawStep['label']?.toString() ?? 'Tap ${index + 1}',
              'x': _requiredInt(rawStep, 'x', index),
              'y': _requiredInt(rawStep, 'y', index),
            },
          ),
        );
      case 'wait':
        nodes.add(
          WorkflowNode(
            id: 'step_$index',
            type: WorkflowNodeType.wait,
            label: 'Wait ${_requiredInt(rawStep, 'ms', index)}ms',
            next: [next],
            parameters: <String, Object?>{
              'ms': _requiredInt(rawStep, 'ms', index),
            },
          ),
        );
      default:
        throw ArgumentError(
          'Unsupported legacy sequence step type at $index: $type.',
        );
    }
  }

  nodes.add(
    const WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
  );
  return WorkflowDefinition(
    id: id,
    name: name,
    entryNodesId: 'start',
    nodes: nodes,
  );
}
