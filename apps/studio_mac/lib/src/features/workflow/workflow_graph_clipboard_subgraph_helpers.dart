part of '../../studio_mac_workspace.dart';

// 复制一个选中子图，并把外部后继统一接回粘贴锚点原后继。
_WorkflowCopiedSubgraph? _workflowCopiedSubgraph(
  List<WorkflowNode> sourceNodes, {
  required Set<String> reservedNodesIds,
  required List<String> fallbackNext,
  int exposedEntryCapacity = 1,
}) {
  if (sourceNodes.isEmpty) return null;
  final duplicateIdsBySource = <String, String>{};
  for (final sourceNode in sourceNodes) {
    final duplicateId = _uniqueNodesIdWithReserved(
      reservedNodesIds,
      sourceNode.type.name,
    );
    reservedNodesIds.add(duplicateId);
    duplicateIdsBySource[sourceNode.id] = duplicateId;
  }
  final components = _workflowCopiedSubgraphComponents(sourceNodes);
  if (components.isEmpty) return null;
  final componentEntries = [
    for (final component in components)
      _workflowCopiedSubgraphEntryIds(
        component,
        duplicateIdsBySource: duplicateIdsBySource,
        sourceIdSet: component.map((node) => node.id).toSet(),
      ),
  ];
  final exposedComponentEntries = [
    for (var index = 0; index < componentEntries.length; index += 1)
      _workflowExposedComponentEntries(
        componentEntries[index],
        entryCapacity: index == 0 ? exposedEntryCapacity : 1,
      ),
  ];
  final duplicatedNodes = <WorkflowNode>[];
  for (var index = 0; index < components.length; index += 1) {
    final component = components[index];
    final componentFallbackNext = index == components.length - 1
        ? fallbackNext
        : exposedComponentEntries[index + 1];
    final componentDuplicatedNodes = component
        .map(
          (sourceNode) => _duplicatedNodesForBatch(
            sourceNode,
            duplicateId: duplicateIdsBySource[sourceNode.id]!,
            duplicateIdsBySource: duplicateIdsBySource,
            fallbackNext: componentFallbackNext,
          ),
        )
        .toList(growable: false);
    duplicatedNodes.addAll(
      _workflowSerializingMultiEntryComponent(
        componentDuplicatedNodes,
        componentEntries[index],
        exposedEntryCapacity: index == 0 ? exposedEntryCapacity : 1,
      ),
    );
  }
  return _WorkflowCopiedSubgraph(
    nodes: duplicatedNodes,
    entryNodeIds: exposedComponentEntries.first,
  );
}

// 将选中节点按内部连线拆成组件，互不相连的组件后续会被串行粘贴。
List<List<WorkflowNode>> _workflowCopiedSubgraphComponents(
  List<WorkflowNode> sourceNodes,
) {
  final sourceIdSet = sourceNodes.map((node) => node.id).toSet();
  final adjacency = <String, Set<String>>{
    for (final node in sourceNodes) node.id: <String>{},
  };
  for (final node in sourceNodes) {
    for (final targetId in _workflowOutgoingTargetIds(
      node,
    ).where(sourceIdSet.contains)) {
      adjacency[node.id]!.add(targetId);
      adjacency[targetId]!.add(node.id);
    }
  }

  final visited = <String>{};
  final components = <List<WorkflowNode>>[];
  for (final node in sourceNodes) {
    if (!visited.add(node.id)) continue;
    final queue = <String>[node.id];
    final componentIds = <String>{node.id};
    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      for (final nextId in adjacency[currentId] ?? const <String>{}) {
        if (!visited.add(nextId)) continue;
        componentIds.add(nextId);
        queue.add(nextId);
      }
    }
    components.add(
      sourceNodes
          .where((candidate) => componentIds.contains(candidate.id))
          .toList(growable: false),
    );
  }
  return components;
}

// 计算复制子图入口：没有内部前驱的节点是入口，纯环则退回第一个节点。
List<String> _workflowCopiedSubgraphEntryIds(
  List<WorkflowNode> sourceNodes, {
  required Map<String, String> duplicateIdsBySource,
  required Set<String> sourceIdSet,
}) {
  final internalTargets = <String>{};
  for (final node in sourceNodes) {
    internalTargets.addAll(
      _workflowOutgoingTargetIds(node).where(sourceIdSet.contains),
    );
  }
  final entries = sourceNodes
      .where((node) => !internalTargets.contains(node.id))
      .map((node) => duplicateIdsBySource[node.id]!)
      .toList(growable: false);
  if (entries.isNotEmpty) return entries;
  return [duplicateIdsBySource[sourceNodes.first.id]!];
}

