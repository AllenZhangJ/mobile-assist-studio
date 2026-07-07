part of '../../studio_mac_workspace.dart';

// 计算多选 Inspector 摘要数据，避免展示层重复遍历和散落业务判断。
({int tapCount, int waitCount, int mutableCount}) _multiNodeInspectorStats({
  required WorkflowDefinition workflow,
  required List<WorkflowNode> nodes,
}) {
  var tapCount = 0;
  var waitCount = 0;
  var mutableCount = 0;

  for (final node in nodes) {
    if (node.type == WorkflowNodeType.tap) tapCount += 1;
    if (node.type == WorkflowNodeType.wait) waitCount += 1;

    if (_canMutateMultiNode(workflow: workflow, node: node)) {
      mutableCount += 1;
    }
  }

  return (tapCount: tapCount, waitCount: waitCount, mutableCount: mutableCount);
}

// 判断节点是否允许批量复制或删除，入口节点与起止节点必须保留。
bool _canMutateMultiNode({
  required WorkflowDefinition workflow,
  required WorkflowNode node,
}) {
  return node.type != WorkflowNodeType.start &&
      node.type != WorkflowNodeType.end &&
      node.id != workflow.entryNodesId;
}
