part of '../studio_runtime.dart';

// StudioRuntimeAiToolCommands 暴露 Batch 8 受控 AI / MCP 工具入口。
// 它只读 Runtime 状态或生成草稿，不直接点击、不运行、不写 workflow。
extension StudioRuntimeAiToolCommands on StudioRuntimeController {
  // 调用受控 AI 工具，并把结果写入可追踪审计日志。
  Future<AiToolInvocationResult> invokeAiTool(
    AiToolInvocationRequest request,
  ) async {
    final decision = const AiToolPermissionGate().decide(request);
    final tool = decision.tool;
    if (!decision.isAllowed) {
      return _finishAiTool(
        request: request,
        tool: tool,
        status: decision.status == AiToolDecisionStatus.needsConfirmation
            ? AiToolInvocationStatus.needsConfirmation
            : AiToolInvocationStatus.blocked,
        message: decision.message,
      );
    }

    switch (tool!.id) {
      case 'readCurrentScreenSummary':
        return _finishAiTool(
          request: request,
          tool: tool,
          status: AiToolInvocationStatus.completed,
          message: '已生成读屏摘要。',
          output: _aiScreenSummary(_snapshot),
        );
      case 'proposeWorkflowDraft':
        return _finishAiTool(
          request: request,
          tool: tool,
          status: AiToolInvocationStatus.completed,
          message: '已生成流程草稿。',
          output: _aiWorkflowDraft(request.arguments),
        );
      case 'explainRunFailure':
        return await _explainRunFailure(request, tool);
      case 'suggestTarget':
        return _finishAiTool(
          request: request,
          tool: tool,
          status: AiToolInvocationStatus.completed,
          message: '已生成目标建议。',
          output: _aiTargetSuggestions(_snapshot),
        );
      case 'suggestLocator':
        return _finishAiTool(
          request: request,
          tool: tool,
          status: AiToolInvocationStatus.completed,
          message: '已生成定位建议。',
          output: _aiLocatorSuggestions(_snapshot),
        );
      case 'suggestTemplateFix':
        return await _suggestTemplateFix(request, tool);
      case 'runWorkflow':
        return _finishAiTool(
          request: request,
          tool: tool,
          status: AiToolInvocationStatus.handoffRequired,
          message: '已确认，但 AI 不直接运行。请交给 Runtime 主按钮执行。',
          output: const <String, Object?>{
            'handoff': 'runtime.startRun',
            'requiresUserAction': true,
          },
        );
      default:
        return _finishAiTool(
          request: request,
          tool: tool,
          status: AiToolInvocationStatus.blocked,
          message: '工具尚未实现。',
        );
    }
  }

  // 读取运行报告并生成失败解释，缺少报告时安全降级。
  Future<AiToolInvocationResult> _explainRunFailure(
    AiToolInvocationRequest request,
    AiToolDefinition tool,
  ) async {
    final runId = _stringArgument(request.arguments, 'runId');
    if (runId == null) {
      return _finishAiTool(
        request: request,
        tool: tool,
        status: AiToolInvocationStatus.unavailable,
        message: '请选择一条运行记录。',
      );
    }
    final report = await _runReportReader.readReport(runId);
    if (report == null) {
      return _finishAiTool(
        request: request,
        tool: tool,
        status: AiToolInvocationStatus.unavailable,
        message: '未找到本地报告。',
      );
    }
    return _finishAiTool(
      request: request,
      tool: tool,
      status: AiToolInvocationStatus.completed,
      message: '已生成失败解释。',
      output: _aiFailureExplanation(report),
    );
  }

  // 读取运行报告并生成模板修复建议，缺少视觉证据时降级。
  Future<AiToolInvocationResult> _suggestTemplateFix(
    AiToolInvocationRequest request,
    AiToolDefinition tool,
  ) async {
    final runId = _stringArgument(request.arguments, 'runId');
    if (runId == null) {
      return _finishAiTool(
        request: request,
        tool: tool,
        status: AiToolInvocationStatus.unavailable,
        message: '请选择一条运行记录。',
      );
    }
    final report = await _runReportReader.readReport(runId);
    if (report == null) {
      return _finishAiTool(
        request: request,
        tool: tool,
        status: AiToolInvocationStatus.unavailable,
        message: '未找到本地报告。',
      );
    }
    return _finishAiTool(
      request: request,
      tool: tool,
      status: AiToolInvocationStatus.completed,
      message: '已生成模板建议。',
      output: _aiTemplateFixSuggestions(report),
    );
  }

