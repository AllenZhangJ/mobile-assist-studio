part of '../../studio_mac_workspace.dart';

// Workflow 节点能力徽标模型，集中把 Runtime 能力转成短中文提示。
// 它只做展示派生，不写 Project DSL，也不触发设备动作。
final class _WorkflowNodeCapabilityBadge {
  const _WorkflowNodeCapabilityBadge({
    required this.label,
    required this.tone,
    required this.detail,
  });

  final String label;
  final StudioStatusTone tone;
  final String detail;
}

// 根据当前平台、能力和目标库，为节点生成一个短能力徽标。
_WorkflowNodeCapabilityBadge? _workflowNodeCapabilityBadge({
  required WorkflowNode node,
  required TargetLibrarySnapshot targetLibrary,
  required ConnectionStatus connectionStatus,
  required MobileRuntimeSummary mobileRuntime,
  required StudioSettings settings,
}) {
  final targetIssue = _workflowNodeTargetCapabilityIssue(
    node: node,
    targetLibrary: targetLibrary,
  );
  if (targetIssue != null) return targetIssue;
  if (!_workflowNodeNeedsRuntimeCapability(node)) return null;

  if (connectionStatus != ConnectionStatus.connected ||
      mobileRuntime.platform == MobilePlatform.unknown) {
    return const _WorkflowNodeCapabilityBadge(
      label: '待连',
      tone: StudioStatusTone.offline,
      detail: '连接手机后会检查该节点能力。',
    );
  }

  final missing = _workflowNodeMissingCapabilityLabel(
    node: node,
    targetLibrary: targetLibrary,
    capabilities: mobileRuntime.capabilities,
    settings: settings,
  );
  if (missing != null) {
    return _WorkflowNodeCapabilityBadge(
      label: '缺$missing',
      tone: StudioStatusTone.warning,
      detail: '当前平台缺少该节点需要的$missing能力。',
    );
  }

  return _WorkflowNodeCapabilityBadge(
    label: '${_workflowPlatformShortLabel(mobileRuntime.platform)}可用',
    tone: StudioStatusTone.ready,
    detail: '当前平台具备该节点需要的基础能力。',
  );
}

// 优先展示目标引用问题，避免用户连接设备后才发现流程缺目标。
_WorkflowNodeCapabilityBadge? _workflowNodeTargetCapabilityIssue({
  required WorkflowNode node,
  required TargetLibrarySnapshot targetLibrary,
}) {
  if (!_workflowNodeRequiresTarget(node)) return null;
  final targetRef = _workflowNodeTargetRef(node);
  if (targetRef == null) {
    return const _WorkflowNodeCapabilityBadge(
      label: '需目标',
      tone: StudioStatusTone.warning,
      detail: '先选择目标，再运行该节点。',
    );
  }
  if (targetLibrary.targetById(targetRef) == null) {
    return const _WorkflowNodeCapabilityBadge(
      label: '缺目标',
      tone: StudioStatusTone.warning,
      detail: '该节点引用的目标不存在。',
    );
  }
  return null;
}

// 判断节点是否需要手机运行时能力。
bool _workflowNodeNeedsRuntimeCapability(WorkflowNode node) {
  return switch (node.type) {
    WorkflowNodeType.tap ||
    WorkflowNodeType.swipe ||
    WorkflowNodeType.input ||
    WorkflowNodeType.snapshot ||
    WorkflowNodeType.visualBranch ||
    WorkflowNodeType.waitForTarget => true,
    _ => false,
  };
}

// 判断节点是否必须绑定目标。
bool _workflowNodeRequiresTarget(WorkflowNode node) {
  return switch (node.type) {
    WorkflowNodeType.visualBranch || WorkflowNodeType.waitForTarget => true,
    _ => false,
  };
}

