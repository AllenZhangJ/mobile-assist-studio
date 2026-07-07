part of '../../studio_mac_workspace.dart';

// Workflow 节点基础 helper，集中维护节点类型、短文案、摘要、图标和默认色调。

// 可从画布或菜单插入的核心节点类型。
const _insertableNodeTypes = <WorkflowNodeType>[
  WorkflowNodeType.tap,
  WorkflowNodeType.wait,
  WorkflowNodeType.swipe,
  WorkflowNodeType.input,
  WorkflowNodeType.loop,
  WorkflowNodeType.snapshot,
  WorkflowNodeType.condition,
  WorkflowNodeType.visualBranch,
  WorkflowNodeType.waitForTarget,
  WorkflowNodeType.catchNodes,
  WorkflowNodeType.subWorkflow,
];

// 边上更多菜单可插入的节点类型，Tap / Wait 由快捷按钮承载。
const _edgeInsertMenuNodeTypes = <WorkflowNodeType>[
  WorkflowNodeType.swipe,
  WorkflowNodeType.input,
  WorkflowNodeType.loop,
  WorkflowNodeType.snapshot,
  WorkflowNodeType.condition,
  WorkflowNodeType.visualBranch,
  WorkflowNodeType.waitForTarget,
  WorkflowNodeType.catchNodes,
  WorkflowNodeType.subWorkflow,
];

/// 返回节点插入菜单使用的稳定 key。
/// key 只用于测试和菜单识别，不作为用户可见文案。
String _nodeInsertKey(WorkflowNodeType type) {
  return switch (type) {
    WorkflowNodeType.tap => 'tap',
    WorkflowNodeType.wait => 'wait',
    WorkflowNodeType.swipe => 'swipe',
    WorkflowNodeType.input => 'input',
    WorkflowNodeType.loop => 'loop',
    WorkflowNodeType.snapshot => 'snapshot',
    WorkflowNodeType.condition => 'condition',
    WorkflowNodeType.visualBranch => 'visual-branch',
    WorkflowNodeType.waitForTarget => 'wait-target',
    WorkflowNodeType.catchNodes => 'catch',
    WorkflowNodeType.subWorkflow => 'sub-workflow',
    _ => type.name,
  };
}

/// 返回插入动作的短中文文案。
/// 文案保持简短，避免撑开菜单。
String _insertNodesLabel(WorkflowNodeType type) {
  return switch (type) {
    WorkflowNodeType.tap => '点击',
    WorkflowNodeType.wait => '等待',
    WorkflowNodeType.swipe => '滑动',
    WorkflowNodeType.input => '输入',
    WorkflowNodeType.loop => '重复',
    WorkflowNodeType.snapshot => '截图',
    WorkflowNodeType.condition => '条件',
    WorkflowNodeType.visualBranch => '看图',
    WorkflowNodeType.waitForTarget => '等目标',
    WorkflowNodeType.catchNodes => '兜底',
    WorkflowNodeType.subWorkflow => '子流程',
    _ => type.name,
  };
}

/// 返回节点库主标签。
/// 节点库优先展示用户能理解的短中文。
String _nodePaletteLabel(WorkflowNodeType type) {
  return switch (type) {
    WorkflowNodeType.tap => '点击',
    WorkflowNodeType.wait => '等待',
    WorkflowNodeType.swipe => '滑动',
    WorkflowNodeType.input => '输入',
    WorkflowNodeType.loop => '重复',
    WorkflowNodeType.snapshot => '截图',
    WorkflowNodeType.condition => '条件',
    WorkflowNodeType.visualBranch => '看图',
    WorkflowNodeType.waitForTarget => '等目标',
    WorkflowNodeType.catchNodes => '兜底',
    WorkflowNodeType.subWorkflow => '子流程',
    _ => type.name,
  };
}

