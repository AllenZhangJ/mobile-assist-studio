part of '../studio_runtime.dart';

// 工作流动作节点分片，负责 Tap、Wait、Swipe、Input 和 Snapshot。
extension StudioRuntimeControllerWorkflowActionNodes
    on StudioRuntimeController {
  // 执行 Tap 节点，并确保 W3C actions 被释放。
  Future<void> _runTapNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required int tapDurationMs,
    required String? evidenceRunId,
  }) async {
    final targetRef = _targetRefFromNode(node);
    if (targetRef != null) {
      final target = _snapshot.targetLibrary.targetById(targetRef);
      if (target == null) {
        throw StateError('节点 ${node.id} 引用了不存在的目标。');
      }
      if (target.kind != RuntimeTargetKind.coordinate) {
        await _runResolvedTargetTapNode(
          sessionId: sessionId,
          node: node,
          target: target,
          loopIndex: loopIndex,
          totalLoops: totalLoops,
          tapDurationMs: tapDurationMs,
          evidenceRunId: evidenceRunId,
        );
        return;
      }
    }
    final tap = _tapFromNode(node, tapDurationMs);
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '点击',
      label: tap.label,
    );
    try {
      await _deviceActions.tap(sessionId, tap);
    } finally {
      await _deviceActions.releaseActions(sessionId);
    }
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': tap.label,
      'loopIndex': loopIndex,
      'x': tap.point.x,
      'y': tap.point.y,
    });
  }

  // 执行非坐标目标 Tap。
  // 先通过 TargetResolver 解析出目标坐标，低置信或未命中时暂停而不是盲点。
  Future<void> _runResolvedTargetTapNode({
    required String sessionId,
    required WorkflowNode node,
    required RuntimeTargetDefinition target,
    required int loopIndex,
    required int totalLoops,
    required int tapDurationMs,
    required String? evidenceRunId,
  }) async {
    final confidenceThreshold = _confidenceThresholdFromNode(node);
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '找目标',
      label: target.label,
    );
    final result = await _resolveTargetFromFreshScreenshot(
      sessionId: sessionId,
      target: target,
      confidenceThreshold: confidenceThreshold,
    );
    final matched = result.status == TargetResolutionStatus.matched;
    if (!matched) {
      await _recordTargetResolutionEvidence(
        evidenceRunId: evidenceRunId,
        node: node,
        target: target,
        loopIndex: loopIndex,
        result: result,
        confidenceThreshold: confidenceThreshold,
        type: 'stepEnd',
        status: 'paused',
        action: 'pause',
      );
      _emit(
        _snapshot.copyWith(
          events: _appendEvent(
            'warning',
            '第 ${loopIndex + 1}/$totalLoops 轮：目标 ${target.label} 未确认，已暂停。',
          ),
        ),
      );
      _pauseForTargetResolutionFailure(
        node: node,
        message: _targetTapPauseMessage(
          target: target,
          result: result,
          confidenceThreshold: confidenceThreshold,
        ),
      );
    }

    final point = result.point;
    if (point == null) {
      throw StateError('目标 ${target.label} 未返回可点击位置。');
    }
    await _recordTargetResolutionEvidence(
      evidenceRunId: evidenceRunId,
      node: node,
      target: target,
      loopIndex: loopIndex,
      result: result,
      confidenceThreshold: confidenceThreshold,
      type: 'targetResolution',
      status: 'ok',
      action: 'tap',
    );
    final duration = _optionalIntParameter(node, 'durationMs') ?? tapDurationMs;
    final tap = RuntimeTap(
      point: point,
      label: target.label,
      durationMs: duration,
    );
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '点击',
      label: tap.label,
    );
    try {
      await _deviceActions.tap(sessionId, tap);
    } finally {
      await _deviceActions.releaseActions(sessionId);
    }
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': tap.label,
      'loopIndex': loopIndex,
      'targetRef': target.id,
      'x': tap.point.x,
      'y': tap.point.y,
    });
  }

  // 执行 Wait 节点，等待期间遵守运行主循环的串行语义。
  Future<void> _runWaitNode({
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    final waitMs = _waitMsFromNode(node);
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '等待',
      label: '${waitMs}ms',
    );
    await _delay(Duration(milliseconds: waitMs));
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'ms': waitMs,
    });
  }

  // 执行 Swipe 节点，并确保滑动后释放 pointer actions。
  Future<void> _runSwipeNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    final swipe = _swipeFromNode(node);
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '滑动',
      label: swipe.label,
    );
    try {
      await _deviceActions.swipe(sessionId, swipe);
    } finally {
      await _deviceActions.releaseActions(sessionId);
    }
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': swipe.label,
      'loopIndex': loopIndex,
      'fromX': swipe.from.x,
      'fromY': swipe.from.y,
      'toX': swipe.to.x,
      'toY': swipe.to.y,
      'durationMs': swipe.durationMs,
    });
  }

  // 执行 Input 节点，证据中只记录文本长度。
  Future<void> _runInputNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    final input = _inputFromNode(node);
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '输入',
      label: input.label,
    );
    await _deviceActions.inputText(sessionId, input);
    await _recordEvidenceEvent(evidenceRunId, <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': input.label,
      'loopIndex': loopIndex,
      'textLength': input.text.length,
    });
  }

  // 执行 Snapshot 节点，并按节点配置决定是否写入截图证据。
  Future<void> _runSnapshotNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '截图',
      label: node.label,
    );
    final screenshot = await _deviceActions.screenshot(sessionId);
    _emit(
      _snapshot.copyWith(
        latestScreenshotBase64: screenshot,
        latestScreenshotAt: DateTime.now(),
      ),
    );
    final shouldSaveEvidence = node.parameters['saveEvidence'] != false;
    final screenshotPath = shouldSaveEvidence
        ? await _recordScreenshotEvidence(
            evidenceRunId,
            node: node,
            loopIndex: loopIndex,
            base64Png: screenshot,
          )
        : null;
    final event = <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
    };
    if (screenshotPath != null) {
      event['screenshotPath'] = screenshotPath;
    }
    await _recordEvidenceEvent(evidenceRunId, event);
  }
}

// 生成目标点击暂停时的用户可读说明。
// 低置信会包含阈值，其它状态保留 provider 返回的短诊断。
String _targetTapPauseMessage({
  required RuntimeTargetDefinition target,
  required TargetResolutionResult result,
  required double confidenceThreshold,
}) {
  if (result.status == TargetResolutionStatus.lowConfidence) {
    return '目标 ${target.label} 置信度 ${result.confidence ?? 0} 低于阈值 $confidenceThreshold。';
  }
  if (result.status == TargetResolutionStatus.notMatched) {
    return '未找到目标 ${target.label}。';
  }
  return result.message;
}