  // 统一完成工具调用，确保事件和审计日志同步写入。
  AiToolInvocationResult _finishAiTool({
    required AiToolInvocationRequest request,
    required AiToolDefinition? tool,
    required AiToolInvocationStatus status,
    required String message,
    Map<String, Object?> output = const <String, Object?>{},
  }) {
    final at = DateTime.now();
    final callId = _newAiCallId(at);
    final result = AiToolInvocationResult(
      callId: callId,
      toolId: tool?.id ?? request.toolId,
      status: status,
      message: message,
      at: at,
      output: output,
    );
    final audit = AiToolAuditEntry(
      callId: callId,
      toolId: tool?.id ?? request.toolId,
      risk: tool?.risk ?? AiToolRisk.forbidden,
      status: status,
      message: message,
      userConfirmed: request.userConfirmed,
      at: at,
    );
    _emit(
      _snapshot.copyWith(
        aiAuditLog: _appendAiAudit(audit),
        events: _appendEvent(_aiEventLevel(status), 'AI：$message'),
      ),
    );
    return result;
  }

  // 追加 AI 审计日志并保留最近 80 条，避免长期撑大快照。
  List<AiToolAuditEntry> _appendAiAudit(AiToolAuditEntry entry) {
    final entries = <AiToolAuditEntry>[..._snapshot.aiAuditLog, entry];
    if (entries.length <= 80) {
      return List<AiToolAuditEntry>.unmodifiable(entries);
    }
    return List<AiToolAuditEntry>.unmodifiable(
      entries.sublist(entries.length - 80),
    );
  }
}

// _aiScreenSummary 生成读屏摘要，不返回截图 base64。
Map<String, Object?> _aiScreenSummary(StudioRuntimeSnapshot snapshot) {
  final inspector = snapshot.inspectorSnapshot;
  final capabilities =
      inspector?.capabilities ?? snapshot.mobileRuntime.capabilities;
  return <String, Object?>{
    'connection': snapshot.connectionStatus.name,
    'run': snapshot.runStatus.name,
    'platform': snapshot.mobileRuntime.platform.name,
    'hasSession': snapshot.sessionId != null,
    'hasScreenshot':
        snapshot.latestScreenshotBase64 != null ||
        (inspector?.hasScreenshot ?? false),
    'inspector': <String, Object?>{
      'available': inspector != null,
      'elementCount': inspector?.elementCount ?? 0,
      'sourceSummary': inspector?.sourceSummary,
      'selectedElementId': inspector?.selectedElementId,
    },
    'capabilities': <String, Object?>{
      'screenshot': capabilities.screenshot,
      'tap': capabilities.tap,
      'swipe': capabilities.swipe,
      'input': capabilities.input,
      'pageSource': capabilities.pageSource,
    },
  };
}

