part of '../studio_mac_workspace.dart';

// 状态详情 helper，负责把连接、驱动、流程和运行状态整理成抽屉可读信息。

// 生成状态详情分组，并把当前点击的状态置顶。
List<_StatusDetailSection> _statusDetailSections(
  StudioRuntimeSnapshot snapshot,
  _StatusDetailFocus focus,
) {
  final sections = [
    _deviceStatusDetail(snapshot),
    _driverStatusDetail(snapshot),
    _workflowStatusDetail(snapshot),
    _runStatusDetail(snapshot),
  ];
  final focused = sections.removeAt(focus.index);
  return [focused, ...sections];
}

// 生成设备状态详情，所有标识只展示脱敏短值。
_StatusDetailSection _deviceStatusDetail(StudioRuntimeSnapshot snapshot) {
  final entry = _usbDeviceReadinessEntry(snapshot.connectionStatus);
  final diagnostic = snapshot.lastConnectionDiagnostic;
  return _StatusDetailSection(
    title: '设备',
    status: _deviceStatusLabel(snapshot.connectionStatus),
    summary: diagnostic?.summary ?? entry.summary,
    nextStep: diagnostic?.nextStep ?? entry.nextStep,
    tone: diagnostic == null
        ? entry.tone
        : _connectionDiagnosticTone(diagnostic.type),
    icon: diagnostic == null
        ? entry.icon
        : _connectionDiagnosticIcon(diagnostic.type),
    fields: [
      const _StatusDetailField('模式', '单台有线手机'),
      if (diagnostic != null)
        _StatusDetailField('原因', _connectionDiagnosticLabel(diagnostic.type)),
      if (diagnostic != null && diagnostic.detail.isNotEmpty)
        _StatusDetailField('详情', diagnostic.detail),
      _StatusDetailField(
        '会话',
        snapshot.sessionId == null ? '未连接' : _shortSession(snapshot.sessionId!),
      ),
      _StatusDetailField(
        '截图',
        snapshot.latestScreenshotAt == null
            ? '暂无'
            : _timeOnly(snapshot.latestScreenshotAt!),
      ),
    ],
  );
}

// 生成本机驱动状态详情，环境检查只展示摘要和检查时间。
_StatusDetailSection _driverStatusDetail(StudioRuntimeSnapshot snapshot) {
  final entry = _appiumReadinessEntry(snapshot.appiumStatus);
  return _StatusDetailSection(
    title: '驱动',
    status: _appiumStatusLabel(snapshot.appiumStatus),
    summary: _safeRuntimeEventMessage(snapshot.appiumMessage),
    nextStep: entry.nextStep,
    tone: _toneForAppium(snapshot.appiumStatus),
    icon: entry.icon,
    fields: [
      _StatusDetailField('环境', snapshot.dependencyReport.message),
      _StatusDetailField('检查', _dependencyCheckedAt(snapshot.dependencyReport)),
    ],
  );
}

// 生成流程状态详情，合并 DSL 与本地子流程引用问题。
_StatusDetailSection _workflowStatusDetail(StudioRuntimeSnapshot snapshot) {
  final workflowValidation = _snapshotWorkflowValidation(snapshot);
  final entry = _workflowReadinessEntry(workflowValidation);
  final tapCount = snapshot.workflow.nodes
      .where((node) => node.type == WorkflowNodeType.tap)
      .length;
  final waitCount = snapshot.workflow.nodes
      .where((node) => node.type == WorkflowNodeType.wait)
      .length;
  return _StatusDetailSection(
    title: '流程',
    status: _workflowStatusLabel(workflowValidation),
    summary: entry.summary,
    nextStep: entry.nextStep,
    tone: _workflowStatusTone(workflowValidation),
    icon: entry.icon,
    fields: [
      _StatusDetailField('名称', snapshot.workflow.name),
      if (!workflowValidation.isValid)
        _StatusDetailField('问题', _workflowIssueSummary(workflowValidation)),
      _StatusDetailField('节点', '${snapshot.workflow.nodes.length} 个'),
      _StatusDetailField('点击', '$tapCount'),
      _StatusDetailField('等待', '$waitCount'),
    ],
  );
}

// 生成运行状态详情，聚合当前节点、问题节点和预计剩余时间。
_StatusDetailSection _runStatusDetail(StudioRuntimeSnapshot snapshot) {
  final status = snapshot.runStatus;
  final focus = snapshot.executionFocus;
  return _StatusDetailSection(
    title: '运行',
    status: _runStatusLabel(status),
    summary: _runStatusSummary(status),
    nextStep: _runStatusNextStep(status),
    tone: _toneForLiveRunStatus(status),
    icon: _iconForLiveRunStatus(status),
    fields: [
      _StatusDetailField('当前', focus.activeNodeId ?? '无'),
      _StatusDetailField('问题', focus.failedNodeId ?? '无'),
      _StatusDetailField('进度', _executionStepLabel(focus)),
      _StatusDetailField('剩余', _estimatedRemainingLabel(focus, status)),
    ],
  );
}

// 生成设备页准备度清单，供设备中心和状态指引用同一套结果。
List<_ReadinessGuideEntry> _deviceReadinessEntries(
  StudioRuntimeSnapshot snapshot,
) {
  return [
    _appiumReadinessEntry(snapshot.appiumStatus),
    _usbDeviceReadinessEntry(snapshot.connectionStatus),
    _developerTrustReadinessEntry(snapshot.connectionStatus),
    _wdaReadinessEntry(snapshot),
    _safeCaptureReadinessEntry(snapshot),
    _workflowReadinessEntry(_snapshotWorkflowValidation(snapshot)),
  ];
}

// 生成本机依赖检查清单，保持依赖详情与设备准备度展示一致。
List<_ReadinessGuideEntry> _dependencyReadinessEntries(
  LocalDependencyReport report,
) {
  return report.checks.map(_dependencyReadinessEntry).toList(growable: false);
}

// 将单项依赖检查转换为就绪指南条目。
_ReadinessGuideEntry _dependencyReadinessEntry(LocalDependencyCheck check) {
  return _ReadinessGuideEntry(
    label: check.label,
    status: _dependencyStatusLabel(check.status),
    summary: check.summary,
    nextStep: check.nextStep,
    tone: _toneForDependency(check.status),
    icon: _iconForDependency(check.id),
  );
}
