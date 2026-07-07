part of '../studio_mac_workspace.dart';

// Monitor 事件与节点轨迹展示 helper。
// 这里只处理详情抽屉的本地筛选、短中文摘要和状态色。

// 根据详情抽屉的轨迹筛选项过滤节点轨迹。
List<RunNodeTrace> _filterRunNodeTraces(
  List<RunNodeTrace> traces,
  _RunTraceFilter filter,
) {
  return switch (filter) {
    _RunTraceFilter.all => traces,
    _RunTraceFilter.issues =>
      traces.where(_runTraceHasIssue).toList(growable: false),
    _RunTraceFilter.screenshots =>
      traces
          .where((trace) => trace.screenshotPath != null)
          .toList(growable: false),
  };
}

// 根据详情抽屉的事件筛选项过滤运行事件。
List<RunEvidenceEvent> _filterRunEvents(
  List<RunEvidenceEvent> events,
  _RunEventFilter filter,
) {
  return switch (filter) {
    _RunEventFilter.all => events,
    _RunEventFilter.nodes =>
      events.where((event) => event.nodeId != null).toList(growable: false),
    _RunEventFilter.issues =>
      events.where(_runEventHasIssue).toList(growable: false),
    _RunEventFilter.screenshots =>
      events
          .where((event) => event.screenshotPath != null)
          .toList(growable: false),
  };
}

// 判断节点轨迹是否代表失败或暂停。
bool _runTraceHasIssue(RunNodeTrace trace) {
  return trace.error != null || trace.status == '失败' || trace.status == '暂停';
}

// 判断运行事件是否代表失败或暂停。
bool _runEventHasIssue(RunEvidenceEvent event) {
  return event.error != null || event.status == '失败' || event.status == '暂停';
}

// 返回运行事件筛选按钮的短标签。
String _labelForRunEventFilter(_RunEventFilter filter) {
  return switch (filter) {
    _RunEventFilter.all => '全部',
    _RunEventFilter.nodes => '节点',
    _RunEventFilter.issues => '问题',
    _RunEventFilter.screenshots => '截图',
  };
}

// 返回运行事件筛选按钮图标。
IconData _iconForRunEventFilter(_RunEventFilter filter) {
  return switch (filter) {
    _RunEventFilter.all => Icons.receipt_long_outlined,
    _RunEventFilter.nodes => Icons.account_tree_outlined,
    _RunEventFilter.issues => Icons.report_problem_outlined,
    _RunEventFilter.screenshots => Icons.photo_library_outlined,
  };
}

// 返回运行事件筛选按钮的状态色。
StudioStatusTone _toneForRunEventFilter(_RunEventFilter filter) {
  return switch (filter) {
    _RunEventFilter.all => StudioStatusTone.running,
    _RunEventFilter.nodes => StudioStatusTone.running,
    _RunEventFilter.issues => StudioStatusTone.warning,
    _RunEventFilter.screenshots => StudioStatusTone.running,
  };
}

// 返回节点轨迹筛选按钮的短标签。
String _labelForRunTraceFilter(_RunTraceFilter filter) {
  return switch (filter) {
    _RunTraceFilter.all => '全部',
    _RunTraceFilter.issues => '问题',
    _RunTraceFilter.screenshots => '截图',
  };
}

// 返回节点轨迹筛选按钮图标。
IconData _iconForRunTraceFilter(_RunTraceFilter filter) {
  return switch (filter) {
    _RunTraceFilter.all => Icons.account_tree_outlined,
    _RunTraceFilter.issues => Icons.report_problem_outlined,
    _RunTraceFilter.screenshots => Icons.photo_library_outlined,
  };
}

// 返回节点轨迹筛选按钮的状态色。
StudioStatusTone _toneForRunTraceFilter(_RunTraceFilter filter) {
  return switch (filter) {
    _RunTraceFilter.all => StudioStatusTone.running,
    _RunTraceFilter.issues => StudioStatusTone.warning,
    _RunTraceFilter.screenshots => StudioStatusTone.running,
  };
}

// 根据事件错误、状态和截图证据推导事件色。
StudioStatusTone _toneForRunEvent(RunEvidenceEvent event) {
  if (event.error != null) return StudioStatusTone.error;
  final status = event.status;
  if (status != null) return _toneForRunTraceStatus(status);
  if (event.screenshotPath != null) return StudioStatusTone.running;
  return StudioStatusTone.offline;
}

