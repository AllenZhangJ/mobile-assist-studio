part of '../studio_runtime.dart';

// ConnectionStatus 表示设备连接生命周期。
// 它与运行状态分离，避免连接和执行互相污染。
enum ConnectionStatus {
  disconnected,
  initializing,
  connecting,
  waitingForDeveloperTrust,
  connected,
  disconnecting,
  error,
}

// RunStatus 表示工作流运行生命周期。
// 任务只有在 connected 且 idle 时才允许启动。
enum RunStatus { idle, running, paused, stopping }

// AppiumProcessStatus 表示本机 Appium 进程状态。
// 它只描述进程生命周期，不代表 WDA session 已建立。
enum AppiumProcessStatus { stopped, starting, running, stopping, error }

// AppiumProcessOwnership 表示当前驱动服务是否由本应用管理。
// UI 用它避免把外部启动的驱动误报为可停止。
enum AppiumProcessOwnership { unknown, managed, external }

// RuntimeEvent 是 Runtime 对 UI 暴露的短事件。
// 事件文案应保持中文、脱敏和可读。
final class RuntimeEvent {
  // 创建运行事件，未传时间时使用当前时间。
  RuntimeEvent({required this.level, required this.message, DateTime? at})
    : at = at ?? DateTime.now();

  final String level;
  final String message;
  final DateTime at;
}

// RuntimeExecutionFocus 描述当前执行焦点。
// Execute、Workflow 和 Monitor 用它展示节点进度。
final class RuntimeExecutionFocus {
  // 创建执行焦点状态。
  const RuntimeExecutionFocus({
    required this.activeNodeId,
    required this.completedNodeIds,
    required this.failedNodeId,
    required this.activeLoopIndex,
    required this.totalLoops,
    this.runStartedAt,
    this.completedSteps = 0,
    this.totalSteps,
  });

  final String? activeNodeId;
  final Set<String> completedNodeIds;
  final String? failedNodeId;
  final int? activeLoopIndex;
  final int? totalLoops;
  final DateTime? runStartedAt;
  final int completedSteps;
  final int? totalSteps;

  // 判断当前是否有可展示的执行痕迹。
  bool get hasRunTrace =>
      activeNodeId != null ||
      completedNodeIds.isNotEmpty ||
      failedNodeId != null ||
      completedSteps > 0;

  // 复制执行焦点，支持将字段显式置空。
  RuntimeExecutionFocus copyWith({
    Object? activeNodeId = _unset,
    Set<String>? completedNodeIds,
    Object? failedNodeId = _unset,
    Object? activeLoopIndex = _unset,
    Object? totalLoops = _unset,
    Object? runStartedAt = _unset,
    int? completedSteps,
    Object? totalSteps = _unset,
  }) {
    return RuntimeExecutionFocus(
      activeNodeId: identical(activeNodeId, _unset)
          ? this.activeNodeId
          : activeNodeId as String?,
      completedNodeIds: completedNodeIds ?? this.completedNodeIds,
      failedNodeId: identical(failedNodeId, _unset)
          ? this.failedNodeId
          : failedNodeId as String?,
      activeLoopIndex: identical(activeLoopIndex, _unset)
          ? this.activeLoopIndex
          : activeLoopIndex as int?,
      totalLoops: identical(totalLoops, _unset)
          ? this.totalLoops
          : totalLoops as int?,
      runStartedAt: identical(runStartedAt, _unset)
          ? this.runStartedAt
          : runStartedAt as DateTime?,
      completedSteps: completedSteps ?? this.completedSteps,
      totalSteps: identical(totalSteps, _unset)
          ? this.totalSteps
          : totalSteps as int?,
    );
  }

  static const empty = RuntimeExecutionFocus(
    activeNodeId: null,
    completedNodeIds: <String>{},
    failedNodeId: null,
    activeLoopIndex: null,
    totalLoops: null,
  );
}

