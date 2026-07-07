part of '../../studio_mac_workspace.dart';

// Workflow 节点分支展示 helper，集中处理 next 与 Catch 错误分支的短中文摘要。

/// 返回节点卡片右侧的短分支摘要。
/// 摘要只展示用户可读目标，不直接暴露 next ID 列表。
String _nodeBranchSummary(WorkflowDefinition workflow, WorkflowNode node) {
  if (node.type == WorkflowNodeType.catchNodes) {
    return _catchBranchSummary(workflow, node);
  }
  if (node.next.isEmpty) return '无后续';
  return switch (node.type) {
    WorkflowNodeType.condition => _indexedBranchSummary(
      workflow,
      node.next,
      const ['满足', '否则'],
    ),
    WorkflowNodeType.loop => _indexedBranchSummary(workflow, node.next, const [
      '主体',
      '后续',
    ]),
    WorkflowNodeType.visualBranch => _indexedBranchSummary(
      workflow,
      node.next,
      const ['通过'],
    ),
    WorkflowNodeType.waitForTarget => _indexedBranchSummary(
      workflow,
      node.next,
      const ['出现'],
    ),
    _ => '后续 ${_nodeBranchTargetLabel(workflow, node.next.first)}',
  };
}

/// 返回 Catch 节点的主线和错误分支摘要。
/// 未配置任何出口时给出“无后续”。
String _catchBranchSummary(WorkflowDefinition workflow, WorkflowNode node) {
  final parts = <String>[];
  if (node.next.isNotEmpty) {
    parts.add('主线 ${_nodeBranchTargetLabel(workflow, node.next.first)}');
  }
  final onError = _catchOnErrorTarget(node);
  if (onError != null) {
    parts.add('错误 ${_nodeBranchTargetLabel(workflow, onError)}');
  }
  return parts.isEmpty ? '无后续' : parts.join(' · ');
}

/// 按固定语义为分支编号。
/// 超过内置语义时使用“分支 N”兜底。
String _indexedBranchSummary(
  WorkflowDefinition workflow,
  List<String> next,
  List<String> labels,
) {
  final parts = <String>[];
  for (var index = 0; index < next.length && index < 2; index++) {
    final label = index < labels.length ? labels[index] : '分支 ${index + 1}';
    parts.add('$label ${_nodeBranchTargetLabel(workflow, next[index])}');
  }
  if (next.length > 2) parts.add('+${next.length - 2}');
  return parts.join(' · ');
}

/// 将目标节点 ID 转成短中文标签。
/// 缺失节点时保留可诊断的缺失标记。
String _nodeBranchTargetLabel(WorkflowDefinition workflow, String nodeId) {
  return _workflowNodeDisplayLabel(workflow, nodeId);
}

/// 从 Catch 节点读取错误分支目标。
/// 非 Catch 或空值时返回空，供图结构 helper 统一复用。
String? _catchOnErrorTarget(WorkflowNode node) {
  if (node.type != WorkflowNodeType.catchNodes) return null;
  final onError = node.parameters['onError'];
  if (onError is! String || onError.trim().isEmpty) return null;
  return onError.trim();
}
