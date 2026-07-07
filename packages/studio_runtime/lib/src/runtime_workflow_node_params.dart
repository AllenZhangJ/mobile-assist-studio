part of '../studio_runtime.dart';

// Runtime 节点参数扩展，负责把 Project DSL 节点转换为可执行动作。
// 参数非法时抛出清晰错误，由执行层统一记录失败证据。
extension StudioRuntimeWorkflowNodeParams on StudioRuntimeController {
  // 从 Tap 节点读取坐标、标签和点击时长。
  // durationMs 缺失时使用当前运行配置的默认点击时长。
  RuntimeTap _tapFromNode(WorkflowNode node, int defaultDurationMs) {
    final targetRef = _targetRefFromNode(node);
    if (targetRef != null) {
      return _tapFromCoordinateTarget(node, targetRef, defaultDurationMs);
    }
    final x = _requiredIntParameter(node, 'x');
    final y = _requiredIntParameter(node, 'y');
    final duration =
        _optionalIntParameter(node, 'durationMs') ?? defaultDurationMs;
    return RuntimeTap(
      point: ViewportPoint(x: x, y: y),
      label: node.parameters['label']?.toString() ?? node.label,
      durationMs: duration,
    );
  }

  // 从坐标目标解析 Tap 节点。
  // 非坐标目标由动作节点先走 TargetResolver，再决定是否点击。
  RuntimeTap _tapFromCoordinateTarget(
    WorkflowNode node,
    String targetRef,
    int defaultDurationMs,
  ) {
    final target = _snapshot.targetLibrary.targetById(targetRef);
    if (target == null) {
      throw StateError('节点 ${node.id} 引用了不存在的目标。');
    }
    if (target.kind != RuntimeTargetKind.coordinate) {
      throw StateError('节点 ${node.id} 的目标暂不能直接点击。');
    }
    final x = _targetIntPayload(target, 'x');
    final y = _targetIntPayload(target, 'y');
    final duration =
        _optionalIntParameter(node, 'durationMs') ?? defaultDurationMs;
    return RuntimeTap(
      point: ViewportPoint(x: x, y: y),
      label: target.label,
      durationMs: duration,
    );
  }

  // 从 Wait 节点读取等待毫秒数。
  // 具体范围由 DSL validator 和执行错误共同兜底。
  int _waitMsFromNode(WorkflowNode node) {
    return _requiredIntParameter(node, 'ms');
  }

  // 从 Wait For Target 节点读取最长等待时间。
  // 超限会直接失败，避免视觉轮询误变成无限等待。
  int _waitForTargetTimeoutMsFromNode(WorkflowNode node) {
    final value = _requiredIntParameter(node, 'timeoutMs');
    if (value <= 0 || value > 600000) {
      throw StateError('等目标节点 ${node.id} 超时时间必须是 1 到 600000ms。');
    }
    return value;
  }

  // 从 Wait For Target 节点读取轮询间隔。
  // 缺省 500ms，既不高频打满设备，也足够给用户明确反馈。
  int _waitForTargetIntervalMsFromNode(WorkflowNode node, int timeoutMs) {
    final value = _optionalIntParameter(node, 'intervalMs') ?? 500;
    if (value <= 0 || value > 60000 || value > timeoutMs) {
      throw StateError('等目标节点 ${node.id} 检查间隔不可用。');
    }
    return value;
  }

  // 从 Swipe 节点读取起止坐标和时长。
  // 负时长会被执行前拦截，避免下发非法 WDA action。
  RuntimeSwipe _swipeFromNode(WorkflowNode node) {
    final duration = _optionalIntParameter(node, 'durationMs') ?? 450;
    if (duration < 0) {
      throw StateError('滑动节点 ${node.id} 时长不能小于 0。');
    }
    return RuntimeSwipe(
      from: ViewportPoint(
        x: _requiredIntParameter(node, 'fromX'),
        y: _requiredIntParameter(node, 'fromY'),
      ),
      to: ViewportPoint(
        x: _requiredIntParameter(node, 'toX'),
        y: _requiredIntParameter(node, 'toY'),
      ),
      label: node.parameters['label']?.toString() ?? node.label,
      durationMs: duration,
    );
  }

  // 从 Input 节点读取输入文本和标签。
  // 明文只进入 RuntimeInput，不写入日志和 evidence 事件。
  RuntimeInput _inputFromNode(WorkflowNode node) {
    final text = node.parameters['text']?.toString();
    if (text == null) {
      throw StateError('输入节点 ${node.id} 需要文本。');
    }
    return RuntimeInput(
      text: text,
      label: node.parameters['label']?.toString() ?? node.label,
    );
  }