/// 返回节点库辅助说明。
/// 说明只解释用途，不暴露底层实现词。
String _nodePaletteDescription(WorkflowNodeType type) {
  return switch (type) {
    WorkflowNodeType.tap => '屏幕点击',
    WorkflowNodeType.wait => '固定等待',
    WorkflowNodeType.swipe => '滑动屏幕',
    WorkflowNodeType.input => '写入文字',
    WorkflowNodeType.loop => '重复几次',
    WorkflowNodeType.snapshot => '保存画面',
    WorkflowNodeType.condition => '按条件走',
    WorkflowNodeType.visualBranch => '看不准就停',
    WorkflowNodeType.waitForTarget => '等到出现',
    WorkflowNodeType.catchNodes => '失败重试',
    WorkflowNodeType.subWorkflow => '复用步骤',
    _ => '流程节点',
  };
}

/// 返回节点在卡片中的一句话摘要。
/// 摘要面向普通用户，不展示底层枚举。
String _nodeSummary(WorkflowNode node) {
  return switch (node.type) {
    WorkflowNodeType.tap => "点击 ${node.parameters['label'] ?? node.label}",
    WorkflowNodeType.wait => "等待 ${node.parameters['ms'] ?? '-'}ms",
    WorkflowNodeType.start => '流程开始',
    WorkflowNodeType.end => '流程结束',
    WorkflowNodeType.snapshot => '截图',
    WorkflowNodeType.swipe => '滑动手势',
    WorkflowNodeType.input => '文本输入',
    WorkflowNodeType.condition => '条件分支',
    WorkflowNodeType.visualBranch => '看图判断',
    WorkflowNodeType.waitForTarget => '等待目标',
    WorkflowNodeType.loop => '重复',
    WorkflowNodeType.catchNodes => '失败兜底',
    WorkflowNodeType.subWorkflow => '子流程',
  };
}

/// 将节点 ID 转成用户可读标签。
/// 缺失节点保留可诊断信息，方便定位坏引用。
String _workflowNodeDisplayLabel(WorkflowDefinition workflow, String nodeId) {
  for (final node in workflow.nodes) {
    if (node.id == nodeId) return node.label;
  }
  return '缺失 $nodeId';
}

/// 返回节点类型对应图标。
/// 图标只表达节点类别，不参与运行语义。
IconData _iconForNodes(WorkflowNodeType type) {
  return switch (type) {
    WorkflowNodeType.start => Icons.play_arrow,
    WorkflowNodeType.tap => Icons.touch_app_outlined,
    WorkflowNodeType.wait => Icons.timer_outlined,
    WorkflowNodeType.swipe => Icons.swipe_outlined,
    WorkflowNodeType.input => Icons.keyboard_outlined,
    WorkflowNodeType.snapshot => Icons.screenshot_monitor_outlined,
    WorkflowNodeType.condition => Icons.call_split_outlined,
    WorkflowNodeType.visualBranch => Icons.visibility_outlined,
    WorkflowNodeType.waitForTarget => Icons.center_focus_strong_outlined,
    WorkflowNodeType.loop => Icons.loop,
    WorkflowNodeType.catchNodes => Icons.report_gmailerrorred_outlined,
    WorkflowNodeType.subWorkflow => Icons.account_tree_outlined,
    WorkflowNodeType.end => Icons.stop,
  };
}

/// 返回节点类型的默认状态色调。
/// 执行态高亮由专门的执行态 helper 覆盖。
StudioStatusTone _toneForNodes(WorkflowNodeType type) {
  return switch (type) {
    WorkflowNodeType.start || WorkflowNodeType.end => StudioStatusTone.running,
    WorkflowNodeType.tap => StudioStatusTone.ready,
    WorkflowNodeType.wait => StudioStatusTone.warning,
    WorkflowNodeType.snapshot => StudioStatusTone.running,
    WorkflowNodeType.swipe ||
    WorkflowNodeType.input ||
    WorkflowNodeType.condition ||
    WorkflowNodeType.visualBranch ||
    WorkflowNodeType.waitForTarget ||
    WorkflowNodeType.loop ||
    WorkflowNodeType.catchNodes ||
    WorkflowNodeType.subWorkflow => StudioStatusTone.offline,
  };
}