// _aiWorkflowDraft 生成只读流程草稿，不保存到项目真源。
Map<String, Object?> _aiWorkflowDraft(Map<String, Object?> arguments) {
  final targetRef = _stringArgument(arguments, 'targetRef');
  final workflow = WorkflowDefinition(
    id: 'ai_draft',
    name: 'AI 草稿',
    entryNodesId: 'start',
    nodes: <WorkflowNode>[
      const WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: <String>['snapshot'],
      ),
      WorkflowNode(
        id: 'snapshot',
        type: WorkflowNodeType.snapshot,
        label: '截图',
        next: <String>[targetRef == null ? 'wait' : 'tap_target'],
      ),
      if (targetRef == null)
        const WorkflowNode(
          id: 'wait',
          type: WorkflowNodeType.wait,
          label: '等待',
          next: <String>['end'],
          parameters: <String, Object?>{'ms': 500},
        )
      else
        WorkflowNode(
          id: 'tap_target',
          type: WorkflowNodeType.tap,
          label: '点目标',
          next: const <String>['end'],
          parameters: <String, Object?>{'targetRef': targetRef},
        ),
      const WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
  return <String, Object?>{
    'draftOnly': true,
    'requiresUserReview': true,
    'workflow': workflow.toJson(),
  };
}

// _aiFailureExplanation 将本地报告转成短中文解释和下一步建议。
Map<String, Object?> _aiFailureExplanation(RunLocalReport report) {
  final category = report.issue.category;
  final reason = report.issue.reason ?? '暂无明确失败原因。';
  return <String, Object?>{
    'summary': _failureSummary(category),
    'category': category,
    'node': report.issue.nodeLabel ?? report.issue.nodeId,
    'reason': reason,
    'platform': report.platform.platform,
    'nextSteps': _failureNextSteps(report),
    'evidence': <String, Object?>{
      'timeline': report.timeline.length,
      'visualChecks': report.visualChecks.length,
      'screenshots': report.screenshots.length,
      'logs': report.logSummary.errorEvents + report.logSummary.warningEvents,
    },
  };
}

// _aiTargetSuggestions 根据当前元素树生成目标草稿，不写入 Target Store。
Map<String, Object?> _aiTargetSuggestions(StudioRuntimeSnapshot snapshot) {
  final root = snapshot.inspectorSnapshot?.rootElement;
  final candidates = root == null
      ? const <Map<String, Object?>>[]
      : _flattenInspectorElements(root)
            .where(_elementCanBecomeTarget)
            .take(5)
            .map(_targetSuggestionFromElement)
            .toList(growable: false);
  return <String, Object?>{
    'draftOnly': true,
    'count': candidates.length,
    'targets': candidates,
  };
}

// _aiLocatorSuggestions 根据当前元素树生成受控 selector 短语法。
Map<String, Object?> _aiLocatorSuggestions(StudioRuntimeSnapshot snapshot) {
  final root = snapshot.inspectorSnapshot?.rootElement;
  final locators = root == null
      ? const <Map<String, Object?>>[]
      : _flattenInspectorElements(root)
            .where(_elementCanBecomeTarget)
            .take(5)
            .map(_locatorSuggestionFromElement)
            .toList(growable: false);
  return <String, Object?>{
    'draftOnly': true,
    'count': locators.length,
    'locators': locators,
  };
}

// _aiTemplateFixSuggestions 根据视觉失败证据生成模板修复建议。
Map<String, Object?> _aiTemplateFixSuggestions(RunLocalReport report) {
  final weakChecks = report.visualChecks.where(_visualCheckNeedsFix).toList();
  return <String, Object?>{
    'count': weakChecks.length,
    'suggestions': weakChecks
        .map(_templateFixFromCheck)
        .toList(growable: false),
    'fallback': weakChecks.isEmpty ? '未发现低置信视觉证据，可先复查目标库和运行日志。' : null,
  };
}

// _flattenInspectorElements 展开元素树，保持原有树顺序。
List<InspectorElementSummary> _flattenInspectorElements(
  InspectorElementSummary root,
) {
  final result = <InspectorElementSummary>[root];
  for (final child in root.children) {
    result.addAll(_flattenInspectorElements(child));
  }
  return result;
}

// _elementCanBecomeTarget 判断元素是否有可生成定位的信息。
bool _elementCanBecomeTarget(InspectorElementSummary element) {
  return (element.label != null && element.label!.trim().isNotEmpty) ||
      (element.value != null && element.value!.trim().isNotEmpty) ||
      element.bounds != null;
}

// _targetSuggestionFromElement 生成目标草稿。
Map<String, Object?> _targetSuggestionFromElement(
  InspectorElementSummary element,
) {
  final label = element.label ?? element.value ?? element.type;
  final selector = _selectorForElement(element);
  return <String, Object?>{
    'targetId': _safeAiId('target_$label'),
    'label': _sanitizeReportText(label),
    'kind': selector == null ? 'region' : 'selector',
    'payload': selector == null
        ? _regionPayload(element.bounds)
        : <String, Object?>{'selector': selector},
  };
}

// _locatorSuggestionFromElement 生成 selector 建议。
Map<String, Object?> _locatorSuggestionFromElement(
  InspectorElementSummary element,
) {
  return <String, Object?>{
    'elementId': element.id,
    'label': element.label ?? element.value ?? element.type,
    'selector': _selectorForElement(element),
    'fallback': element.bounds == null ? null : _regionPayload(element.bounds),
  };
}

// _selectorForElement 使用项目允许的短语法，不生成 XPath / CSS / 脚本。
String? _selectorForElement(InspectorElementSummary element) {
  final label = element.label?.trim();
  if (label != null && label.isNotEmpty) return 'label=$label';
  final value = element.value?.trim();
  if (value != null && value.isNotEmpty) return 'value=$value';
  final type = element.type.trim();
  if (type.isNotEmpty) return 'type=$type';
  return null;
}

// _regionPayload 把元素边界转成区域目标草稿。
Map<String, Object?>? _regionPayload(RuntimeRegion? region) {
  if (region == null) return null;
  return <String, Object?>{
    'x': region.x.round(),
    'y': region.y.round(),
    'width': region.width.round(),
    'height': region.height.round(),
  };
}

// _visualCheckNeedsFix 判断视觉证据是否需要修复建议。
bool _visualCheckNeedsFix(RunReportVisualCheck check) {
  final confidence = check.confidence;
  final threshold = check.confidenceThreshold;
  return check.result == false ||
      (confidence != null && threshold != null && confidence < threshold);
}

// _templateFixFromCheck 生成单条模板修复建议。
Map<String, Object?> _templateFixFromCheck(RunReportVisualCheck check) {
  return <String, Object?>{
    'node': check.label ?? check.nodeId,
    'rule': check.rule,
    'confidence': check.confidence,
    'threshold': check.confidenceThreshold,
    'nextSteps': <String>[
      '重新截取更稳定的目标区域。',
      '缩小模板，避开动态文字、角标和时间。',
      '必要时降低阈值，但低于阈值仍应暂停确认。',
    ],
  };
}

// _failureSummary 按失败分类生成简短解释。
String _failureSummary(String category) {
  switch (category) {
    case 'visual':
      return '视觉判断没有稳定命中。';
    case 'timeout':
      return '执行等待超时。';
    case 'device':
      return '设备或会话状态异常。';
    case 'workflow':
      return '流程结构或参数需要检查。';
    default:
      return '运行未按预期完成。';
  }
}

// _failureNextSteps 生成不会越权执行的下一步建议。
List<String> _failureNextSteps(RunLocalReport report) {
  final steps = <String>[];
  if (report.visualChecks.any(_visualCheckNeedsFix)) {
    steps.add('先查看视觉证据，确认模板或目标是否变化。');
  }
  if (report.screenshots.isNotEmpty) {
    steps.add('打开截图胶片，对比失败前后的界面状态。');
  }
  if (report.platform.platform == 'android' &&
      report.logSummary.errorEvents > 0) {
    steps.add('结合 Android 日志摘要排查应用或 UiAutomator2 状态。');
  }
  if (steps.isEmpty) {
    steps.add('从失败节点开始复查目标、等待时间和设备连接状态。');
  }
  return steps;
}

// _stringArgument 读取字符串参数，空白视为空。
String? _stringArgument(Map<String, Object?> arguments, String key) {
  final value = arguments[key];
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

// _safeAiId 生成安全草稿 ID。
String _safeAiId(String value) {
  final safe = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (safe.isEmpty) return 'ai_target';
  return safe.length > 60 ? safe.substring(0, 60) : safe;
}

// _newAiCallId 生成可追踪但不包含设备信息的调用 ID。
String _newAiCallId(DateTime at) {
  return 'ai_${at.microsecondsSinceEpoch}';
}

// _aiEventLevel 映射工具状态到 Runtime 事件等级。
String _aiEventLevel(AiToolInvocationStatus status) {
  switch (status) {
    case AiToolInvocationStatus.completed:
    case AiToolInvocationStatus.handoffRequired:
      return 'info';
    case AiToolInvocationStatus.needsConfirmation:
      return 'warning';
    case AiToolInvocationStatus.blocked:
    case AiToolInvocationStatus.unavailable:
      return 'warning';
  }
}
