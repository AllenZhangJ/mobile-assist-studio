part of '../studio_runtime.dart';

// Runtime 目标库项目命令，负责本地 Target Library 的受控写入。
// 所有命令只维护项目数据，不连接设备、不启动驱动、不执行 workflow。
extension StudioRuntimeTargetLibraryCommands on StudioRuntimeController {
  // 新增或更新目标，保存前必须通过目标库 validator。
  Future<bool> upsertTarget(RuntimeTargetDefinition target) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能修改目标。')));
      return false;
    }

    final targets = <RuntimeTargetDefinition>[
      for (final existing in _snapshot.targetLibrary.targets)
        if (existing.id != target.id) existing,
      target,
    ];
    return _saveTargetLibrary(targets, eventMessage: '目标已保存：${target.label}。');
  }

  // 创建并保存坐标目标，供 Recorder 和 Device Preview 快速沉淀目标资产。
  Future<RuntimeTargetDefinition?> createCoordinateTarget({
    required String label,
    required int x,
    required int y,
    int? viewportWidth,
    int? viewportHeight,
  }) async {
    final id = _targetIdFromLabel(label, DateTime.now());
    final target = RuntimeTargetDefinition.coordinate(
      id: id,
      label: label,
      x: x,
      y: y,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
    );
    final saved = await upsertTarget(target);
    return saved ? target : null;
  }

  // 创建并保存图片目标模板，供后续视觉定位和 Tap Target 使用。
  // 目标库只保存 imageRef，模板内容写入本地 targets/images。
  Future<RuntimeTargetDefinition?> createImageTargetFromTemplate({
    required String label,
    required String imageBase64,
  }) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能修改目标。')));
      return null;
    }
    final id = _targetIdFromLabel(label, DateTime.now());
    final imageRef = await _saveImageTargetAsset(
      targetId: id,
      imageBase64: imageBase64,
    );
    if (imageRef == null) return null;
    final target = RuntimeTargetDefinition(
      id: id,
      kind: RuntimeTargetKind.image,
      label: label,
      payload: <String, Object?>{'imageRef': imageRef},
    );
    final saved = await upsertTarget(target);
    return saved ? target : null;
  }

  // 删除未被当前 workflow 引用的目标。
  Future<bool> deleteTarget(String targetId) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能删除目标。')));
      return false;
    }
    final normalized = targetId.trim();
    if (normalized.isEmpty ||
        _snapshot.targetLibrary.targetById(normalized) == null) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '目标不存在。')));
      return false;
    }
    if (_workflowReferencesTarget(_snapshot.workflow, normalized)) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '当前流程正在使用该目标。')),
      );
      return false;
    }

    final targets = _snapshot.targetLibrary.targets
        .where((target) => target.id != normalized)
        .toList(growable: false);
    return _saveTargetLibrary(targets, eventMessage: '目标已删除。');
  }

  // 使用最近截图测试目标是否可解析。
  // 该命令只诊断目标质量，不刷新截图、不连接设备、不点击手机。
  Future<TargetResolutionResult?> testTargetAgainstLatestScreenshot(
    String targetId, {
    double confidenceThreshold = 0.8,
  }) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能测试目标。')));
      return null;
    }
    final target = _snapshot.targetLibrary.targetById(targetId);
    if (target == null) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '目标不存在。')));
      return null;
    }
    final screenshot = _snapshot.latestScreenshotBase64;
    if (screenshot == null || screenshot.trim().isEmpty) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '先截图。')));
      return null;
    }

    final resolvedTarget = await _targetWithResolvedAsset(target);
    final result = await _targetResolver.resolve(
      TargetResolutionRequest(
        target: resolvedTarget,
        platform: _snapshot.mobileRuntime.platform,
        capabilities: _snapshot.mobileRuntime.capabilities,
        screenshotBase64: screenshot,
        confidenceThreshold: confidenceThreshold,
      ),
    );
    _emit(
      _snapshot.copyWith(
        events: _appendEvent('info', _targetTestEventMessage(target, result)),
      ),
    );
    return result;
  }

  // 统一保存目标库，保证命令都走同一个校验和快照更新路径。
  Future<bool> _saveTargetLibrary(
    List<RuntimeTargetDefinition> targets, {
    required String eventMessage,
  }) async {
    final targetIssues = const TargetLibraryValidator().validate(targets);
    if (targetIssues.isNotEmpty) {
      _emit(
        _snapshot.copyWith(
          targetLibrary: _targetLibrarySnapshotFor(
            targets: targets,
            workflow: _snapshot.workflow,
          ),
          events: _appendEvent(
            'warning',
            '目标未保存：${targetIssues.map((issue) => issue.displayMessage).join(' ')}',
          ),
        ),
      );
      return false;
    }

    try {
      await _targetLibraryStore.saveTargets(targets);
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '目标保存失败：$error')));
      return false;
    }

    final targetLibrary = _targetLibrarySnapshotFor(
      targets: targets,
      workflow: _snapshot.workflow,
    );
    final validation = _workflowProjectValidationResult(
      _snapshot.workflow,
      _subWorkflows,
      targetLibrary,
    );
    _emit(
      _snapshot.copyWith(
        targetLibrary: targetLibrary,
        workflowIsValid: validation.isValid,
        events: _appendEvent('info', eventMessage),
      ),
    );
    return true;
  }

  // 保存图片模板资产，并把错误收口为 Runtime 事件。
  Future<String?> _saveImageTargetAsset({
    required String targetId,
    required String imageBase64,
  }) async {
    try {
      return await _targetAssetStore.saveImageTemplateBase64(
        targetId: targetId,
        imageBase64: imageBase64,
      );
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '图片目标未保存：$error')),
      );
      return null;
    }
  }
}

// 判断 workflow 是否引用指定目标 ID。
bool _workflowReferencesTarget(WorkflowDefinition workflow, String targetId) {
  return _referencedTargetIds(workflow).contains(targetId);
}

// 根据用户标签生成稳定安全的目标 ID。
String _targetIdFromLabel(String label, DateTime now) {
  final safeLabel = label
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final base = safeLabel.isEmpty ? 'target' : safeLabel;
  return '$base-${now.toUtc().microsecondsSinceEpoch}';
}

// 把目标测试结果转换成短中文事件。
String _targetTestEventMessage(
  RuntimeTargetDefinition target,
  TargetResolutionResult result,
) {
  return switch (result.status) {
    TargetResolutionStatus.matched => '已找到目标：${target.label}。',
    TargetResolutionStatus.lowConfidence => '目标不够准：${target.label}。',
    TargetResolutionStatus.notMatched => '未找到目标：${target.label}。',
    TargetResolutionStatus.unsupported => '目标暂不可测：${target.label}。',
    TargetResolutionStatus.infrastructureError => '目标测试失败：${target.label}。',
  };
}
