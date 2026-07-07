part of '../../studio_mac_workspace.dart';

// Workflow 图剪贴板 helper，负责复制、批量复制和粘贴节点。

// 创建单节点副本，并轻微偏移视觉位置。
WorkflowNode _duplicatedNodesForInsert(
  WorkflowDefinition workflow,
  WorkflowNode source,
) {
  final id = _uniqueNodesId(workflow, source.type.name);
  return WorkflowNode(
    id: id,
    type: source.type,
    label: '复制 ${source.label}',
    parameters: Map<String, Object?>.unmodifiable(source.parameters),
    visual: source.visual == null
        ? null
        : WorkflowNodeVisual(
            x: source.visual!.x == null ? null : source.visual!.x! + 36,
            y: source.visual!.y == null ? null : source.visual!.y! + 36,
          ),
  );
}

// 批量复制选中节点，保持源节点内部连线关系。
_WorkflowDuplicateResult _workflowDuplicatingNodes(
  WorkflowDefinition workflow,
  List<String> sourceNodeIds,
) {
  final sourceIdSet = sourceNodeIds.toSet();
  final sourceNodes = workflow.nodes
      .where((node) => sourceIdSet.contains(node.id))
      .toList(growable: false);
  if (sourceNodes.isEmpty) {
    return _WorkflowDuplicateResult(
      workflow: workflow,
      duplicatedNodeIds: const <String>{},
    );
  }

  final reservedNodesIds = workflow.nodes.map((node) => node.id).toSet();
  final lastSourceId = sourceNodes.last.id;
  final anchorNodes = _selectedNode(workflow, lastSourceId);
  final copiedSubgraph = _workflowCopiedSubgraph(
    sourceNodes,
    reservedNodesIds: reservedNodesIds,
    fallbackNext: anchorNodes?.next ?? const <String>[],
    exposedEntryCapacity: _workflowClipboardEntryCapacity(anchorNodes),
  );
  if (copiedSubgraph == null) {
    return _WorkflowDuplicateResult(
      workflow: workflow,
      duplicatedNodeIds: const <String>{},
    );
  }

  final updatedNodes = <WorkflowNode>[];
  for (final node in workflow.nodes) {
    if (node.id == lastSourceId) {
      updatedNodes.add(node.copyWith(next: copiedSubgraph.entryNodeIds));
      updatedNodes.addAll(copiedSubgraph.nodes);
    } else {
      updatedNodes.add(node);
    }
  }

  return _WorkflowDuplicateResult(
    workflow: WorkflowDefinition(
      id: workflow.id,
      name: workflow.name,
      entryNodesId: workflow.entryNodesId,
      nodes: updatedNodes,
    ),
    duplicatedNodeIds: copiedSubgraph.nodeIds,
  );
}

// 把本地画布剪贴板内容插入到锚点节点之后。
_WorkflowDuplicateResult _workflowPastingClipboardNodes(
  WorkflowDefinition workflow,
  _WorkflowCanvasClipboard clipboard, {
  required String anchorNodeId,
}) {
  final sourceNodes = clipboard.nodes;
  if (sourceNodes.isEmpty || !_workflowContainsNodes(workflow, anchorNodeId)) {
    return _WorkflowDuplicateResult(
      workflow: workflow,
      duplicatedNodeIds: const <String>{},
    );
  }

  final anchorNodes = _selectedNode(workflow, anchorNodeId);
  if (anchorNodes == null) {
    return _WorkflowDuplicateResult(
      workflow: workflow,
      duplicatedNodeIds: const <String>{},
    );
  }
  final copiedSubgraph = _workflowCopiedSubgraph(
    sourceNodes,
    reservedNodesIds: workflow.nodes.map((node) => node.id).toSet(),
    fallbackNext: anchorNodes.next,
    exposedEntryCapacity: _workflowClipboardEntryCapacity(anchorNodes),
  );
  if (copiedSubgraph == null) {
    return _WorkflowDuplicateResult(
      workflow: workflow,
      duplicatedNodeIds: const <String>{},
    );
  }

  final updatedNodes = <WorkflowNode>[];
  var inserted = false;
  for (final node in workflow.nodes) {
    if (node.id == anchorNodeId) {
      updatedNodes.add(node.copyWith(next: copiedSubgraph.entryNodeIds));
      updatedNodes.addAll(copiedSubgraph.nodes);
      inserted = true;
    } else {
      updatedNodes.add(node);
    }
  }

  if (!inserted) {
    return _WorkflowDuplicateResult(
      workflow: workflow,
      duplicatedNodeIds: const <String>{},
    );
  }

  return _WorkflowDuplicateResult(
    workflow: WorkflowDefinition(
      id: workflow.id,
      name: workflow.name,
      entryNodesId: workflow.entryNodesId,
      nodes: updatedNodes,
    ),
    duplicatedNodeIds: copiedSubgraph.nodeIds,
  );
}

// 批量复制/粘贴后的 workflow 和新节点集合。
final class _WorkflowDuplicateResult {
  const _WorkflowDuplicateResult({
    required this.workflow,
    required this.duplicatedNodeIds,
  });

  final WorkflowDefinition workflow;
  final Set<String> duplicatedNodeIds;
}
