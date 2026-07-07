part of '../../studio_mac_workspace.dart';

// Workflow 边参数 helper，集中处理 next 去重和 Catch onError 写入。

// 替换 next 中的目标节点，并保持目标列表去重和原始顺序。
List<String> _replacedNextTargets(
  Iterable<String> nextTargets, {
  required String oldToNodeId,
  required String newToNodeId,
}) {
  final next = <String>[];
  for (final nextId in nextTargets) {
    final target = nextId == oldToNodeId ? newToNodeId : nextId;
    if (!next.contains(target)) next.add(target);
  }
  return next;
}

// 返回写入指定错误分支后的节点，保持其它参数不变。
WorkflowNode _nodeWithOnError(WorkflowNode node, String targetNodeId) {
  return node.copyWith(
    parameters: {...node.parameters, 'onError': targetNodeId},
  );
}

// 返回清除错误分支后的节点，避免保留空 onError。
WorkflowNode _nodeWithoutOnError(WorkflowNode node) {
  final parameters = Map<String, Object?>.of(node.parameters)
    ..remove('onError');
  return node.copyWith(parameters: parameters);
}
