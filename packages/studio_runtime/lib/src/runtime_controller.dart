part of '../studio_runtime.dart';

// StudioRuntimeController 是 Runtime 的状态和依赖中心。
// 具体命令拆到 extension 分片，主类只保留构造、快照和广播能力。
final class StudioRuntimeController {
  // 创建 Runtime Controller，可注入所有外部依赖以便测试。
  StudioRuntimeController({
    AppiumAvailabilityChecker? availabilityProbe,
    LocalDependencyChecker? dependencyChecker,
    AppiumProcessManager? processManager,
    AppiumProcessCleaner? appiumCleaner,
    AppiumTunnelProcessManager? tunnelManager,
    AppiumTunnelProcessCleaner? tunnelCleaner,
    RuntimeSessionManager? sessionManager,
    DeviceActionExecutor? deviceActions,
    RunEvidenceStore? evidenceStore,
    RunHistoryReader? runHistoryReader,
    RunDetailReader? runDetailReader,
    RunReportReader? runReportReader,
    RunReportExporter? runReportExporter,
    RunEvidenceAssetReader? runEvidenceAssetReader,
    WorkflowStore? workflowStore,
    SubWorkflowStore? subWorkflowStore,
    TargetLibraryStore? targetLibraryStore,
    TargetAssetStore? targetAssetStore,
    TargetResolver? targetResolver,
    SettingsStore? settingsStore,
    UsbDeviceDiscovery? usbDeviceDiscovery,
    DeviceBindingStore? deviceBindingStore,
    Map<String, WorkflowDefinition> subWorkflows = const {},
    List<RuntimeTargetDefinition> targets = const <RuntimeTargetDefinition>[],
    RuntimeDelay delay = defaultRuntimeDelay,
    WorkflowDefinition? workflow,
    StudioSettings settings = StudioSettings.defaults,
    this.requiresAppiumTunnel = false,
    this.defaultTapDurationMs = 80,
    this.appiumReadinessTimeout = const Duration(seconds: 10),
    this.appiumReadinessInterval = const Duration(milliseconds: 300),
    this.appiumReadinessMaxAttempts = 40,
  }) : _availabilityProbe =
           availabilityProbe ?? AppiumAvailabilityProbe(AppiumClient()),
       _dependencyChecker = dependencyChecker ?? const LocalDependencyProbe(),
       _processManager = processManager ?? AppiumProcessManager(),
       _appiumCleaner = appiumCleaner ?? const ScopedAppiumProcessCleaner(),
       _tunnelManager = tunnelManager ?? AppiumTunnelProcessManager(),
       _tunnelCleaner = tunnelCleaner ?? const SudoAppiumTunnelProcessCleaner(),
       _sessionManager = sessionManager ?? DeviceSessionManager(),
       _deviceActions = deviceActions ?? AppiumDeviceActionExecutor(),
       _evidenceStore = evidenceStore ?? const NoopRunEvidenceStore(),
       _runHistoryReader = _resolveRunHistoryReader(
         runHistoryReader,
         evidenceStore,
       ),
       _runDetailReader = _resolveRunDetailReader(
         runDetailReader,
         evidenceStore,
       ),
       _runReportReader = _resolveRunReportReader(
         runReportReader,
         evidenceStore,
       ),
       _runReportExporter = _resolveRunReportExporter(
         runReportExporter,
         evidenceStore,
       ),
       _runEvidenceAssetReader = _resolveRunEvidenceAssetReader(
         runEvidenceAssetReader,
         evidenceStore,
       ),
       _workflowStore = workflowStore ?? const NoopWorkflowStore(),
       _subWorkflowStore = subWorkflowStore ?? const NoopSubWorkflowStore(),
       _targetLibraryStore =
           targetLibraryStore ?? const NoopTargetLibraryStore(),
       _targetAssetStore = targetAssetStore ?? const NoopTargetAssetStore(),
       _targetResolver = targetResolver ?? _targetResolverForSettings(settings),
       _usesInjectedTargetResolver = targetResolver != null,
       _settingsStore = settingsStore ?? const NoopSettingsStore(),
       _usbDeviceDiscovery =
           usbDeviceDiscovery ?? const NoopUsbDeviceDiscovery(),
       _deviceBindingStore =
           deviceBindingStore ?? const NoopDeviceBindingStore(),
       _subWorkflows = Map<String, WorkflowDefinition>.of(subWorkflows),
       _delay = delay,
       _snapshot = StudioRuntimeSnapshot.initial(
         workflow: workflow,
         targets: targets,
         subWorkflows: subWorkflows,
         settings: settings,
       );