// 将运行事件类型转成短中文。
String _runEventTypeLabel(String type) {
  return switch (type) {
    'stepStart' => '步骤开始',
    'stepEnd' => '步骤结束',
    'subWorkflowStart' => '子流程',
    'runStart' => '开始运行',
    'runEnd' => '运行结束',
    _ => type,
  };
}

// 把可空 Runtime 节点类型转成短中文，缺失时返回安全兜底文案。
String _runNodeTypeLabel(String? nodeType) {
  if (nodeType == null || nodeType.trim().isEmpty) return '节点';
  return _runtimeNodeTypeLabel(nodeType);
}

// 返回 Monitor 可见节点名，缺少 label 时只用类型或短兜底，不暴露 nodeId。
String _monitorNodeDisplayLabel({
  required String? label,
  required String? nodeType,
  String fallback = '节点',
}) {
  final cleanLabel = label?.trim();
  if (cleanLabel != null && cleanLabel.isNotEmpty) return cleanLabel;
  final typeLabel = _runNodeTypeLabel(nodeType);
  if (typeLabel != '节点') return typeLabel;
  return fallback;
}

// 生成运行事件摘要，优先展示错误、截图或子流程传参。
String _runEventSummary(RunEvidenceEvent event) {
  final error = event.error?.trim();
  if (error != null && error.isNotEmpty) {
    return _safeRuntimeEventMessage(error);
  }
  if (event.screenshotPath != null) {
    return '已保存截图证据';
  }
  if (_runEventCanShowInputSummary(event)) {
    return _runEventInputSummary(event);
  }
  final parts = <String>[
    _runEventTypeLabel(event.type),
    if (event.status != null) _runTraceStatusLabelForStatus(event.status!),
  ];
  return parts.join(' / ');
}

// 判断事件是否是子流程传参证据，避免普通节点展示无意义输入信息。
bool _runEventCanShowInputSummary(RunEvidenceEvent event) {
  if (!event.hasInputSummary) return false;
  return event.type == 'subWorkflowStart' || event.nodeType == 'subWorkflow';
}

// 生成子流程传参摘要，只展示字段名和数量，不展示任何真实参数值。
String _runEventInputSummary(RunEvidenceEvent event) {
  final count = event.inputCount ?? event.inputNames.length;
  if (count <= 0) return '未传参';
  if (event.inputNames.isEmpty) return '传参 $count 项';
  final visibleNames = event.inputNames.take(3).toList(growable: false);
  final hiddenCount = count - visibleNames.length;
  final suffix = hiddenCount > 0 ? '等 $count 项' : '';
  return '传参 $count 项：${visibleNames.join('、')}$suffix';
}

// 根据节点轨迹错误和状态推导状态色。
StudioStatusTone _toneForRunTrace(RunNodeTrace trace) {
  if (trace.error != null) {
    return StudioStatusTone.error;
  }
  return _toneForRunTraceStatus(trace.status);
}

// 将节点轨迹状态文本映射成状态色。
StudioStatusTone _toneForRunTraceStatus(String status) {
  if (status == '失败') {
    return StudioStatusTone.error;
  }
  return switch (status) {
    'running' || '运行中' => StudioStatusTone.running,
    'paused' || '暂停' => StudioStatusTone.warning,
    'failed' || '失败' => StudioStatusTone.error,
    'ok' || 'completed' || 'success' || '正常' || '完成' => StudioStatusTone.ready,
    'stopped' || '已停' => StudioStatusTone.warning,
    _ => StudioStatusTone.offline,
  };
}

// 生成节点轨迹状态短标签，错误优先。
String _runTraceStatusLabel(RunNodeTrace trace) {
  if (trace.status == '失败' || trace.error != null) return '失败';
  return _runTraceStatusLabelForStatus(trace.status);
}

// 将底层状态文本转成用户可读短中文。
String _runTraceStatusLabelForStatus(String status) {
  return switch (status) {
    'running' || '运行中' => '运行中',
    'paused' || '暂停' => '暂停',
    'failed' || '失败' => '失败',
    'ok' || 'completed' || 'success' || '正常' || '完成' => '完成',
    'stopped' || '已停' => '已停',
    _ => status,
  };
}
