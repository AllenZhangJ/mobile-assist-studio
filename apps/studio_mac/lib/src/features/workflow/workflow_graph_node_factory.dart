part of '../../studio_mac_workspace.dart';

// Workflow 节点工厂 helper，负责新增节点和唯一 ID 生成。

// 按节点类型创建默认插入节点。
WorkflowNode _newNodesForInsert(
  WorkflowDefinition workflow,
  WorkflowNodeType type,
) {
  return switch (type) {
    WorkflowNodeType.tap => WorkflowNode(
      id: _uniqueNodesId(workflow, 'tap'),
      type: WorkflowNodeType.tap,
      label: '新点击',
      parameters: const <String, Object?>{'label': '新点击', 'x': 0, 'y': 0},
    ),
    WorkflowNodeType.wait => WorkflowNode(
      id: _uniqueNodesId(workflow, 'wait'),
      type: WorkflowNodeType.wait,
      label: '等 500ms',
      parameters: const <String, Object?>{'ms': 500},
    ),
    WorkflowNodeType.swipe => WorkflowNode(
      id: _uniqueNodesId(workflow, 'swipe'),
      type: WorkflowNodeType.swipe,
      label: '上滑',
      parameters: const <String, Object?>{
        'label': '上滑',
        'fromX': 200,
        'fromY': 700,
        'toX': 200,
        'toY': 300,
        'durationMs': 450,
      },
    ),
    WorkflowNodeType.input => WorkflowNode(
      id: _uniqueNodesId(workflow, 'input'),
      type: WorkflowNodeType.input,
      label: '输入文本',
      parameters: const <String, Object?>{'label': '输入文本', 'text': '演示文本'},
    ),
    WorkflowNodeType.loop => WorkflowNode(
      id: _uniqueNodesId(workflow, 'loop'),
      type: WorkflowNodeType.loop,
      label: '重复',
      parameters: const <String, Object?>{'count': 2},
    ),
    WorkflowNodeType.snapshot => WorkflowNode(
      id: _uniqueNodesId(workflow, 'snapshot'),
      type: WorkflowNodeType.snapshot,
      label: '截图',
      parameters: const <String, Object?>{'saveEvidence': true},
    ),
    WorkflowNodeType.condition => WorkflowNode(
      id: _uniqueNodesId(workflow, 'condition'),
      type: WorkflowNodeType.condition,
      label: '条件',
      parameters: const <String, Object?>{'expression': 'context.flag'},
    ),
    WorkflowNodeType.visualBranch => WorkflowNode(
      id: _uniqueNodesId(workflow, 'visual_branch'),
      type: WorkflowNodeType.visualBranch,
      label: '看图',
      parameters: const <String, Object?>{'confidenceThreshold': 0.8},
    ),
    WorkflowNodeType.waitForTarget => WorkflowNode(
      id: _uniqueNodesId(workflow, 'wait_target'),
      type: WorkflowNodeType.waitForTarget,
      label: '等目标',
      parameters: const <String, Object?>{
        'targetRef': 'target_1',
        'timeoutMs': 5000,
        'intervalMs': 500,
        'confidenceThreshold': 0.8,
      },
    ),
    WorkflowNodeType.catchNodes => WorkflowNode(
      id: _uniqueNodesId(workflow, 'catch'),
      type: WorkflowNodeType.catchNodes,
      label: '兜底',
      parameters: const <String, Object?>{'maxRetries': 1},
    ),
    WorkflowNodeType.subWorkflow => WorkflowNode(
      id: _uniqueNodesId(workflow, 'sub_workflow'),
      type: WorkflowNodeType.subWorkflow,
      label: '子流程',
      parameters: const <String, Object?>{'workflowId': 'local-workflow'},
    ),
    _ => throw ArgumentError('不支持该节点：${type.name}。'),
  };
}

// 在当前 workflow 内生成唯一节点 ID。
String _uniqueNodesId(WorkflowDefinition workflow, String prefix) {
  final existing = workflow.nodes.map((node) => node.id).toSet();
  return _uniqueNodesIdWithReserved(existing, prefix);
}

// 在预留集合内生成唯一节点 ID。
String _uniqueNodesIdWithReserved(Set<String> reservedNodesIds, String prefix) {
  var index = 1;
  while (reservedNodesIds.contains('${prefix}_new_$index')) {
    index += 1;
  }
  return '${prefix}_new_$index';
}