  // 从项目配置创建真实本机 Runtime Controller。
  factory StudioRuntimeController.fromProjectConfig(
    StudioProjectConfig config, {
    ProcessStarter starter = defaultProcessStarter,
    AppiumTunnelProcessStarter tunnelStarter =
        defaultAppiumTunnelProcessStarter,
    RuntimeDelay delay = defaultRuntimeDelay,
  }) {
    final appiumClient = AppiumClient(config: config.appiumServer);
    final sessionClient = AppiumClient(config: config.appiumServer);
    final actionClient = AppiumClient(config: config.appiumServer);
    final settingsStore = LocalStudioSettingsStore(
      file: _settingsFileForConfig(config),
    );
    final settings = settingsStore.loadSettingsSync();
    final evidenceRoot = _evidenceRootForConfig(config);
    final evidenceStore = LocalRunEvidenceStore(
      rootDirectory: evidenceRoot,
      maxRuns: settings.evidenceMaxRuns,
      maxAgeDays: settings.evidenceMaxAgeDays,
    );
    final workflowStore = LocalWorkflowStore(
      file: _workflowFileForConfig(config),
    );
    final workflow = workflowStore.loadWorkflowSync() ?? config.workflow;
    final subWorkflowStore = LocalSubWorkflowStore(
      file: _subWorkflowFileForConfig(config),
    );
    final subWorkflows = subWorkflowStore.loadSubWorkflowsSync();
    final targetLibraryStore = LocalTargetLibraryStore(
      file: _targetLibraryFileForConfig(config),
    );
    final targetAssetStore = LocalTargetAssetStore(
      projectDirectory: _projectDirectoryForConfig(config),
    );
    final targets = targetLibraryStore.loadTargetsSync();
    return StudioRuntimeController(
      availabilityProbe: AppiumAvailabilityProbe(appiumClient),
      dependencyChecker: const LocalDependencyProbe(),
      processManager: AppiumProcessManager(
        config: config.appiumProcess,
        starter: starter,
      ),
      tunnelManager: AppiumTunnelProcessManager(
        config: AppiumTunnelProcessConfig(
          appiumExecutable: config.appiumProcess.executable,
          workingDirectory: _projectDirectoryForConfig(config).path,
          environment: config.appiumProcess.environment,
          udid: config.deviceSession.udid,
        ),
        starter: tunnelStarter,
        delay: delay,
      ),
      sessionManager: DeviceSessionManager(
        client: sessionClient,
        config: config.deviceSession,
      ),
      deviceActions: AppiumDeviceActionExecutor(actionClient),
      evidenceStore: evidenceStore,
      runHistoryReader: evidenceStore,
      runDetailReader: evidenceStore,
      runReportReader: evidenceStore,
      runReportExporter: evidenceStore,
      runEvidenceAssetReader: evidenceStore,
      workflowStore: workflowStore,
      subWorkflowStore: subWorkflowStore,
      targetLibraryStore: targetLibraryStore,
      targetAssetStore: targetAssetStore,
      settingsStore: settingsStore,
      usbDeviceDiscovery: const DevicectlUsbDeviceDiscovery(),
      deviceBindingStore: LocalDeviceBindingStore(
        file: File(config.sourcePath),
      ),
      subWorkflows: subWorkflows,
      targets: targets,
      delay: delay,
      workflow: workflow,
      settings: settings,
      requiresAppiumTunnel: config.deviceSession.requiresAppiumTunnel,
      defaultTapDurationMs: config.tapDurationMs,
    );
  }