// 返回当前节点缺失的第一项用户可理解能力。
String? _workflowNodeMissingCapabilityLabel({
  required WorkflowNode node,
  required TargetLibrarySnapshot targetLibrary,
  required MobileDriverCapabilityReport capabilities,
  required StudioSettings settings,
}) {
  return switch (node.type) {
    WorkflowNodeType.tap => _missingTapCapability(
      node,
      targetLibrary,
      capabilities,
      settings,
    ),
    WorkflowNodeType.swipe => capabilities.swipe ? null : '滑动',
    WorkflowNodeType.input => capabilities.input ? null : '输入',
    WorkflowNodeType.snapshot => capabilities.screenshot ? null : '截图',
    WorkflowNodeType.visualBranch ||
    WorkflowNodeType.waitForTarget => _missingTargetReadCapability(
      node,
      targetLibrary,
      capabilities,
      settings,
      needsScreenshot: true,
    ),
    _ => null,
  };
}

// Tap 节点先要求点击能力，再按目标类型补充截图或元素能力。
String? _missingTapCapability(
  WorkflowNode node,
  TargetLibrarySnapshot targetLibrary,
  MobileDriverCapabilityReport capabilities,
  StudioSettings settings,
) {
  if (!capabilities.tap) return '点击';
  final target = _workflowNodeTarget(node, targetLibrary);
  if (target == null || target.kind == RuntimeTargetKind.coordinate) {
    return null;
  }
  return _missingCapabilityForTargetKind(
    target.kind,
    capabilities,
    settings,
    needsScreenshot: true,
  );
}

// 视觉判断和等待目标需要截图，再按目标类型补充元素或文字能力。
String? _missingTargetReadCapability(
  WorkflowNode node,
  TargetLibrarySnapshot targetLibrary,
  MobileDriverCapabilityReport capabilities,
  StudioSettings settings, {
  required bool needsScreenshot,
}) {
  final target = _workflowNodeTarget(node, targetLibrary);
  if (target == null) return null;
  return _missingCapabilityForTargetKind(
    target.kind,
    capabilities,
    settings,
    needsScreenshot: needsScreenshot,
  );
}

// 按目标类型检查当前运行时能力，返回短中文缺口。
String? _missingCapabilityForTargetKind(
  RuntimeTargetKind kind,
  MobileDriverCapabilityReport capabilities,
  StudioSettings settings, {
  required bool needsScreenshot,
}) {
  if (needsScreenshot && !capabilities.screenshot) return '截图';
  return switch (kind) {
    RuntimeTargetKind.coordinate => null,
    RuntimeTargetKind.region => null,
    RuntimeTargetKind.image => null,
    RuntimeTargetKind.selector =>
      _supportsElementTarget(capabilities) ? null : '元素',
    RuntimeTargetKind.text =>
      _supportsTextTarget(capabilities, settings) ? null : '文字',
  };
}

// 元素目标需要 Appium source 和受控 selector 解析能力。
bool _supportsElementTarget(MobileDriverCapabilityReport capabilities) {
  return capabilities.pageSource && capabilities.selectorTarget;
}

// 文本目标优先走 source，启用视觉增强时可由截图 OCR 兜底。
bool _supportsTextTarget(
  MobileDriverCapabilityReport capabilities,
  StudioSettings settings,
) {
  final sourceText = capabilities.pageSource && capabilities.selectorTarget;
  final ocrText =
      capabilities.screenshot &&
      (settings.enablePythonVision || capabilities.ocrTarget);
  return sourceText || ocrText;
}

// 读取节点 targetRef，空字符串按未配置处理。
String? _workflowNodeTargetRef(WorkflowNode node) {
  final value = node.parameters['targetRef'];
  if (value is! String) return null;
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

// 读取当前节点引用的目标定义。
RuntimeTargetDefinition? _workflowNodeTarget(
  WorkflowNode node,
  TargetLibrarySnapshot targetLibrary,
) {
  final targetRef = _workflowNodeTargetRef(node);
  return targetRef == null ? null : targetLibrary.targetById(targetRef);
}

// 平台短标签必须适配紧凑节点卡片。
String _workflowPlatformShortLabel(MobilePlatform platform) {
  return switch (platform) {
    MobilePlatform.ios => 'iOS',
    MobilePlatform.android => '安卓',
    MobilePlatform.unknown => '设备',
  };
}
