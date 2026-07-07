part of '../../studio_mac_workspace.dart';

// Workflow 图布局 helper，负责节点替换和视觉位置写入。

// 替换单个节点，保留 workflow 元信息不变。
WorkflowDefinition _workflowReplacingNodes(
  WorkflowDefinition workflow,
  WorkflowNode replacement,
) {
  return WorkflowDefinition(
    id: workflow.id,
    name: workflow.name,
    entryNodesId: workflow.entryNodesId,
    nodes: workflow.nodes
        .map((node) => node.id == replacement.id ? replacement : node)
        .toList(growable: false),
  );
}

// 批量写入节点视觉位置，只影响画布布局不改变执行语义。
WorkflowDefinition _workflowReplacingNodesPositions(
  WorkflowDefinition workflow,
  Map<String, Offset> positionsByNodeId,
) {
  return WorkflowDefinition(
    id: workflow.id,
    name: workflow.name,
    entryNodesId: workflow.entryNodesId,
    nodes: workflow.nodes
        .map((node) {
          final position = positionsByNodeId[node.id];
          if (position == null) return node;
          return node.copyWith(
            visual: WorkflowNodeVisual(
              x: position.dx.roundToDouble(),
              y: position.dy.roundToDouble(),
            ),
          );
        })
        .toList(growable: false),
  );
}

// 清空节点视觉位置，让画布回到自动布局。
WorkflowDefinition _workflowClearingVisualPositions(
  WorkflowDefinition workflow,
) {
  return WorkflowDefinition(
    id: workflow.id,
    name: workflow.name,
    entryNodesId: workflow.entryNodesId,
    nodes: workflow.nodes
        .map((node) => node.visual == null ? node : node.copyWith(visual: null))
        .toList(growable: false),
  );
}