// SubWorkflowSummary 是 UI 可见的子流程摘要。
// 它不包含设备、session、路径或底层 payload。
final class SubWorkflowSummary {
  // 创建子流程摘要。
  const SubWorkflowSummary({
    required this.workflowId,
    required this.name,
    required this.nodeCount,
    required this.isValid,
    this.referencedWorkflowIds = const <String>[],
  });

  final String workflowId;
  final String name;
  final int nodeCount;
  final bool isValid;
  final List<String> referencedWorkflowIds;

  // 从本地子流程表生成排序后的脱敏摘要列表。
  static List<SubWorkflowSummary> fromWorkflows(
    Map<String, WorkflowDefinition> workflows,
  ) {
    final validator = const WorkflowValidator();
    final summaries = workflows.entries
        .map((entry) {
          final validation = validator.validate(entry.value);
          return SubWorkflowSummary(
            workflowId: entry.key,
            name: entry.value.name,
            nodeCount: entry.value.nodes.length,
            isValid: validation.isValid,
            referencedWorkflowIds: _referencedSubWorkflowIds(
              entry.value,
            ).toList(growable: false)..sort(),
          );
        })
        .toList(growable: false);
    summaries.sort((a, b) => a.workflowId.compareTo(b.workflowId));
    return List<SubWorkflowSummary>.unmodifiable(summaries);
  }
}

// StudioRuntimeSnapshot 是 Flutter App 消费的运行时快照。
// 所有 UI 状态从这里派生，保持单向数据流。
final class StudioRuntimeSnapshot {
  // 创建运行时快照。
  const StudioRuntimeSnapshot({
    required this.connectionStatus,
    required this.runStatus,
    required this.appiumStatus,
    this.appiumOwnership = AppiumProcessOwnership.unknown,
    required this.appiumMessage,
    required this.lastConnectionDiagnostic,
    required this.sessionId,
    required this.workflow,
    required this.workflowIsValid,
    required this.targetLibrary,
    required this.latestScreenshotBase64,
    required this.latestScreenshotAt,
    required this.inspectorSnapshot,
    required this.dependencyReport,
    required this.mobileRuntime,
    required this.runHistory,
    required this.executionFocus,
    required this.subWorkflows,
    required this.settings,
    required this.aiAuditLog,
    required this.events,
  });

  // 构建初始快照，优先使用传入 workflow，否则回退 A-F 模板。
  factory StudioRuntimeSnapshot.initial({
    WorkflowDefinition? workflow,
    List<RuntimeTargetDefinition> targets = const <RuntimeTargetDefinition>[],
    Map<String, WorkflowDefinition> subWorkflows = const {},
    StudioSettings settings = StudioSettings.defaults,
  }) {
    final initialWorkflow = workflow ?? WorkflowDefinition.afTemplate();
    final validation = const WorkflowValidator().validate(initialWorkflow);
    final targetLibrary = _targetLibrarySnapshotFor(
      targets: List<RuntimeTargetDefinition>.of(targets),
      workflow: initialWorkflow,
    );
    return StudioRuntimeSnapshot(
      connectionStatus: ConnectionStatus.disconnected,
      runStatus: RunStatus.idle,
      appiumStatus: AppiumProcessStatus.stopped,
      appiumOwnership: AppiumProcessOwnership.unknown,
      appiumMessage: '尚未检查本机驱动。',
      lastConnectionDiagnostic: null,
      sessionId: null,
      workflow: initialWorkflow,
      workflowIsValid: validation.isValid,
      targetLibrary: targetLibrary,
      latestScreenshotBase64: null,
      latestScreenshotAt: null,
      inspectorSnapshot: null,
      dependencyReport: LocalDependencyReport.empty,
      mobileRuntime: MobileRuntimeSummary.initial,
      runHistory: RunHistorySummary.empty,
      executionFocus: RuntimeExecutionFocus.empty,
      subWorkflows: SubWorkflowSummary.fromWorkflows(subWorkflows),
      settings: settings,
      aiAuditLog: const <AiToolAuditEntry>[],
      events: <RuntimeEvent>[
        RuntimeEvent(level: 'info', message: '工作台运行时已就绪。'),
      ],
    );
  }

