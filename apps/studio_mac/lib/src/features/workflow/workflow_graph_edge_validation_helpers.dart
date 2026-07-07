part of '../../studio_mac_workspace.dart';

// Workflow 边合法性 helper，负责候选层的 Project DSL validator 预检。
// 它只回答“能不能保存”，不直接修改当前 workflow。

// 判断新增普通连线后是否仍是合法 Project DSL。
// UI 候选和保存兜底都应复用 validator，避免规则漂移。
bool _workflowCanAddEdge(
  WorkflowDefinition workflow, {
  required String fromNodeId,
  required String toNodeId,
}) {
  if (fromNodeId == toNodeId) return false;
  if (!_workflowContainsNodes(workflow, fromNodeId) ||
      !_workflowContainsNodes(workflow, toNodeId)) {
    return false;
  }
  final source = _selectedNode(workflow, fromNodeId);
  if (source == null ||
      source.type == WorkflowNodeType.end ||
      source.next.contains(toNodeId)) {
    return false;
  }
  final updatedWorkflow = _workflowAddingEdge(
    workflow,
    fromNodeId: fromNodeId,
    toNodeId: toNodeId,
  );
  return const WorkflowValidator().validate(updatedWorkflow).isValid;
}

// 判断选中边改目标后是否仍是合法 Project DSL。
// 候选菜单先过滤非法目标，保存时仍保留 Runtime validator 兜底。
bool _workflowCanReplaceEdgeTarget(
  WorkflowDefinition workflow, {
  required String fromNodeId,
  required String oldToNodeId,
  required String newToNodeId,
  _WorkflowSelectedEdgeKind kind = _WorkflowSelectedEdgeKind.next,
}) {
  if (fromNodeId == newToNodeId || oldToNodeId == newToNodeId) {
    return false;
  }
  if (!_workflowContainsNodes(workflow, fromNodeId) ||
      !_workflowContainsNodes(workflow, oldToNodeId) ||
      !_workflowContainsNodes(workflow, newToNodeId)) {
    return false;
  }
  final updatedWorkflow = _workflowReplacingEdgeTarget(
    workflow,
    fromNodeId: fromNodeId,
    oldToNodeId: oldToNodeId,
    newToNodeId: newToNodeId,
    kind: kind,
  );
  return const WorkflowValidator().validate(updatedWorkflow).isValid;
}

// 判断选中边改起点后是否仍是合法 Project DSL。
// 该 helper 覆盖普通 next 和 Catch onError 两类边。
bool _workflowCanReplaceEdgeSource(
  WorkflowDefinition workflow, {
  required String oldFromNodeId,
  required String newFromNodeId,
  required String toNodeId,
  _WorkflowSelectedEdgeKind kind = _WorkflowSelectedEdgeKind.next,
}) {
  if (oldFromNodeId == newFromNodeId || newFromNodeId == toNodeId) {
    return false;
  }
  if (!_workflowContainsNodes(workflow, oldFromNodeId) ||
      !_workflowContainsNodes(workflow, newFromNodeId) ||
      !_workflowContainsNodes(workflow, toNodeId)) {
    return false;
  }
  final updatedWorkflow = _workflowReplacingEdgeSource(
    workflow,
    oldFromNodeId: oldFromNodeId,
    newFromNodeId: newFromNodeId,
    toNodeId: toNodeId,
    kind: kind,
  );
  return const WorkflowValidator().validate(updatedWorkflow).isValid;
}