  // 从 Loop 节点读取 bounded 循环次数。
  // 当前只允许 0 到 1000，防止无限循环或误操作。
  int _loopCountFromNode(WorkflowNode node) {
    final count = _requiredIntParameter(node, 'count');
    if (count < 0 || count > 1000) {
      throw StateError('循环节点 ${node.id} 次数必须是 0 到 1000 的整数。');
    }
    return count;
  }

  // 从 Visual Branch 节点读取置信度阈值。
  // 缺省值保持保守的 0.8，非法阈值直接失败。
  double _confidenceThresholdFromNode(WorkflowNode node) {
    final value = node.parameters['confidenceThreshold'];
    if (value == null) return 0.8;
    if (value is num && value.isFinite && value >= 0 && value <= 1) {
      return value.toDouble();
    }
    throw StateError('视觉判断节点 ${node.id} 置信度阈值必须在 0 到 1 之间。');
  }

  // 从 Sub Workflow 节点解析本地注册子流程引用。
  // 仅允许引用 Runtime 已注册的 Project DSL 子流程。
  _SubWorkflowTarget _subWorkflowTargetFromNode(WorkflowNode node) {
    final workflowId = node.parameters['workflowId']?.toString().trim();
    if (workflowId == null || workflowId.isEmpty) {
      throw StateError('子流程节点 ${node.id} 需要 workflowId。');
    }
    final workflow = _subWorkflows[workflowId];
    if (workflow == null) {
      throw StateError('子流程不存在：$workflowId。');
    }
    return _SubWorkflowTarget(workflowId: workflowId, workflow: workflow);
  }

  // 从 Sub Workflow 节点解析参数映射，并在父上下文中取值。
  // 只允许 inputMap 的值读取 context.xxx，不执行任意脚本。
  Map<String, Object?> _subWorkflowInputsFromNode(
    WorkflowNode node,
    Map<String, Object?> parentContext,
  ) {
    final inputMap = node.parameters['inputMap'];
    if (inputMap == null) return const <String, Object?>{};
    if (inputMap is! Map<String, Object?>) {
      throw StateError('子流程节点 ${node.id} 参数映射必须是对象。');
    }
    final resolved = <String, Object?>{};
    for (final entry in inputMap.entries) {
      final key = entry.key.trim();
      final expression = entry.value;
      if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key) ||
          expression is! String ||
          !isSafeContextExpression(expression)) {
        throw StateError('子流程节点 ${node.id} 参数映射不安全。');
      }
      resolved[key] = _readContextExpression(expression, parentContext);
    }
    return Map<String, Object?>.unmodifiable(resolved);
  }

  // 从 Catch 节点解析重试次数和错误分支。
  // onError 为空时异常继续失败退出，不会隐式吞掉错误。
  _ActiveCatch _activeCatchFromNode(WorkflowNode node) {
    final maxRetries = _optionalIntParameter(node, 'maxRetries') ?? 0;
    if (maxRetries < 0) {
      throw StateError('异常处理节点 ${node.id} 重试次数不能小于 0。');
    }
    final onError = node.parameters['onError']?.toString().trim();
    return _ActiveCatch(
      nodeId: node.id,
      label: node.label,
      maxRetries: maxRetries,
      onErrorNodeId: onError == null || onError.isEmpty ? null : onError,
    );
  }

  // 读取必填整数参数，缺失时给出节点级错误。
  // 该 helper 保持 Project DSL 的错误定位能力。
  int _requiredIntParameter(WorkflowNode node, String key) {
    final value = _optionalIntParameter(node, key);
    if (value == null) {
      throw StateError('Node ${node.id} requires integer parameter $key.');
    }
    return value;
  }

  // 读取可选整数参数，num 会按 round 归一。
  // 其他类型返回 null，由调用方决定是否允许缺省。
  int? _optionalIntParameter(WorkflowNode node, String key) {
    final value = node.parameters[key];
    if (value is int) return value;
    if (value is num && value.isFinite) return value.round();
    return null;
  }
}

// 读取目标整数 payload，目标库 validator 会在保存前兜底。
int _targetIntPayload(RuntimeTargetDefinition target, String key) {
  final value = target.payload[key];
  if (value is int) return value;
  if (value is num && value.isFinite) return value.round();
  throw StateError('目标 ${target.label} 缺少 $key。');
}
