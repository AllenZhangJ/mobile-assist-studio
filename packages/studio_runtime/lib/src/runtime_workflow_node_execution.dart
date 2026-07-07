part of '../studio_runtime.dart';

// 工作流节点调度分片，负责分发节点类型并收口执行焦点。
extension StudioRuntimeControllerWorkflowNodeExecution
    on StudioRuntimeController {
  // 执行一个 workflow 节点，返回需要覆盖默认 next 的目标节点。
  Future<String?> _runWorkflowNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required int tapDurationMs,
    required String? evidenceRunId,
    required int depth,
    required Map<String, int> loopIterationCounts,
    required Map<String, Object?> workflowInputs,
  }) async {
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepStart',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
    });
    _emit(
      _snapshot.copyWith(
        executionFocus: _snapshot.executionFocus.copyWith(
          activeNodeId: node.id,
          failedNodeId: null,
          activeLoopIndex: loopIndex,
          totalLoops: totalLoops,
        ),
      ),
    );
    String? nextOverride;
    try {
      switch (node.type) {
        case WorkflowNodeType.tap:
          await _runTapNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            tapDurationMs: tapDurationMs,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.wait:
          await _runWaitNode(
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.swipe:
          await _runSwipeNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.input:
          await _runInputNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.snapshot:
          await _runSnapshotNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.condition:
          nextOverride = await _runConditionNode(
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
            workflowInputs: workflowInputs,
          );
        case WorkflowNodeType.visualBranch:
          nextOverride = await _runVisualBranchNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.waitForTarget:
          await _runWaitForTargetNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.catchNodes:
          await _runCatchNode(
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
          );
        case WorkflowNodeType.subWorkflow:
          await _runSubWorkflowNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            tapDurationMs: tapDurationMs,
            evidenceRunId: evidenceRunId,
            depth: depth,
            workflowInputs: workflowInputs,
          );
        case WorkflowNodeType.loop:
          nextOverride = await _runLoopNode(
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            evidenceRunId: evidenceRunId,
            loopIterationCounts: loopIterationCounts,
          );
        case WorkflowNodeType.start:
        case WorkflowNodeType.end:
          return null;
      }
      _markNodeCompleted(node);
      return nextOverride;
    } on Object catch (error) {
      await _markNodeFailed(
        node: node,
        loopIndex: loopIndex,
        evidenceRunId: evidenceRunId,
        error: error,
      );
      rethrow;
    }
  }

  // 标记节点成功完成并推进执行焦点。
  void _markNodeCompleted(WorkflowNode node) {
    _emit(
      _snapshot.copyWith(
        executionFocus: _snapshot.executionFocus.copyWith(
          activeNodeId: null,
          completedNodeIds: {
            ..._snapshot.executionFocus.completedNodeIds,
            node.id,
          },
          completedSteps: _snapshot.executionFocus.completedSteps + 1,
        ),
      ),
    );
  }

  // 标记节点失败并写入失败证据，暂停异常由上层保留原语义。
  Future<void> _markNodeFailed({
    required WorkflowNode node,
    required int loopIndex,
    required String? evidenceRunId,
    required Object error,
  }) async {
    if (error is _WorkflowPausedException) {
      throw error;
    }
    _emit(
      _snapshot.copyWith(
        executionFocus: _snapshot.executionFocus.copyWith(
          activeNodeId: null,
          failedNodeId: node.id,
        ),
      ),
    );
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'failed',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'error': '$error',
    });
  }
}
