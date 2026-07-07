part of '../../studio_mac_workspace.dart';

// Inspector 草稿扩展，只负责把当前输入组装为可保存的节点草稿。
extension _NodeInspectorEditorDraftState on _NodeInspectorEditorState {
  // 从当前控制器生成节点草稿，并在 UI 层给出轻量错误。
  _NodeInspectorDraft _nodeDraftFromControllers() {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      return _NodeInspectorDraft(node: widget.node, error: '名称必填。');
    }

    final parameters = Map<String, Object?>.of(widget.node.parameters);
    final error = switch (widget.node.type) {
      WorkflowNodeType.tap => _applyTapDraft(parameters, label),
      WorkflowNodeType.wait => _applyWaitDraft(parameters),
      WorkflowNodeType.swipe => _applySwipeDraft(parameters, label),
      WorkflowNodeType.input => _applyInputDraft(parameters, label),
      WorkflowNodeType.loop => _applyLoopDraft(parameters),
      WorkflowNodeType.snapshot => _applySnapshotDraft(parameters),
      WorkflowNodeType.condition => _applyConditionDraft(parameters),
      WorkflowNodeType.visualBranch => _applyVisualBranchDraft(parameters),
      WorkflowNodeType.waitForTarget => _applyWaitForTargetDraft(parameters),
      WorkflowNodeType.catchNodes => _applyCatchDraft(parameters),
      WorkflowNodeType.subWorkflow => _applySubWorkflowDraft(parameters),
      WorkflowNodeType.start || WorkflowNodeType.end => null,
    };

    if (error != null) {
      return _NodeInspectorDraft(node: widget.node, error: error);
    }

    return _NodeInspectorDraft(
      node: widget.node.copyWith(label: label, parameters: parameters),
      error: null,
    );
  }

  // 写入点击节点参数，坐标必须是整数。
  String? _applyTapDraft(Map<String, Object?> parameters, String label) {
    final x = _parseInspectorInt(_xController);
    final y = _parseInspectorInt(_yController);
    if (x == null || y == null) {
      return '点击坐标必须是整数。';
    }
    parameters['x'] = x;
    parameters['y'] = y;
    parameters['label'] = label;
    return null;
  }

  // 写入等待节点参数，等待时间不能为负。
  String? _applyWaitDraft(Map<String, Object?> parameters) {
    final ms = _parseInspectorInt(_msController);
    if (ms == null || ms < 0) {
      return '等待时间不能为负。';
    }
    parameters['ms'] = ms;
    return null;
  }

  // 写入滑动节点参数，坐标和时长共同组成一次手势。
  String? _applySwipeDraft(Map<String, Object?> parameters, String label) {
    final fromX = _parseInspectorInt(_fromXController);
    final fromY = _parseInspectorInt(_fromYController);
    final toX = _parseInspectorInt(_toXController);
    final toY = _parseInspectorInt(_toYController);
    final durationMs = _parseInspectorInt(_durationController);
    if (fromX == null || fromY == null || toX == null || toY == null) {
      return '滑动坐标必须是整数。';
    }
    if (durationMs == null || durationMs < 0) {
      return '滑动时长不能为负。';
    }
    parameters['label'] = label;
    parameters['fromX'] = fromX;
    parameters['fromY'] = fromY;
    parameters['toX'] = toX;
    parameters['toY'] = toY;
    parameters['durationMs'] = durationMs;
    return null;
  }

  // 写入输入节点参数，文本保持用户原始输入。
  String? _applyInputDraft(Map<String, Object?> parameters, String label) {
    parameters['label'] = label;
    parameters['text'] = _textController.text;
    return null;
  }

  // 写入循环节点参数，限制最大轮数保护本地执行安全。
  String? _applyLoopDraft(Map<String, Object?> parameters) {
    final count = _parseInspectorInt(_loopCountController);
    if (count == null || count < 0 || count > 1000) {
      return '轮数需为 0 到 1000 的整数。';
    }
    parameters['count'] = count;
    return null;
  }

  // 写入截图节点参数，只记录是否保留证据。
  String? _applySnapshotDraft(Map<String, Object?> parameters) {
    parameters['saveEvidence'] = _saveEvidence;
    return null;
  }

  // 写入条件节点参数，表达式只能读取上下文。
  String? _applyConditionDraft(Map<String, Object?> parameters) {
    final expression = _expressionController.text.trim();
    if (!isSafeContextExpression(expression)) {
      return '条件只能读取上下文。';
    }
    parameters['expression'] = expression;
    return null;
  }

  // 写入视觉分支参数，置信度保持 0 到 1 的显式范围。
  String? _applyVisualBranchDraft(Map<String, Object?> parameters) {
    final confidence = double.tryParse(_confidenceController.text.trim());
    if (confidence == null || confidence < 0 || confidence > 1) {
      return '置信度需为 0 到 1。';
    }
    parameters['confidenceThreshold'] = confidence;
    return null;
  }

  // 写入等目标节点参数，目标引用和轮询时间都必须显式可控。
  String? _applyWaitForTargetDraft(Map<String, Object?> parameters) {
    final targetRef = _textController.text.trim();
    final timeoutMs = _parseInspectorInt(_msController);
    final intervalMs = _parseInspectorInt(_durationController);
    final confidence = double.tryParse(_confidenceController.text.trim());
    if (targetRef.isEmpty) {
      return '请选择目标。';
    }
    if (timeoutMs == null || timeoutMs <= 0 || timeoutMs > 600000) {
      return '超时需为正整数。';
    }
    if (intervalMs == null || intervalMs <= 0 || intervalMs > timeoutMs) {
      return '间隔不可大于超时。';
    }
    if (confidence == null || confidence < 0 || confidence > 1) {
      return '置信度需为 0 到 1。';
    }
    parameters['targetRef'] = targetRef;
    parameters['timeoutMs'] = timeoutMs;
    parameters['intervalMs'] = intervalMs;
    parameters['confidenceThreshold'] = confidence;
    return null;
  }

  // 写入异常节点参数，错误分支必须指向现有节点。
  String? _applyCatchDraft(Map<String, Object?> parameters) {
    final maxRetries = _parseInspectorInt(_maxRetriesController);
    if (maxRetries == null || maxRetries < 0) {
      return '重试次数不能为负。';
    }
    parameters['maxRetries'] = maxRetries;
    final onError = _onErrorController.text.trim();
    if (onError.isEmpty) {
      parameters.remove('onError');
      return null;
    }
    final targetExists = widget.workflow.nodes.any(
      (node) => node.id == onError,
    );
    if (!targetExists) {
      return '错误分支不存在。';
    }
    parameters['onError'] = onError;
    return null;
  }

  // 写入子流程参数，同时解析安全的上下文传参映射。
  String? _applySubWorkflowDraft(Map<String, Object?> parameters) {
    final workflowId = _workflowIdController.text.trim();
    if (workflowId.isEmpty) {
      return '请选择子流程。';
    }
    parameters['workflowId'] = workflowId;
    final inputMapResult = _parseSubWorkflowInputMapText(
      _inputMapController.text,
    );
    if (inputMapResult.error != null) {
      return inputMapResult.error;
    }
    if (inputMapResult.inputMap.isEmpty) {
      parameters.remove('inputMap');
    } else {
      parameters['inputMap'] = inputMapResult.inputMap;
    }
    return null;
  }
}

// 解析 Inspector 整数字段。
// 空值或非整数统一返回 null，由调用处给出面向用户的提示。
int? _parseInspectorInt(TextEditingController controller) {
  return int.tryParse(controller.text.trim());
}