  final AppiumAvailabilityChecker _availabilityProbe;
  final LocalDependencyChecker _dependencyChecker;
  final AppiumProcessManager _processManager;
  final AppiumProcessCleaner _appiumCleaner;
  final AppiumTunnelProcessManager _tunnelManager;
  final AppiumTunnelProcessCleaner _tunnelCleaner;
  final RuntimeSessionManager _sessionManager;
  final DeviceActionExecutor _deviceActions;
  final RunEvidenceStore _evidenceStore;
  final RunHistoryReader _runHistoryReader;
  final RunDetailReader _runDetailReader;
  final RunReportReader _runReportReader;
  final RunReportExporter _runReportExporter;
  final RunEvidenceAssetReader _runEvidenceAssetReader;
  final WorkflowStore _workflowStore;
  final SubWorkflowStore _subWorkflowStore;
  final TargetLibraryStore _targetLibraryStore;
  final TargetAssetStore _targetAssetStore;
  TargetResolver _targetResolver;
  final bool _usesInjectedTargetResolver;
  final SettingsStore _settingsStore;
  final UsbDeviceDiscovery _usbDeviceDiscovery;
  final DeviceBindingStore _deviceBindingStore;
  final Map<String, WorkflowDefinition> _subWorkflows;
  final RuntimeDelay _delay;
  bool requiresAppiumTunnel;
  final int defaultTapDurationMs;
  final Duration appiumReadinessTimeout;
  final Duration appiumReadinessInterval;
  final int appiumReadinessMaxAttempts;
  final StreamController<StudioRuntimeSnapshot> _changes =
      StreamController<StudioRuntimeSnapshot>.broadcast();

  StudioRuntimeSnapshot _snapshot;
  bool _stopRequested = false;
  bool _inspectorBusy = false;

  // 当前 Runtime 快照，供 Flutter UI 读取。
  StudioRuntimeSnapshot get snapshot => _snapshot;

  // Runtime 快照流，供 Flutter Shell 订阅。
  Stream<StudioRuntimeSnapshot> get snapshots => _changes.stream;

  // 释放 Runtime 持有的会话、进程和广播流。
  Future<void> dispose() async {
    await _sessionManager.disconnect();
    await _tunnelManager.stop();
    await _processManager.stop();
    await _changes.close();
  }

  // 写入新的 Runtime 快照并广播。
  void _emit(StudioRuntimeSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_changes.isClosed) {
      _changes.add(snapshot);
    }
  }

  // 追加 Runtime 事件，保留历史事件列表供 Console 使用。
  List<RuntimeEvent> _appendEvent(String level, String message) {
    return <RuntimeEvent>[
      ..._snapshot.events,
      RuntimeEvent(level: level, message: message),
    ];
  }
}

// 解析运行历史 reader，未注入时优先复用 evidence store。
RunHistoryReader _resolveRunHistoryReader(
  RunHistoryReader? reader,
  RunEvidenceStore? store,
) {
  if (reader != null) return reader;
  final candidate = store;
  if (candidate is RunHistoryReader) return candidate as RunHistoryReader;
  return const NoopRunEvidenceStore();
}

// 根据本机设置创建目标解析器。
// 默认不启用 Python，避免缺少环境时影响基础坐标流程。
TargetResolver _targetResolverForSettings(StudioSettings settings) {
  if (settings.enablePythonVision) {
    return CompositeTargetResolver.v4WithPython();
  }
  return CompositeTargetResolver.v4Default();
}

// 解析运行详情 reader，未注入时优先复用 evidence store。
RunDetailReader _resolveRunDetailReader(
  RunDetailReader? reader,
  RunEvidenceStore? store,
) {
  if (reader != null) return reader;
  final candidate = store;
  if (candidate is RunDetailReader) return candidate as RunDetailReader;
  return const NoopRunEvidenceStore();
}

// 解析运行报告 reader，未注入时优先复用 evidence store。
RunReportReader _resolveRunReportReader(
  RunReportReader? reader,
  RunEvidenceStore? store,
) {
  if (reader != null) return reader;
  final candidate = store;
  if (candidate is RunReportReader) return candidate as RunReportReader;
  return const NoopRunEvidenceStore();
}

// 解析运行报告 exporter，未注入时优先复用 evidence store。
RunReportExporter _resolveRunReportExporter(
  RunReportExporter? exporter,
  RunEvidenceStore? store,
) {
  if (exporter != null) return exporter;
  final candidate = store;
  if (candidate is RunReportExporter) return candidate as RunReportExporter;
  return const NoopRunEvidenceStore();
}

// 解析证据资产 reader，未注入时优先复用 evidence store。
RunEvidenceAssetReader _resolveRunEvidenceAssetReader(
  RunEvidenceAssetReader? reader,
  RunEvidenceStore? store,
) {
  if (reader != null) return reader;
  final candidate = store;
  if (candidate is RunEvidenceAssetReader) {
    return candidate as RunEvidenceAssetReader;
  }
  return const NoopRunEvidenceStore();
}
