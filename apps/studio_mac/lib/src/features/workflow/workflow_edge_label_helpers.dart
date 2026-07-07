part of '../../studio_mac_workspace.dart';

// Workflow 连线展示 helper，集中处理选中连线浮层和分支角色文案。
// 这里只做用户可读标签转换，不写 Project DSL，也不触发 Runtime 命令。

// 返回画布连线浮层使用的短中文标签，避免把节点 ID 暴露给用户。
String _workflowEdgeDisplayLabel(
  WorkflowDefinition workflow,
  _WorkflowSelectedEdge edge,
) {
  final from = _workflowNodeDisplayLabel(workflow, edge.fromNodeId);
  final to = _workflowNodeDisplayLabel(workflow, edge.toNodeId);
  final role = _workflowEdgeRoleLabel(
    workflow,
    fromNodeId: edge.fromNodeId,
    toNodeId: edge.toNodeId,
    kind: edge.kind,
  );
  final path = '$from → $to';
  return role == null ? path : '$role：$path';
}

// 返回分支连线的短语义标签，普通线性连线不额外标注。
String? _workflowEdgeRoleLabel(
  WorkflowDefinition workflow, {
  required String fromNodeId,
  required String toNodeId,
  _WorkflowSelectedEdgeKind kind = _WorkflowSelectedEdgeKind.next,
}) {
  if (kind == _WorkflowSelectedEdgeKind.onError) return '错误';
  final fromNode = _selectedNode(workflow, fromNodeId);
  if (fromNode == null) return null;
  final nextIndex = fromNode.next.indexOf(toNodeId);
  if (nextIndex < 0) return null;
  return switch (fromNode.type) {
    WorkflowNodeType.condition => switch (nextIndex) {
      0 => '满足',
      1 => '否则',
      _ => '分支 ${nextIndex + 1}',
    },
    WorkflowNodeType.loop => switch (nextIndex) {
      0 => '主体',
      1 => '后续',
      _ => '分支 ${nextIndex + 1}',
    },
    WorkflowNodeType.visualBranch =>
      nextIndex == 0 ? '通过' : '分支 ${nextIndex + 1}',
    WorkflowNodeType.waitForTarget =>
      nextIndex == 0 ? '出现' : '分支 ${nextIndex + 1}',
    WorkflowNodeType.catchNodes =>
      nextIndex == 0 ? '主线' : '分支 ${nextIndex + 1}',
    _ => null,
  };
}
