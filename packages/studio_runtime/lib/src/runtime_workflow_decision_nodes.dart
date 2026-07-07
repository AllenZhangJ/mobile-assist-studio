part of '../studio_runtime.dart';

// 工作流判断节点分片，负责条件分支和视觉分支的执行语义。

extension StudioRuntimeControllerWorkflowDecisionNodes
    on StudioRuntimeController {
  /// 执行 Condition 节点，只允许读取安全 context 表达式。
  /// 表达式 truthy 时走第一条边，falsey 时走第二条边。
  Future<String?> _runConditionNode({
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
    required Map<String, Object?> workflowInputs,
  }) async {
    final expression = node.parameters['expression']?.toString() ?? '';
    if (!isSafeContextExpression(expression)) {
      throw StateError('条件节点 ${node.id} 表达式不安全。');
    }
    if (node.next.length > 2) {
      throw StateError('条件节点 ${node.id} 分支过多。');
    }
    final context = _workflowContext(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      workflowInputs: workflowInputs,
    );
    final value = _readContextExpression(expression, context);
    final passed = _truthyContextValue(value);
    final selectedNext = node.next.isEmpty
        ? null
        : passed
        ? node.next.first
        : node.next.length > 1
        ? node.next[1]
        : null;
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(
          'info',
          '第 ${loopIndex + 1}/$totalLoops 轮：条件 ${node.label} ${passed ? '通过' : '未通过'}。',
        ),
      ),
    );
    final conditionEvent = <String, Object?>{
      'type': 'stepEnd',
      'status': 'ok',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'expression': expression,
      'result': passed,
    };
    if (selectedNext != null) {
      conditionEvent['selectedNext'] = selectedNext;
    }
    await _recordEvidenceEvent(evidenceRunId, conditionEvent);
    return selectedNext;
  }

  /// 执行 Visual Branch 节点。
  /// 低置信或系统弹窗命中时进入人工介入暂停态。
  Future<String?> _runVisualBranchNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    final confidenceThreshold = _confidenceThresholdFromNode(node);
    final hasScreenshot =
        _snapshot.latestScreenshotBase64 != null &&
        _snapshot.latestScreenshotBase64!.isNotEmpty;
    final popupMatch = await _knownPopupMatch(sessionId);
    final targetRef = _targetRefFromNode(node);
    if (popupMatch == null && targetRef != null) {
      return _runTargetVisualBranchNode(
        sessionId: sessionId,
        node: node,
        targetRef: targetRef,
        confidenceThreshold: confidenceThreshold,
        hasScreenshot: hasScreenshot,
        loopIndex: loopIndex,
        totalLoops: totalLoops,
        evidenceRunId: evidenceRunId,
      );
    }
    final confidence = popupMatch == null
        ? hasScreenshot
              ? 1.0
              : 0.0
        : 1.0;
    final popupBlocked = popupMatch != null;
    final confidencePassed = confidence >= confidenceThreshold;
    final shouldContinue = confidencePassed && !popupBlocked;
    final selectedNext = shouldContinue && node.next.isNotEmpty
        ? node.next.single
        : null;
    final visualRule = popupMatch?.rule ?? 'latest_screenshot_presence';
    final visualReason =
        popupMatch?.reason ??
        (confidencePassed ? '最新截图可用，置信度已达标。' : '最新截图缺失或置信度不足。');
    final eventMessage = shouldContinue
        ? '第 ${loopIndex + 1}/$totalLoops 轮：视觉判断 ${node.label} 通过。'
        : popupMatch == null
        ? '第 ${loopIndex + 1}/$totalLoops 轮：视觉判断 ${node.label} 置信度不足，已暂停。'
        : '第 ${loopIndex + 1}/$totalLoops 轮：发现系统弹窗，已暂停。';
    final visualEvent = <String, Object?>{
      'type': 'stepEnd',
      'status': shouldContinue ? 'ok' : 'paused',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'confidence': confidence,
      'confidenceThreshold': confidenceThreshold,
      'result': shouldContinue,
    };
    if (selectedNext != null) {
      visualEvent['selectedNext'] = selectedNext;
    }
    visualEvent['visualRule'] = visualRule;
    visualEvent['screenshotAvailable'] = hasScreenshot;
    visualEvent['visualAction'] = shouldContinue ? 'continue' : 'pause';
    visualEvent['visualReason'] = visualReason;
    await _recordEvidenceEvent(evidenceRunId, visualEvent);
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(shouldContinue ? 'info' : 'warning', eventMessage),
      ),
    );
    if (!shouldContinue) {
      _emit(
        _snapshot.copyWith(
          executionFocus: _snapshot.executionFocus.copyWith(
            activeNodeId: null,
            failedNodeId: node.id,
          ),
        ),
      );
      throw _WorkflowPausedException(
        visualReason == '最新截图缺失或置信度不足。'
            ? '视觉判断 ${node.label} 置信度 $confidence 低于阈值 $confidenceThreshold。'
            : visualReason,
      );
    }
    return selectedNext;
  }

  /// 执行绑定 targetRef 的 Visual Branch。
  /// TargetResolver 只做解析，低置信、未命中或不支持都会暂停。
  Future<String?> _runTargetVisualBranchNode({
    required String sessionId,
    required WorkflowNode node,
    required String targetRef,
    required double confidenceThreshold,
    required bool hasScreenshot,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    final target = _snapshot.targetLibrary.targetById(targetRef);
    if (target == null) {
      throw StateError('视觉判断节点 ${node.id} 引用了不存在的目标。');
    }
    final result = hasScreenshot
        ? await _resolveTargetFromScreenshot(
            sessionId: sessionId,
            target: target,
            screenshotBase64: _snapshot.latestScreenshotBase64!,
            confidenceThreshold: confidenceThreshold,
          )
        : TargetResolutionResult.lowConfidence(confidence: 0);
    final confidence = result.confidence ?? 0;
    final shouldContinue = result.status == TargetResolutionStatus.matched;
    final selectedNext = shouldContinue && node.next.isNotEmpty
        ? node.next.single
        : null;
    final eventMessage = shouldContinue
        ? '第 ${loopIndex + 1}/$totalLoops 轮：视觉判断 ${node.label} 通过。'
        : '第 ${loopIndex + 1}/$totalLoops 轮：视觉判断 ${node.label} 目标未确认，已暂停。';
    final visualEvent = <String, Object?>{
      'type': 'stepEnd',
      'status': shouldContinue ? 'ok' : 'paused',
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'confidence': confidence,
      'confidenceThreshold': confidenceThreshold,
      'result': shouldContinue,
      'visualRule': 'target_${target.kind.name}',
      'screenshotAvailable': hasScreenshot,
      'visualAction': shouldContinue ? 'continue' : 'pause',
      'visualReason': result.message,
      'visualTargetKind': target.kind.name,
    };
    if (selectedNext != null) {
      visualEvent['selectedNext'] = selectedNext;
    }
    if (result.evidenceRef != null) {
      visualEvent['visualEvidenceRef'] = result.evidenceRef;
    }
    await _recordEvidenceEvent(evidenceRunId, visualEvent);
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(shouldContinue ? 'info' : 'warning', eventMessage),
      ),
    );
    if (!shouldContinue) {
      _emit(
        _snapshot.copyWith(
          executionFocus: _snapshot.executionFocus.copyWith(
            activeNodeId: null,
            failedNodeId: node.id,
          ),
        ),
      );
      throw _WorkflowPausedException(
        result.status == TargetResolutionStatus.lowConfidence
            ? '视觉判断 ${node.label} 置信度 $confidence 低于阈值 $confidenceThreshold。'
            : result.message,
      );
    }
    return selectedNext;
  }

  /// 执行 Wait For Target 节点。
  /// 它会串行截图并解析目标，超时或低置信进入暂停，不执行点击。
  Future<void> _runWaitForTargetNode({
    required String sessionId,
    required WorkflowNode node,
    required int loopIndex,
    required int totalLoops,
    required String? evidenceRunId,
  }) async {
    final targetRef = _targetRefFromNode(node);
    if (targetRef == null) {
      throw StateError('等目标节点 ${node.id} 需要目标。');
    }
    final target = _snapshot.targetLibrary.targetById(targetRef);
    if (target == null) {
      throw StateError('等目标节点 ${node.id} 引用了不存在的目标。');
    }
    final confidenceThreshold = _confidenceThresholdFromNode(node);
    final timeoutMs = _waitForTargetTimeoutMsFromNode(node);
    final intervalMs = _waitForTargetIntervalMsFromNode(node, timeoutMs);
    final maxAttempts = (timeoutMs / intervalMs).ceil().clamp(1, 10000);
    _emitNodeRunEvent(
      loopIndex: loopIndex,
      totalLoops: totalLoops,
      action: '等目标',
      label: target.label,
    );

    TargetResolutionResult result = TargetResolutionResult.notMatched();
    var attempts = 0;
    for (var attempt = 1; attempt <= maxAttempts; attempt += 1) {
      attempts = attempt;
      if (_stopRequested) {
        await _recordWaitForTargetEvidence(
          evidenceRunId: evidenceRunId,
          node: node,
          target: target,
          loopIndex: loopIndex,
          attempts: attempts,
          confidenceThreshold: confidenceThreshold,
          result: result,
          status: 'stopped',
          action: 'stop',
        );
        return;
      }
      final screenshot = await _deviceActions.screenshot(sessionId);
      _emit(
        _snapshot.copyWith(
          latestScreenshotBase64: screenshot,
          latestScreenshotAt: DateTime.now(),
        ),
      );
      result = await _resolveTargetFromScreenshot(
        sessionId: sessionId,
        target: target,
        screenshotBase64: screenshot,
        confidenceThreshold: confidenceThreshold,
      );
      if (result.status == TargetResolutionStatus.matched ||
          result.status == TargetResolutionStatus.unsupported ||
          result.status == TargetResolutionStatus.infrastructureError) {
        break;
      }
      if (attempt < maxAttempts) {
        await _delay(Duration(milliseconds: intervalMs));
      }
    }

    final matched = result.status == TargetResolutionStatus.matched;
    await _recordWaitForTargetEvidence(
      evidenceRunId: evidenceRunId,
      node: node,
      target: target,
      loopIndex: loopIndex,
      attempts: attempts,
      confidenceThreshold: confidenceThreshold,
      result: result,
      status: matched ? 'ok' : 'paused',
      action: matched ? 'continue' : 'pause',
    );
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(
          matched ? 'info' : 'warning',
          matched
              ? '第 ${loopIndex + 1}/$totalLoops 轮：目标 ${target.label} 已出现。'
              : '第 ${loopIndex + 1}/$totalLoops 轮：目标 ${target.label} 未确认，已暂停。',
        ),
      ),
    );
    if (!matched) {
      _emit(
        _snapshot.copyWith(
          executionFocus: _snapshot.executionFocus.copyWith(
            activeNodeId: null,
            failedNodeId: node.id,
          ),
        ),
      );
      throw _WorkflowPausedException(
        result.status == TargetResolutionStatus.lowConfidence
            ? '等目标 ${target.label} 置信度 ${result.confidence ?? 0} 低于阈值 $confidenceThreshold。'
            : result.message,
      );
    }
  }

  /// 记录 Wait For Target 的视觉证据。
  /// 证据只写目标类型、置信度、尝试次数和本地引用，不写截图内容。
  Future<void> _recordWaitForTargetEvidence({
    required String? evidenceRunId,
    required WorkflowNode node,
    required RuntimeTargetDefinition target,
    required int loopIndex,
    required int attempts,
    required double confidenceThreshold,
    required TargetResolutionResult result,
    required String status,
    required String action,
  }) async {
    final visualEvent = <String, Object?>{
      'type': 'stepEnd',
      'status': status,
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'confidence': result.confidence ?? 0,
      'confidenceThreshold': confidenceThreshold,
      'result': result.status == TargetResolutionStatus.matched,
      'visualRule': 'target_${target.kind.name}',
      'screenshotAvailable': _snapshot.latestScreenshotBase64 != null,
      'visualAction': action,
      'visualReason': result.message,
      'visualTargetKind': target.kind.name,
      'attempts': attempts,
    };
    if (result.evidenceRef != null) {
      visualEvent['visualEvidenceRef'] = result.evidenceRef;
    }
    await _recordEvidenceEvent(evidenceRunId, visualEvent);
  }
}
