part of '../../studio_mac_workspace.dart';

// Workflow 节点执行态 helper，供画布节点和小地图统一高亮。

// 节点运行态，供画布和迷你图统一高亮。
enum _WorkflowNodeExecutionState { idle, active, completed, failed }

/// 根据执行焦点计算节点运行态。
/// 失败优先于当前态，已完成节点只在非当前时展示完成。
_WorkflowNodeExecutionState _executionStateForNodes(
  String nodeId,
  RuntimeExecutionFocus focus,
) {
  if (focus.failedNodeId == nodeId) return _WorkflowNodeExecutionState.failed;
  if (focus.activeNodeId == nodeId) return _WorkflowNodeExecutionState.active;
  if (focus.completedNodeIds.contains(nodeId)) {
    return _WorkflowNodeExecutionState.completed;
  }
  return _WorkflowNodeExecutionState.idle;
}

/// 返回运行态对应色调。
/// 色调用于状态胶囊和局部高亮保持一致。
StudioStatusTone _toneForExecutionState(_WorkflowNodeExecutionState state) {
  return switch (state) {
    _WorkflowNodeExecutionState.active => StudioStatusTone.running,
    _WorkflowNodeExecutionState.completed => StudioStatusTone.ready,
    _WorkflowNodeExecutionState.failed => StudioStatusTone.error,
    _WorkflowNodeExecutionState.idle => StudioStatusTone.offline,
  };
}

/// 返回运行态短中文标签。
/// 标签面向用户，不展示底层执行枚举。
String _labelForExecutionState(_WorkflowNodeExecutionState state) {
  return switch (state) {
    _WorkflowNodeExecutionState.active => '当前',
    _WorkflowNodeExecutionState.completed => '完成',
    _WorkflowNodeExecutionState.failed => '失败',
    _WorkflowNodeExecutionState.idle => '空闲',
  };
}

/// 返回运行态前景色。
/// 空闲时回退到节点类型色，避免普通节点失去类型区分。
Color _colorForExecutionState(
  _WorkflowNodeExecutionState state,
  StudioStatusTone fallbackTone,
) {
  return switch (state) {
    _WorkflowNodeExecutionState.active => StudioColors.cyan,
    _WorkflowNodeExecutionState.completed => StudioColors.green,
    _WorkflowNodeExecutionState.failed => StudioColors.red,
    _WorkflowNodeExecutionState.idle => _colorForTone(fallbackTone),
  };
}

/// 返回运行态背景色。
/// 背景色只表达执行反馈，不改变节点类型语义。
Color _backgroundForExecutionState(_WorkflowNodeExecutionState state) {
  return switch (state) {
    _WorkflowNodeExecutionState.active => StudioColors.cyan.withValues(
      alpha: 0.11,
    ),
    _WorkflowNodeExecutionState.completed => StudioColors.green.withValues(
      alpha: 0.08,
    ),
    _WorkflowNodeExecutionState.failed => StudioColors.red.withValues(
      alpha: 0.10,
    ),
    _WorkflowNodeExecutionState.idle => StudioColors.background.withValues(
      alpha: 0.48,
    ),
  };
}
