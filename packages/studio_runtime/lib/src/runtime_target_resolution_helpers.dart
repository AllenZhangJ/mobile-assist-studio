part of '../studio_runtime.dart';

// 目标解析 helper 只负责截图、解析和证据字段组装。
// 它不执行设备动作，避免 Vision 能力绕过 Runtime 串行执行边界。
extension StudioRuntimeControllerTargetResolutionHelpers
    on StudioRuntimeController {
  // 截取当前屏幕并通过 TargetResolver 解析目标。
  // 截图会同步写入 Runtime snapshot，供后续面板和证据链复用。
  Future<TargetResolutionResult> _resolveTargetFromFreshScreenshot({
    required String sessionId,
    required RuntimeTargetDefinition target,
    required double confidenceThreshold,
  }) async {
    final screenshot = await _deviceActions.screenshot(sessionId);
    _emit(
      _snapshot.copyWith(
        latestScreenshotBase64: screenshot,
        latestScreenshotAt: DateTime.now(),
      ),
    );
    return _resolveTargetFromScreenshot(
      sessionId: sessionId,
      target: target,
      screenshotBase64: screenshot,
      confidenceThreshold: confidenceThreshold,
    );
  }

  // 使用指定截图解析目标。
  // Selector 目标会额外读取一次界面结构，其它目标不读取 source。
  Future<TargetResolutionResult> _resolveTargetFromScreenshot({
    required String? sessionId,
    required RuntimeTargetDefinition target,
    required String screenshotBase64,
    required double confidenceThreshold,
  }) async {
    final resolvedTarget = await _targetWithResolvedAsset(target);
    String? sourceXml;
    try {
      sourceXml = await _sourceXmlForTarget(
        sessionId: sessionId,
        target: resolvedTarget,
      );
    } on _TargetSourceReadException {
      return TargetResolutionResult.infrastructureError('界面结构读取失败。');
    }
    return _targetResolver.resolve(
      TargetResolutionRequest(
        target: resolvedTarget,
        platform: _snapshot.mobileRuntime.platform,
        capabilities: _snapshot.mobileRuntime.capabilities,
        screenshotBase64: screenshotBase64,
        confidenceThreshold: confidenceThreshold,
        sourceXml: sourceXml,
      ),
    );
  }

  // 仅 selector 目标需要 Appium source，读取失败时返回结构化基础设施错误。
  Future<String?> _sourceXmlForTarget({
    required String? sessionId,
    required RuntimeTargetDefinition target,
  }) async {
    if (target.kind != RuntimeTargetKind.selector &&
        target.kind != RuntimeTargetKind.text) {
      return null;
    }
    if (sessionId == null || sessionId.trim().isEmpty) return null;
    try {
      return await _deviceActions.pageSource(sessionId);
    } on Object {
      throw const _TargetSourceReadException();
    }
  }

  // 为图片目标补齐模板内容。
  // 目标库持久化只保存 imageRef，解析时才从本地资产读取模板。
  Future<RuntimeTargetDefinition> _targetWithResolvedAsset(
    RuntimeTargetDefinition target,
  ) async {
    if (target.kind != RuntimeTargetKind.image) return target;
    final inline = target.payload['imageBase64'];
    if (inline is String && inline.trim().isNotEmpty) return target;
    final imageRef = target.payload['imageRef'];
    if (imageRef is! String || imageRef.trim().isEmpty) return target;
    final imageBase64 = await _targetAssetStore.readImageTemplateBase64(
      imageRef,
    );
    if (imageBase64 == null || imageBase64.trim().isEmpty) return target;
    return RuntimeTargetDefinition(
      id: target.id,
      kind: target.kind,
      label: target.label,
      payload: Map<String, Object?>.unmodifiable({
        ...target.payload,
        'imageBase64': imageBase64,
      }),
    );
  }

  // 写入一次目标解析证据。
  // type 可使用 targetResolution 或 stepEnd，由调用节点决定是否影响节点路径。
  Future<void> _recordTargetResolutionEvidence({
    required String? evidenceRunId,
    required WorkflowNode node,
    required RuntimeTargetDefinition target,
    required int loopIndex,
    required TargetResolutionResult result,
    required double confidenceThreshold,
    required String type,
    required String status,
    required String action,
    int? attempts,
    String? selectedNext,
  }) async {
    final event = <String, Object?>{
      'type': type,
      'status': status,
      'nodeId': node.id,
      'nodeType': node.type.name,
      'label': node.label,
      'loopIndex': loopIndex,
      'confidence': result.confidence ?? 0,
      'confidenceThreshold': confidenceThreshold,
      'result': result.status == TargetResolutionStatus.matched,
      'visualRule': 'target_${target.kind.name}',
      'screenshotAvailable':
          _snapshot.latestScreenshotBase64 != null &&
          _snapshot.latestScreenshotBase64!.isNotEmpty,
      'visualAction': action,
      'visualReason': result.message,
      'visualTargetKind': target.kind.name,
    };
    if (attempts != null) {
      event['attempts'] = attempts;
    }
    if (selectedNext != null) {
      event['selectedNext'] = selectedNext;
    }
    if (result.evidenceRef != null) {
      event['visualEvidenceRef'] = result.evidenceRef;
    }
    await _recordEvidenceEvent(evidenceRunId, event);
  }

  // 将节点切入人工介入态并抛出暂停异常。
  // 调用前应已记录 paused 证据，避免暂停路径丢失现场。
  Never _pauseForTargetResolutionFailure({
    required WorkflowNode node,
    required String message,
  }) {
    _emit(
      _snapshot.copyWith(
        executionFocus: _snapshot.executionFocus.copyWith(
          activeNodeId: null,
          failedNodeId: node.id,
        ),
      ),
    );
    throw _WorkflowPausedException(message);
  }
}

// _TargetSourceReadException 表示界面结构读取失败。
// 调用方会把它收口成用户可理解的目标解析错误。
final class _TargetSourceReadException implements Exception {
  const _TargetSourceReadException();
}