  final ConnectionStatus connectionStatus;
  final RunStatus runStatus;
  final AppiumProcessStatus appiumStatus;
  final AppiumProcessOwnership appiumOwnership;
  final String appiumMessage;
  final RuntimeConnectionDiagnostic? lastConnectionDiagnostic;
  final String? sessionId;
  final WorkflowDefinition workflow;
  final bool workflowIsValid;
  final TargetLibrarySnapshot targetLibrary;
  final String? latestScreenshotBase64;
  final DateTime? latestScreenshotAt;
  final InspectorSnapshot? inspectorSnapshot;
  final LocalDependencyReport dependencyReport;
  final MobileRuntimeSummary mobileRuntime;
  final RunHistorySummary runHistory;
  final RuntimeExecutionFocus executionFocus;
  final List<SubWorkflowSummary> subWorkflows;
  final StudioSettings settings;
  final List<AiToolAuditEntry> aiAuditLog;
  final List<RuntimeEvent> events;

  // 复制快照，支持 session 和截图字段显式置空。
  StudioRuntimeSnapshot copyWith({
    ConnectionStatus? connectionStatus,
    RunStatus? runStatus,
    AppiumProcessStatus? appiumStatus,
    AppiumProcessOwnership? appiumOwnership,
    String? appiumMessage,
    Object? lastConnectionDiagnostic = _unset,
    Object? sessionId = _unset,
    WorkflowDefinition? workflow,
    bool? workflowIsValid,
    TargetLibrarySnapshot? targetLibrary,
    Object? latestScreenshotBase64 = _unset,
    Object? latestScreenshotAt = _unset,
    Object? inspectorSnapshot = _unset,
    LocalDependencyReport? dependencyReport,
    MobileRuntimeSummary? mobileRuntime,
    RunHistorySummary? runHistory,
    RuntimeExecutionFocus? executionFocus,
    List<SubWorkflowSummary>? subWorkflows,
    StudioSettings? settings,
    List<AiToolAuditEntry>? aiAuditLog,
    List<RuntimeEvent>? events,
  }) {
    return StudioRuntimeSnapshot(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      runStatus: runStatus ?? this.runStatus,
      appiumStatus: appiumStatus ?? this.appiumStatus,
      appiumOwnership: appiumOwnership ?? this.appiumOwnership,
      appiumMessage: appiumMessage ?? this.appiumMessage,
      lastConnectionDiagnostic: identical(lastConnectionDiagnostic, _unset)
          ? this.lastConnectionDiagnostic
          : lastConnectionDiagnostic as RuntimeConnectionDiagnostic?,
      sessionId: identical(sessionId, _unset)
          ? this.sessionId
          : sessionId as String?,
      workflow: workflow ?? this.workflow,
      workflowIsValid: workflowIsValid ?? this.workflowIsValid,
      targetLibrary: targetLibrary ?? this.targetLibrary,
      latestScreenshotBase64: identical(latestScreenshotBase64, _unset)
          ? this.latestScreenshotBase64
          : latestScreenshotBase64 as String?,
      latestScreenshotAt: identical(latestScreenshotAt, _unset)
          ? this.latestScreenshotAt
          : latestScreenshotAt as DateTime?,
      inspectorSnapshot: identical(inspectorSnapshot, _unset)
          ? this.inspectorSnapshot
          : inspectorSnapshot as InspectorSnapshot?,
      dependencyReport: dependencyReport ?? this.dependencyReport,
      mobileRuntime: mobileRuntime ?? this.mobileRuntime,
      runHistory: runHistory ?? this.runHistory,
      executionFocus: executionFocus ?? this.executionFocus,
      subWorkflows: subWorkflows ?? this.subWorkflows,
      settings: settings ?? this.settings,
      aiAuditLog: aiAuditLog ?? this.aiAuditLog,
      events: events ?? this.events,
    );
  }
}

const Object _unset = Object();
