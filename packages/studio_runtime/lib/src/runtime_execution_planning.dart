part of '../studio_runtime.dart';

// Runtime 执行规划扩展，负责估算运行步数和子流程步数。
// 估算只用于进度展示，不参与真实执行语义。
extension StudioRuntimeExecutionPlanning on StudioRuntimeController {
  // 估算多轮运行的总步骤数，用于 Execute 和 Workflow 展示进度。
  // 估算失败时降级为 loops，避免 UI 出现 0 步运行。
  int _estimatedTotalExecutionSteps(WorkflowDefinition workflow, int loops) {
    final perLoop = _estimatedWorkflowStepCount(workflow, depth: 0);
    if (perLoop <= 0) return loops;
    return perLoop * loops;
  }

  // 估算单个 workflow 的步骤数，递归深度有硬上限。
  // 子流程过深时返回 0，避免估算阶段递归失控。
  int _estimatedWorkflowStepCount(
    WorkflowDefinition workflow, {
    required int depth,
  }) {
    if (depth > 8) return 0;
    final byId = {for (final node in workflow.nodes) node.id: node};
    return _estimatedPathStepCount(
      byId: byId,
      nodeId: workflow.entryNodesId,
      stopAtNodeIds: const <String>{},
      visitedNodeIds: const <String>{},
      depth: depth,
    );
  }

  // 沿一条路径估算步骤数，遇到已访问节点或停止节点就截断。
  // Loop 节点会按 bounded count 展开估算，但不改变 workflow。
  int _estimatedPathStepCount({
    required Map<String, WorkflowNode> byId,
    required String nodeId,
    required Set<String> stopAtNodeIds,
    required Set<String> visitedNodeIds,
    required int depth,
  }) {
    if (depth > 8 || stopAtNodeIds.contains(nodeId)) return 0;
    if (visitedNodeIds.contains(nodeId)) return 0;
    final node = byId[nodeId];
    if (node == null || node.type == WorkflowNodeType.end) return 0;
    final nextVisited = {...visitedNodeIds, nodeId};

    if (node.type == WorkflowNodeType.start) {
      return _estimatedBranchStepCount(
        byId: byId,
        nextNodeIds: node.next,
        stopAtNodeIds: stopAtNodeIds,
        visitedNodeIds: nextVisited,
        depth: depth,
      );
    }

    if (node.type == WorkflowNodeType.loop) {
      final count = _optionalIntParameter(node, 'count') ?? 0;
      final afterSteps = node.next.length > 1
          ? _estimatedPathStepCount(
              byId: byId,
              nodeId: node.next[1],
              stopAtNodeIds: stopAtNodeIds,
              visitedNodeIds: nextVisited,
              depth: depth,
            )
          : 0;
      if (count <= 0 || node.next.isEmpty) {
        return 1 + afterSteps;
      }
      final bodySteps = _estimatedPathStepCount(
        byId: byId,
        nodeId: node.next.first,
        stopAtNodeIds: {...stopAtNodeIds, node.id},
        visitedNodeIds: const <String>{},
        depth: depth,
      );
      return 1 + bodySteps * count + afterSteps;
    }

    final nestedWorkflowSteps = node.type == WorkflowNodeType.subWorkflow
        ? _estimatedSubWorkflowStepCount(node, depth: depth + 1)
        : 0;
    return 1 +
        nestedWorkflowSteps +
        _estimatedBranchStepCount(
          byId: byId,
          nextNodeIds: node.next,
          stopAtNodeIds: stopAtNodeIds,
          visitedNodeIds: nextVisited,
          depth: depth,
        );
  }

  // 多出口节点取最大路径作为保守估算，避免进度过早显示完成。
  // 该估算不代表实际分支一定会走最长路径。
  int _estimatedBranchStepCount({
    required Map<String, WorkflowNode> byId,
    required List<String> nextNodeIds,
    required Set<String> stopAtNodeIds,
    required Set<String> visitedNodeIds,
    required int depth,
  }) {
    var maxSteps = 0;
    for (final nextNodeId in nextNodeIds) {
      final steps = _estimatedPathStepCount(
        byId: byId,
        nodeId: nextNodeId,
        stopAtNodeIds: stopAtNodeIds,
        visitedNodeIds: visitedNodeIds,
        depth: depth,
      );
      if (steps > maxSteps) maxSteps = steps;
    }
    return maxSteps;
  }

  // 估算本地注册子流程步骤数，未注册或未配置时返回 0。
  // 子流程估算复用同一递归深度限制。
  int _estimatedSubWorkflowStepCount(WorkflowNode node, {required int depth}) {
    final workflowId = node.parameters['workflowId']?.toString().trim();
    if (workflowId == null || workflowId.isEmpty) return 0;
    final workflow = _subWorkflows[workflowId];
    if (workflow == null) return 0;
    return _estimatedWorkflowStepCount(workflow, depth: depth);
  }
}
