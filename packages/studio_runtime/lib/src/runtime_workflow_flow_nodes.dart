part of '../studio_runtime.dart';

// 工作流流程编排节点分片，负责异常路由、子流程和有限循环。

extension StudioRuntimeControllerWorkflowFlowNodes on StudioRuntimeController {
  /// 执行 Catch 节点，启用后续异常路由上下文。
  /// Catch 本身不执行设备动作，只写入证据并影响后续失败路由。
  Future<void> _runCatchNode({
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    final catchContext = _activeCatchFromNode(node);
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(
          'info',
          '第 ${loopIndex + 1}/$totalLoops 轮：异常处理 ${node.label} 已启用。',
        ),
      ),
    );
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'maxRetries': catchContext.maxRetries,
      if (catchContext.onErrorNodeId != null)
        'onError': catchContext.onErrorNodeId,
    });
  }

  /// 执行 Sub Workflow 节点，递归调用工作流主循环。
  /// 子流程复用同一 session、同一 evidence run 和同一串行 runner。
  Future<void> _runSubWorkflowNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required int tapDurationMs,
    required String? evidenceRunId,
    required int depth,
    required Map<String, Object?> workflowInputs,
  }) async {
    final target = _subWorkflowTargetFromNode(node);
    final validation = const WorkflowValidator().validate(target.workflow);
    if (!validation.isValid) {
      throw StateError(
        '子流程 ${target.workflowId} 无效：${validation.errors.join(' ')}',
      );
    }
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(
          'info',
          '第 ${loopIndex + 1}/$totalLoops 轮：运行子流程 ${target.workflow.name}。',
        ),
      ),
    );
    final context = _workflowContext(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      workflowInputs: workflowInputs,
    );
    final childInputs = _subWorkflowInputsFromNode(node, context);
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'subWorkflowStart',
      'status': 'running',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'workflowId': target.workflowId,
      'workflowName': target.workflow.name,
      'inputCount': childInputs.length,
      if (childInputs.isNotEmpty) 'inputNames': childInputs.keys.toList(),
    });
    await _runWorkflowLoop(
      workflow: target.workflow,
      sessionId: sessionId,
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      tapDurationMs: tapDurationMs,
      evidenceRunId: evidenceRunId,
      depth: depth + 1,
      workflowInputs: childInputs,
    );
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'workflowId': target.workflowId,
      'workflowName': target.workflow.name,
      'inputCount': childInputs.length,
      if (childInputs.isNotEmpty) 'inputNames': childInputs.keys.toList(),
    });
  }

  /// 执行 Loop 节点，返回循环体或结束后分支。
  /// Loop 只支持有限次数，循环状态保存在当前执行上下文中。
  Future<String?> _runLoopNode({
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
    required Map<String, int> loopIterationCounts,
  }) async {
    final count = _loopCountFromNode(node);
    if (node.next.length > 2) {
      throw StateError('循环节点 ${node.id} 分支过多。');
    }
    if (count > 0 && node.next.length != 2) {
      throw StateError('循环节点 ${node.id} 需要循环体和结束后分支。');
    }
    final completedIterations = loopIterationCounts[node.id] ?? 0;
    final shouldRunBody =
        count > 0 && node.next.isNotEmpty && completedIterations < count;
    if (shouldRunBody) {
      final nextIteration = completedIterations + 1;
      loopIterationCounts[node.id] = nextIteration;
      final selectedNext = node.next.first;
      _emit(
        _snapshot.copyWith(
          events: _appendEvent(
            'info',
            '第 ${loopIndex + 1}/$totalLoops 轮：循环 ${node.label} 第 $nextIteration/$count 次。',
          ),
        ),
      );
      await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
        'type': 'stepEnd',
        'status': 'running',
        'nodeId': node.id,
        'nodeType': node.type.name,
        'label': node.label,
        'loopIndex': loopIndex,
        'iteration': nextIteration,
        'count': count,
        'selectedNext': selectedNext,
      });
      return selectedNext;
    }
    loopIterationCounts.remove(node.id);
    final selectedNext = node.next.length > 1 ? node.next[1] : null;
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(
          'info',
          '第 ${loopIndex + 1}/$totalLoops 轮：循环 ${node.label} 已完成 $count 次。',
        ),
      ),
    );
    final loopEndEvent = <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'count': count,
    };
    if (selectedNext != null) {
      loopEndEvent['selectedNext'] = selectedNext;
    }
    await _recordEvidenceEvent(evidenceRunId, loopEndEvent);
    return selectedNext;
  }
}
