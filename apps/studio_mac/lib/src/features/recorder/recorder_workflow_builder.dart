part of '../../studio_mac_workspace.dart';

// Recorder Workflow Builder，负责把本地录制动作转换为 Project DSL。
// 模型文件只描述录制动作本身，DSL 写入细节集中在这里维护。

// 将录制动作线性转换为 Project DSL workflow。
WorkflowDefinition _workflowFromRecordedActions(
  List<_RecordedActions> actions,
) {
  final nodes = <WorkflowNode>[];
  final firstNodesId = actions.isEmpty ? 'end' : 'action_0';
  nodes.add(
    WorkflowNode(
      id: 'start',
      type: WorkflowNodeType.start,
      label: '开始',
      next: [firstNodesId],
    ),
  );

  for (var index = 0; index < actions.length; index += 1) {
    final action = actions[index];
    final actionNodesId = 'action_$index';
    final waitNodesId = 'wait_after_$index';
    final nextActionsNodesId = index == actions.length - 1
        ? 'end'
        : 'action_${index + 1}';
    final includeWaitAfter =
        action.type != _RecordedActionsType.wait && action.waitAfterMs > 0;
    nodes.add(
      WorkflowNode(
        id: actionNodesId,
        type: _workflowTypeForRecordedAction(action),
        label: action.label,
        next: [includeWaitAfter ? waitNodesId : nextActionsNodesId],
        parameters: _workflowParametersForRecordedAction(action),
      ),
    );
    if (includeWaitAfter) {
      nodes.add(
        WorkflowNode(
          id: waitNodesId,
          type: WorkflowNodeType.wait,
          label: '等 ${action.waitAfterMs}ms',
          next: [nextActionsNodesId],
          parameters: <String, Object?>{'ms': action.waitAfterMs},
        ),
      );
    }
  }

  nodes.add(
    const WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
  );
  return WorkflowDefinition(
    id: 'recorded-session',
    name: '录制流程',
    entryNodesId: 'start',
    nodes: nodes,
  );
}

// 把录制动作类型映射为 Project DSL 节点类型。
WorkflowNodeType _workflowTypeForRecordedAction(_RecordedActions action) {
  return switch (action.type) {
    _RecordedActionsType.tap => WorkflowNodeType.tap,
    _RecordedActionsType.wait => WorkflowNodeType.wait,
    _RecordedActionsType.swipe => WorkflowNodeType.swipe,
    _RecordedActionsType.input => WorkflowNodeType.input,
  };
}

// 生成 Project DSL 参数，最终仍由 Runtime updateWorkflow 和 validator 兜底。
Map<String, Object?> _workflowParametersForRecordedAction(
  _RecordedActions action,
) {
  return switch (action.type) {
    _RecordedActionsType.tap => <String, Object?>{
      'label': action.label,
      if (action.targetRef case final targetRef?) 'targetRef': targetRef,
      if (action.targetRef == null) 'x': action.x,
      if (action.targetRef == null) 'y': action.y,
      'durationMs': action.durationMs,
    },
    _RecordedActionsType.wait => <String, Object?>{'ms': action.waitAfterMs},
    _RecordedActionsType.swipe => <String, Object?>{
      'label': action.label,
      'durationMs': action.durationMs,
      'direction': _workflowSwipeDirectionForRecordedAction(action),
      'fromX': action.x ?? 200,
      'fromY': action.y ?? 700,
      'toX': action.toX ?? 200,
      'toY': action.toY ?? 300,
    },
    _RecordedActionsType.input => <String, Object?>{
      'label': action.label,
      'text': action.text ?? '',
    },
  };
}

// 将录制滑动方向转成 DSL 机器字段，界面文案仍使用短中文。
String _workflowSwipeDirectionForRecordedAction(_RecordedActions action) {
  if (!action.hasSwipePath) return 'up';
  final dx = action.toX! - action.x!;
  final dy = action.toY! - action.y!;
  if (dx.abs() > dy.abs()) return dx > 0 ? 'right' : 'left';
  return dy > 0 ? 'down' : 'up';
}