// 根据锚点出口容量决定组件对外暴露几个入口。
// 普通节点只能暴露一个入口；条件节点可保留双入口分支结构。
List<String> _workflowExposedComponentEntries(
  List<String> entryNodeIds, {
  required int entryCapacity,
}) {
  if (entryNodeIds.isEmpty) return const <String>[];
  final normalizedCapacity = entryCapacity < 1 ? 1 : entryCapacity;
  return entryNodeIds.take(normalizedCapacity).toList(growable: false);
}

// 多入口汇合子图只对外暴露第一个入口，并把其它入口按源顺序串起来。
// 这样粘贴到普通节点之后不会产生多个出口，同时保留共享下游节点。
List<WorkflowNode> _workflowSerializingMultiEntryComponent(
  List<WorkflowNode> duplicatedNodes,
  List<String> entryNodeIds, {
  required int exposedEntryCapacity,
}) {
  if (entryNodeIds.length < 2 || entryNodeIds.length <= exposedEntryCapacity) {
    return duplicatedNodes;
  }
  final nextEntryByEntry = <String, String>{
    for (
      var index = exposedEntryCapacity - 1;
      index < entryNodeIds.length - 1;
      index += 1
    )
      entryNodeIds[index]: entryNodeIds[index + 1],
  };
  return [
    for (final node in duplicatedNodes)
      if (nextEntryByEntry[node.id] case final nextEntry?)
        node.copyWith(next: [nextEntry])
      else
        node,
  ];
}

// 返回剪贴板粘贴锚点可承载的入口数量。
// 当前只让条件节点保留双分支，其它节点继续走安全串行化。
int _workflowClipboardEntryCapacity(WorkflowNode? anchorNode) {
  return anchorNode?.type == WorkflowNodeType.condition ? 2 : 1;
}

// 复制批量节点，并把内部引用映射到新节点 ID。
WorkflowNode _duplicatedNodesForBatch(
  WorkflowNode source, {
  required String duplicateId,
  required Map<String, String> duplicateIdsBySource,
  required List<String> fallbackNext,
}) {
  final parameters = Map<String, Object?>.of(source.parameters);
  final remappedOnError = _remappedSubgraphOnError(
    parameters['onError'],
    duplicateIdsBySource: duplicateIdsBySource,
    fallbackNext: fallbackNext,
  );
  if (remappedOnError == null) {
    parameters.remove('onError');
  } else {
    parameters['onError'] = remappedOnError;
  }
  final next = _remappedSubgraphNext(
    source.next,
    duplicateIdsBySource: duplicateIdsBySource,
    fallbackNext: fallbackNext,
  );
  return WorkflowNode(
    id: duplicateId,
    type: source.type,
    label: '复制 ${source.label}',
    next: next,
    parameters: Map<String, Object?>.unmodifiable(parameters),
    visual: source.visual == null
        ? null
        : WorkflowNodeVisual(
            x: source.visual!.x == null ? null : source.visual!.x! + 48,
            y: source.visual!.y == null ? null : source.visual!.y! + 48,
          ),
  );
}

// 重映射复制节点的错误分支；外部错误出口接回锚点原后继。
String? _remappedSubgraphOnError(
  Object? sourceOnError, {
  required Map<String, String> duplicateIdsBySource,
  required List<String> fallbackNext,
}) {
  if (sourceOnError is! String || sourceOnError.trim().isEmpty) return null;
  final onError = sourceOnError.trim();
  return duplicateIdsBySource[onError] ?? fallbackNext.firstOrNull;
}

// 重映射复制节点的 next；外部引用会改接到锚点原后继。
List<String> _remappedSubgraphNext(
  List<String> sourceNext, {
  required Map<String, String> duplicateIdsBySource,
  required List<String> fallbackNext,
}) {
  final next = <String>[];
  for (final nextId in sourceNext) {
    final mapped = duplicateIdsBySource[nextId];
    if (mapped != null) {
      next.add(mapped);
    } else {
      next.addAll(fallbackNext);
    }
  }
  if (sourceNext.isEmpty) next.addAll(fallbackNext);
  return next.toSet().toList(growable: false);
}

// 已复制的子图结果，包含可插入节点和子图入口。
final class _WorkflowCopiedSubgraph {
  const _WorkflowCopiedSubgraph({
    required this.nodes,
    required this.entryNodeIds,
  });

  final List<WorkflowNode> nodes;
  final List<String> entryNodeIds;

  // 返回复制出的节点 ID 集合，用于粘贴后切换选区。
  Set<String> get nodeIds => nodes.map((node) => node.id).toSet();
}
