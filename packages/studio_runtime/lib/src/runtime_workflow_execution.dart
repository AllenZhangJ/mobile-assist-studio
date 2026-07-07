part of '../studio_runtime.dart';

// 工作流执行主循环，负责串行推进节点和 Catch 路由。
extension StudioRuntimeControllerWorkflowExecution on StudioRuntimeController {
  // 按入口节点开始执行一轮 workflow，并限制子流程嵌套深度。
  Future<void> _runWorkflowLoop({
    required WorkflowDefinition workflow,
    required String sessionId,
    required int loopIndex,
    required int totalLoops,
    required int tapDurationMs,
    required String? evidenceRunId,
    required int depth,
    Map<String, Object?> workflowInputs = const <String, Object?>{},
  }) async {
    if (depth > 8) {
      throw StateError('子流程嵌套过深。');
    }
    var currentNodeId = workflow.entryNodesId;
    _ActiveCatch? activeCatch;
    final catchRetryCounts = <String, int>{};
    final loopIterationCounts = <String, int>{};
    while (true) {
      final node = _nodeById(workflow, currentNodeId);
      if (node.type == WorkflowNodeType.end) {
        return;
      }
      try {
        String? selectedNextNodeId;
        if (node.type != WorkflowNodeType.start) {
          selectedNextNodeId = await _runWorkflowNode(
            sessionId: sessionId,
            node: node,
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            tapDurationMs: tapDurationMs,
            evidenceRunId: evidenceRunId,
            depth: depth,
            loopIterationCounts: loopIterationCounts,
            workflowInputs: workflowInputs,
          );
          if (node.type == WorkflowNodeType.catchNodes) {
            activeCatch = _activeCatchFromNode(node);
          }
        }
        if (_stopRequested) return;
        if (node.type == WorkflowNodeType.condition ||
            node.type == WorkflowNodeType.loop) {
          if (selectedNextNodeId == null) return;
          currentNodeId = selectedNextNodeId;
          continue;
        }
        if (node.next.isEmpty) return;
        if (selectedNextNodeId != null) {
          currentNodeId = selectedNextNodeId;
          continue;
        }
        if (node.next.length > 1) {
          throw StateError('节点 ${node.id} 有多个出口，当前只能执行线性流程。');
        }
        currentNodeId = node.next.single;
      } on Object catch (error) {
        if (error is _WorkflowPausedException) {
          rethrow;
        }
        final catchContext = activeCatch;
        if (catchContext == null || catchContext.onErrorNodeId == null) {
          rethrow;
        }
        final retryKey = '${catchContext.nodeId}:$currentNodeId:$loopIndex';
        final attempts = catchRetryCounts[retryKey] ?? 0;
        if (attempts < catchContext.maxRetries) {
          catchRetryCounts[retryKey] = attempts + 1;
          await _recordCatchRetry(
            evidenceRunId: evidenceRunId,
            catchContext: catchContext,
            loopIndex: loopIndex,
            failedNodeId: currentNodeId,
            attempt: attempts + 1,
            error: error,
          );
          continue;
        }
        await _recordCatchRoute(
          evidenceRunId: evidenceRunId,
          catchContext: catchContext,
          loopIndex: loopIndex,
          failedNodeId: currentNodeId,
          error: error,
        );
        currentNodeId = catchContext.onErrorNodeId!;
        activeCatch = null;
      }
    }
  }

  // 记录 Catch 重试事件，并清掉当前失败焦点。
  Future<void> _recordCatchRetry({
    required String? evidenceRunId,
    required _ActiveCatch catchContext,
    required int loopIndex,
    required String failedNodeId,
    required int attempt,
    required Object error,
  }) async {
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'catchRetry',
      'status': 'retrying',
      'nodeId': catchContext.nodeId,
      'nodeType': WorkflowNodeType.catchNodes.name,
      'label': catchContext.label,
      'loopIndex': loopIndex,
      'failedNodeId': failedNodeId,
      'attempt': attempt,
      'maxRetries': catchContext.maxRetries,
      'error': '$error',
    });
    _emit(
      _snapshot.copyWith(
        executionFocus: _snapshot.executionFocus.copyWith(failedNodeId: null),
        events: _appendEvent(
          'warning',
          '异常处理 ${catchContext.label}：$failedNodeId 失败后重试 $attempt/${catchContext.maxRetries}。',
        ),
      ),
    );
  }

  // 记录 Catch 错误分支路由事件，并切换到 onError 分支。
  Future<void> _recordCatchRoute({
    required String? evidenceRunId,
    required _ActiveCatch catchContext,
    required int loopIndex,
    required String failedNodeId,
    required Object error,
  }) async {
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'catchRoute',
      'status': 'handled',
      'nodeId': catchContext.nodeId,
      'nodeType': WorkflowNodeType.catchNodes.name,
      'label': catchContext.label,
      'loopIndex': loopIndex,
      'failedNodeId': failedNodeId,
      'selectedNext': catchContext.onErrorNodeId,
      'error': '$error',
    });
    _emit(
      _snapshot.copyWith(
        executionFocus: _snapshot.executionFocus.copyWith(failedNodeId: null),
        events: _appendEvent(
          'warning',
          '异常处理 ${catchContext.label}：$failedNodeId 已转到 ${catchContext.onErrorNodeId}。',
        ),
      ),
    );
  }
}
