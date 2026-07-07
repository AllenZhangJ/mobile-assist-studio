part of '../studio_runtime.dart';

// Runtime 的本机环境、驱动和设备会话命令。
// 这些命令只维护连接生命周期，不执行 workflow 节点。
extension StudioRuntimeAppiumCommands on StudioRuntimeController {
  // 一键连接设备：本机检查、隧道、驱动和手机会话都在 Runtime 内串行完成。
  Future<void> connectDeviceEndToEnd({String? adminPassword}) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能连接设备。')));
      return;
    }
    if (_snapshot.connectionStatus == ConnectionStatus.connected) {
      _emit(_snapshot.copyWith(events: _appendEvent('info', '设备已连接。')));
      return;
    }
    if (_deviceConnectionBusy(_snapshot.connectionStatus) ||
        _snapshot.appiumStatus == AppiumProcessStatus.starting ||
        _snapshot.appiumStatus == AppiumProcessStatus.stopping) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '连接处理中，请稍等。')));
      return;
    }

    _emit(
      _snapshot.copyWith(
        connectionStatus: ConnectionStatus.connecting,
        appiumMessage: '正在连接设备。',
        lastConnectionDiagnostic: null,
        events: _appendEvent('info', '正在连接设备。'),
      ),
    );

    var retriedAfterBinding = false;
    var retriedAfterWdaRecovery = false;
    while (true) {
      final bindingOutcome = await _autoBindCurrentUsbDeviceForConnection(this);
      if (bindingOutcome == _RuntimeDeviceBindingOutcome.failed) {
        return;
      }
      await refreshDependencyReport();
      var tunnelRegistryVerified = false;
      if (requiresAppiumTunnel && _appiumTunnelRegistryPending(_snapshot)) {
        final registryReady = await _waitForAppiumTunnelRegistry();
        if (!registryReady) {
          if (_tunnelManager.isRunning) return;
          final recovered = await _restartExternalEmptyAppiumTunnel(
            adminPassword,
          );
          if (!recovered) return;
        }
        tunnelRegistryVerified = true;
        await refreshDependencyReport();
      }
      if (requiresAppiumTunnel &&
          !tunnelRegistryVerified &&
          _appiumTunnelReportedReady(_snapshot)) {
        final registryReady = await _waitForAppiumTunnelRegistry();
        if (!registryReady) {
          final rebound = await _retryBindCurrentUsbDeviceForConnection(
            this,
            alreadyRetried: retriedAfterBinding,
          );
          if (rebound) {
            retriedAfterBinding = true;
            continue;
          }
          return;
        }
        await refreshDependencyReport();
      }
      if (requiresAppiumTunnel &&
          _appiumTunnelNeedsAction(
            _snapshot,
            tunnelRunning: _tunnelManager.isRunning,
          )) {
        final password = adminPassword;
        if (password == null || password.isEmpty) {
          _emit(
            _snapshot.copyWith(
              connectionStatus: ConnectionStatus.error,
              appiumMessage: '需要本机密码。',
              lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
                type: RuntimeConnectionIssueType.tunnelUnavailable,
                status: ConnectionStatus.error,
                summary: '需要本机密码。',
                nextStep: '输入 Mac 密码后继续连接。',
                detail: '',
              ),
              events: _appendEvent('warning', '需要本机密码。请点连接设备后输入密码。'),
            ),
          );
          return;
        }
        final tunnelStarted = await startAppiumTunnel(adminPassword: password);
        if (!tunnelStarted) {
          final rebound = await _retryBindCurrentUsbDeviceForConnection(
            this,
            alreadyRetried: retriedAfterBinding,
          );
          if (rebound) {
            retriedAfterBinding = true;
            continue;
          }
          return;
        }
        await refreshDependencyReport();
      }

      await prepareAppium();
      if (_snapshot.appiumStatus != AppiumProcessStatus.running) {
        _emit(
          _snapshot.copyWith(
            connectionStatus: ConnectionStatus.error,
            events: _appendEvent('warning', '连接未完成。请按提示处理后重试。'),
          ),
        );
        return;
      }
      await connectDevice();
      if (_snapshot.connectionStatus == ConnectionStatus.connected) return;
      final rebound = await _retryBindCurrentUsbDeviceForConnection(
        this,
        alreadyRetried: retriedAfterBinding,
      );
      if (rebound) {
        retriedAfterBinding = true;
        continue;
      }
      final recovered = await _retryManagedDriverAfterTransientWdaFailure(
        this,
        alreadyRetried: retriedAfterWdaRecovery,
      );
      if (recovered) {
        retriedAfterWdaRecovery = true;
        continue;
      }
      return;
    }
  }

  // 启动 Appium XCUITest 本机隧道。
  // 密码只传入进程 stdin，不进入快照、事件或本地证据。
  Future<bool> startAppiumTunnel({required String adminPassword}) async {
    if (_tunnelManager.isRunning) {
      return _waitForAppiumTunnelRegistry();
    }
    _emit(
      _snapshot.copyWith(
        appiumMessage: '正在启动本机隧道。',
        events: _appendEvent('info', '正在启动本机隧道。'),
      ),
    );
    try {
      await _tunnelManager.start(
        adminPassword: adminPassword,
        onWaitingForRegistry: () {
          _emit(
            _snapshot.copyWith(
              appiumMessage: '等待手机允许。',
              events: _appendEvent('info', '等待手机允许。请在手机提示时点允许。'),
            ),
          );
        },
      );
      _emit(
        _snapshot.copyWith(
          appiumMessage: '本机隧道已就绪。',
          events: _appendEvent('info', '本机隧道已就绪。'),
        ),
      );
      return true;
    } on Object catch (error) {
      final message = _appiumTunnelStartFailureMessage(error);
      final detail = _redactConnectionDetail(error.toString());
      final diagnostic = _appiumTunnelConnectionDiagnostic(
        message: message,
        detail: detail,
      );
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.error,
          appiumMessage: diagnostic.summary,
          lastConnectionDiagnostic: diagnostic,
          events: _appendEvent('error', diagnostic.eventMessage),
        ),
      );
      return false;
    }
  }

  // 等待已有 Appium XCUITest tunnel registry 出现目标手机。
  // 该路径不启动新进程，避免旧隧道未完成时重复占用 registry 端口。
  Future<bool> _waitForAppiumTunnelRegistry() async {
    _emit(
      _snapshot.copyWith(
        appiumMessage: '等待手机允许。',
        events: _appendEvent('info', '等待手机允许。请在手机提示时点允许。'),
      ),
    );
    try {
      await _tunnelManager.waitUntilRegistryReady();
      _emit(
        _snapshot.copyWith(
          appiumMessage: '本机隧道已就绪。',
          events: _appendEvent('info', '本机隧道已就绪。'),
        ),
      );
      return true;
    } on Object catch (error) {
      final message = _appiumTunnelStartFailureMessage(error);
      final detail = _redactConnectionDetail(error.toString());
      final diagnostic = _appiumTunnelConnectionDiagnostic(
        message: message,
        detail: detail,
      );
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.error,
          appiumMessage: diagnostic.summary,
          lastConnectionDiagnostic: diagnostic,
          events: _appendEvent('error', diagnostic.eventMessage),
        ),
      );
      return false;
    }
  }

  // 清理当前 Runtime 未持有的空 registry 隧道，再启动受控隧道。
  // 这覆盖热重启或旧进程残留后“进程在、设备不在”的卡死状态。
  Future<bool> _restartExternalEmptyAppiumTunnel(String? adminPassword) async {
    if (adminPassword == null || adminPassword.isEmpty) {
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.error,
          appiumMessage: '需要本机密码。',
          lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
            type: RuntimeConnectionIssueType.tunnelUnavailable,
            status: ConnectionStatus.error,
            summary: '需要本机密码。',
            nextStep: '输入 Mac 密码后继续连接。',
            detail: '',
          ),
          events: _appendEvent('warning', '需要本机密码。请点连接设备后输入密码。'),
        ),
      );
      return false;
    }
    _emit(
      _snapshot.copyWith(
        appiumMessage: '正在清理旧隧道。',
        events: _appendEvent('info', '正在清理旧隧道。'),
      ),
    );
    try {
      await _tunnelCleaner.cleanStaleTunnels(
        config: _tunnelManager.config,
        adminPassword: adminPassword,
      );
    } on Object catch (error) {
      final message = _appiumTunnelStartFailureMessage(error);
      final detail = _redactConnectionDetail(error.toString());
      final diagnostic = _appiumTunnelConnectionDiagnostic(
        message: message,
        detail: detail,
      );
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.error,
          appiumMessage: diagnostic.summary,
          lastConnectionDiagnostic: diagnostic,
          events: _appendEvent('error', diagnostic.eventMessage),
        ),
      );
      return false;
    }
    return startAppiumTunnel(adminPassword: adminPassword);
  }

  // 刷新本机环境检查结果。
  Future<void> refreshDependencyReport() async {
    _emit(_snapshot.copyWith(events: _appendEvent('info', '正在检查本机环境。')));
    try {
      final report = await _dependencyChecker.check(
        appiumProcess: _processManager.config,
      );
      _emit(
        _snapshot.copyWith(
          dependencyReport: report,
          events: _appendEvent(
            report.hasError
                ? 'warning'
                : report.hasWarning
                ? 'warning'
                : 'info',
            _dependencyReportEventMessage(report),
          ),
        ),
      );
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(
          dependencyReport: LocalDependencyReport(
            checks: const <LocalDependencyCheck>[
              LocalDependencyCheck(
                id: 'local-stack',
                label: '本机环境',
                status: LocalDependencyStatus.error,
                summary: '本机检查未完成。',
                nextStep: '请重试检查，再看控制台。',
              ),
            ],
            checkedAt: DateTime.now(),
            message: '本机检查失败。',
          ),
          events: _appendEvent('warning', '本机检查失败：$error'),
        ),
      );
    }
  }

  // 准备 Appium：先检查已有服务，未发现时再启动并等待就绪。
  // 这是面向 UI 的主入口，避免用户手动区分检查和启动。
  Future<void> prepareAppium() async {
    if (_snapshot.appiumStatus == AppiumProcessStatus.starting ||
        _snapshot.appiumStatus == AppiumProcessStatus.stopping) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '驱动处理中，请稍等。')));
      return;
    }

    _emit(
      _snapshot.copyWith(
        appiumStatus: AppiumProcessStatus.starting,
        appiumOwnership: AppiumProcessOwnership.unknown,
        appiumMessage: '正在准备驱动。',
        events: _appendEvent('info', '正在准备驱动。'),
      ),
    );
    final result = await _availabilityProbe.check();
    if (result.available) {
      final ownership = _currentAppiumOwnership(this);
      _emit(
        _snapshot.copyWith(
          appiumStatus: AppiumProcessStatus.running,
          appiumOwnership: ownership,
          appiumMessage: _appiumReadyMessage(ownership),
          events: _appendEvent('info', _appiumReadyEvent(ownership)),
        ),
      );
      return;
    }

    if (!_appiumAvailabilityCanStart(result.message)) {
      final message = _appiumAvailabilityMessage(result.message);
      _emit(
        _snapshot.copyWith(
          appiumStatus: AppiumProcessStatus.error,
          appiumOwnership: AppiumProcessOwnership.unknown,
          appiumMessage: message,
          events: _appendEvent('warning', '驱动准备失败：$message'),
        ),
      );
      return;
    }

    _emit(
      _snapshot.copyWith(
        appiumStatus: AppiumProcessStatus.starting,
        appiumOwnership: AppiumProcessOwnership.unknown,
        appiumMessage: '未发现本机驱动，正在启动。',
        events: _appendEvent('info', '未发现本机驱动，正在启动。'),
      ),
    );
    await _startAppiumProcess();
  }

  // 检查 Appium 服务是否可用。
  Future<void> checkAppium() async {
    _emit(
      _snapshot.copyWith(
        appiumStatus: AppiumProcessStatus.starting,
        appiumOwnership: AppiumProcessOwnership.unknown,
        appiumMessage: '正在检查驱动。',
        events: _appendEvent('info', '正在检查驱动。'),
      ),
    );
    final result = await _availabilityProbe.check();
    final diagnostic = _appiumAvailabilityDiagnostic(result);
    final ownership = _appiumOwnershipForStatus(this, diagnostic.status);
    final ready = diagnostic.status == AppiumProcessStatus.running;
    _emit(
      _snapshot.copyWith(
        appiumStatus: diagnostic.status,
        appiumOwnership: ownership,
        appiumMessage: ready
            ? _appiumReadyMessage(ownership)
            : diagnostic.message,
        events: _appendEvent(
          ready ? 'info' : diagnostic.level,
          ready ? _appiumReadyEvent(ownership) : diagnostic.eventMessage,
        ),
      ),
    );
  }

  // 启动 Appium 并等待 /status ready。
  Future<void> startAppium() async {
    _emit(
      _snapshot.copyWith(
        appiumStatus: AppiumProcessStatus.starting,
        appiumOwnership: AppiumProcessOwnership.unknown,
        appiumMessage: '正在启动驱动。',
        events: _appendEvent('info', '正在启动驱动。'),
      ),
    );
    await _startAppiumProcess();
  }

  // 启动 Appium 进程并等待服务 ready。
  // prepareAppium 和 startAppium 共用该收口，保持启动失败分类一致。
  Future<void> _startAppiumProcess() async {
    try {
      final pid = await _processManager.start();
      _emit(
        _snapshot.copyWith(
          appiumStatus: AppiumProcessStatus.starting,
          appiumOwnership: AppiumProcessOwnership.managed,
          appiumMessage: '驱动已启动，等待就绪。',
          events: _appendEvent('info', '驱动已启动，等待就绪。'),
        ),
      );
      final readiness = await _waitForAppiumReadiness();
      if (!readiness.available) {
        final message = _appiumAvailabilityMessage(
          readiness.message,
          afterStart: true,
        );
        _emit(
          _snapshot.copyWith(
            appiumStatus: AppiumProcessStatus.error,
            appiumOwnership: AppiumProcessOwnership.unknown,
            appiumMessage: message,
            events: _appendEvent('error', '驱动未就绪：$message'),
          ),
        );
        return;
      }
      _emit(
        _snapshot.copyWith(
          appiumStatus: AppiumProcessStatus.running,
          appiumOwnership: AppiumProcessOwnership.managed,
          appiumMessage: '驱动已就绪。进程 $pid。',
          events: _appendEvent('info', '驱动已就绪。'),
        ),
      );
    } on Object catch (error) {
      final message = _appiumStartFailureMessage(error);
      final detail = _redactConnectionDetail(error.toString());
      _emit(
        _snapshot.copyWith(
          appiumStatus: AppiumProcessStatus.error,
          appiumOwnership: AppiumProcessOwnership.unknown,
          appiumMessage: message,
          events: _appendEvent('error', '$message 详情：$detail'),
        ),
      );
    }
  }

  // 等待 Appium ready，带超时和最大尝试次数。
  Future<AppiumAvailability> _waitForAppiumReadiness() async {
    final deadline = DateTime.now().add(appiumReadinessTimeout);
    AppiumAvailability last = const AppiumAvailability(
      available: false,
      message: '尚未检查驱动就绪状态。',
    );

    for (var attempt = 1; attempt <= appiumReadinessMaxAttempts; attempt += 1) {
      last = await _availabilityProbe.check();
      if (last.available) {
        return last;
      }
      if (DateTime.now().isAfter(deadline)) {
        break;
      }
      if (appiumReadinessInterval > Duration.zero) {
        await _delay(appiumReadinessInterval);
      }
    }

    return AppiumAvailability(
      available: false,
      message: '驱动等待超时。最后状态：${last.message}',
    );
  }

  // 停止 Appium；若设备还连接则先断开会话。
  Future<void> stopAppium() async {
    if (_snapshot.appiumStatus == AppiumProcessStatus.stopping) {
      return;
    }
    if (_snapshot.appiumStatus == AppiumProcessStatus.stopped &&
        !_processManager.isRunning) {
      return;
    }
    if (!_processManager.isRunning) {
      await _handleExternalAppiumStopRequest();
      return;
    }
    if (_snapshot.connectionStatus == ConnectionStatus.connected) {
      await disconnectDevice();
    }
    _emit(
      _snapshot.copyWith(
        appiumStatus: AppiumProcessStatus.stopping,
        appiumOwnership: AppiumProcessOwnership.managed,
        appiumMessage: '正在停止驱动。',
        events: _appendEvent('info', '正在停止驱动。'),
      ),
    );
    await _processManager.stop();
    await _emitAppiumStoppedOrExternalStillRunning();
  }

  // 处理外部 Appium 的停止请求。
  // Runtime 不能假装停止未接管的进程，只能刷新事实状态并给出短提示。
  Future<void> _handleExternalAppiumStopRequest() async {
    final availability = await _availabilityProbe.check();
    if (availability.available) {
      _emit(
        _snapshot.copyWith(
          appiumStatus: AppiumProcessStatus.running,
          appiumOwnership: AppiumProcessOwnership.external,
          appiumMessage: _appiumReadyMessage(AppiumProcessOwnership.external),
          events: _appendEvent('warning', '外部驱动未停止。可直接连接设备。'),
        ),
      );
      return;
    }
    _emit(
      _snapshot.copyWith(
        appiumStatus: AppiumProcessStatus.stopped,
        appiumOwnership: AppiumProcessOwnership.unknown,
        appiumMessage: '驱动已停止。',
        events: _appendEvent('info', '驱动已停止。'),
      ),
    );
  }

  // 停止受控驱动后复核端口状态。
  // 若端口仍可用，说明存在外部驱动，状态必须保持 running。
  Future<void> _emitAppiumStoppedOrExternalStillRunning() async {
    final availability = await _availabilityProbe.check();
    if (availability.available) {
      _emit(
        _snapshot.copyWith(
          appiumStatus: AppiumProcessStatus.running,
          appiumOwnership: AppiumProcessOwnership.external,
          appiumMessage: _appiumReadyMessage(AppiumProcessOwnership.external),
          events: _appendEvent('warning', '外部驱动仍在运行。可直接连接设备。'),
        ),
      );
      return;
    }
    _emit(
      _snapshot.copyWith(
        appiumStatus: AppiumProcessStatus.stopped,
        appiumOwnership: AppiumProcessOwnership.unknown,
        appiumMessage: '驱动已停止。',
        events: _appendEvent('info', '驱动已停止。'),
      ),
    );
  }

  // 创建手机 WebDriver 会话。
  Future<void> connectDevice() async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能连接设备。')));
      return;
    }
    final usbReady = await _ensureCurrentUsbDeviceForSession(this);
    if (!usbReady) {
      return;
    }
    if (requiresAppiumTunnel &&
        _appiumTunnelNeedsAction(
          _snapshot,
          tunnelRunning: _tunnelManager.isRunning,
        )) {
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.error,
          appiumMessage: '本机隧道未就绪。',
          lastConnectionDiagnostic: const RuntimeConnectionDiagnostic(
            type: RuntimeConnectionIssueType.tunnelUnavailable,
            status: ConnectionStatus.error,
            summary: '本机隧道未就绪。',
            nextStep: '点连接设备并输入密码。',
            detail: '',
          ),
          events: _appendEvent('warning', '本机隧道未就绪。请点连接设备并输入密码。'),
        ),
      );
      return;
    }
    _emit(
      _snapshot.copyWith(
        connectionStatus: ConnectionStatus.connecting,
        appiumMessage: '正在创建手机会话。',
        lastConnectionDiagnostic: null,
        events: _appendEvent('info', '正在创建手机会话。'),
      ),
    );
    try {
      final session = await _sessionManager.connect();
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.connected,
          sessionId: session.id,
          appiumMessage: '手机会话已连接。',
          lastConnectionDiagnostic: null,
          events: _appendEvent('info', '手机会话已连接。'),
        ),
      );
    } on AppiumClientException catch (error) {
      final diagnostic = classifyRuntimeConnectionError(error);
      _emit(
        _snapshot.copyWith(
          connectionStatus: diagnostic.status,
          appiumMessage: diagnostic.summary,
          lastConnectionDiagnostic: diagnostic,
          events: _appendEvent('error', diagnostic.eventMessage),
        ),
      );
    } on Object catch (error) {
      final diagnostic = classifyRuntimeConnectionError(error);
      _emit(
        _snapshot.copyWith(
          connectionStatus: diagnostic.status,
          appiumMessage: diagnostic.summary,
          lastConnectionDiagnostic: diagnostic,
          events: _appendEvent('error', diagnostic.eventMessage),
        ),
      );
    }
  }

  // 断开当前手机 WebDriver 会话并清空截图。
  Future<void> disconnectDevice() async {
    _emit(
      _snapshot.copyWith(
        connectionStatus: ConnectionStatus.disconnecting,
        appiumMessage: '正在断开手机会话。',
        events: _appendEvent('info', '正在断开手机会话。'),
      ),
    );
    await _sessionManager.disconnect();
    _emit(
      _snapshot.copyWith(
        connectionStatus: ConnectionStatus.disconnected,
        sessionId: null,
        latestScreenshotBase64: null,
        latestScreenshotAt: null,
        inspectorSnapshot: null,
        appiumMessage: '手机会话已断开。',
        lastConnectionDiagnostic: null,
        events: _appendEvent('info', '手机会话已断开。'),
      ),
    );
  }
}

// 当当前设备需要 RemoteXPC 且本机检查已发现隧道缺失时，连接前直接拦截。
bool _appiumTunnelNeedsAction(
  StudioRuntimeSnapshot snapshot, {
  required bool tunnelRunning,
}) {
  if (tunnelRunning) return false;
  final tunnel = snapshot.dependencyReport.checkById('ios-tunnel');
  if (tunnel == null) return false;
  return tunnel.status == LocalDependencyStatus.warning ||
      tunnel.status == LocalDependencyStatus.error;
}

// 判断已有 tunnel-creation 进程是否存在但 registry 尚未发布设备。
// 这种情况需要等待手机允许，不能再启动第二个隧道进程。
bool _appiumTunnelRegistryPending(StudioRuntimeSnapshot snapshot) {
  final tunnel = snapshot.dependencyReport.checkById('ios-tunnel');
  return tunnel?.id == 'ios-tunnel' &&
      tunnel?.status == LocalDependencyStatus.warning &&
      tunnel?.detail == 'registry-empty';
}

// 判断本机检查是否只证明了“有隧道”，还需要 Runtime 再确认命中绑定手机。
bool _appiumTunnelReportedReady(StudioRuntimeSnapshot snapshot) {
  final tunnel = snapshot.dependencyReport.checkById('ios-tunnel');
  return tunnel?.id == 'ios-tunnel' &&
      tunnel?.status == LocalDependencyStatus.ready;
}

// 判断连接生命周期是否已经在处理中。
bool _deviceConnectionBusy(ConnectionStatus status) {
  return status == ConnectionStatus.initializing ||
      status == ConnectionStatus.connecting ||
      status == ConnectionStatus.disconnecting;
}

// 对 WDA 代理瞬时断开做一次受控恢复。
// 只重启本应用启动的驱动，避免误动用户手动启动的 Appium。
Future<bool> _retryManagedDriverAfterTransientWdaFailure(
  StudioRuntimeController controller, {
  required bool alreadyRetried,
}) async {
  if (alreadyRetried || !controller._processManager.isRunning) {
    return false;
  }
  final diagnostic = controller._snapshot.lastConnectionDiagnostic;
  if (diagnostic?.type != RuntimeConnectionIssueType.wdaStartFailed) {
    return false;
  }
  if (!_transientWdaFailureLooksRecoverable(diagnostic!.detail)) {
    return false;
  }
  controller._emit(
    controller._snapshot.copyWith(
      events: controller._appendEvent('info', '正在恢复手机会话。'),
    ),
  );
  await controller.stopAppium();
  return true;
}

// 判断 WDA 失败是否像瞬时代理断开。
// 签名、证书或 Xcode 构建错误不应自动重试。
bool _transientWdaFailureLooksRecoverable(String detail) {
  final lower = detail.toLowerCase();
  return _hasAny(lower, const [
    'socket hang up',
    'could not proxy command',
    'port 8100',
  ]);
}

// 根据当前 Runtime 是否持有进程句柄判断驱动来源。
// 外部驱动可复用，但不能被“停止驱动”误报为已停止。
AppiumProcessOwnership _currentAppiumOwnership(
  StudioRuntimeController controller,
) {
  return controller._processManager.isRunning
      ? AppiumProcessOwnership.managed
      : AppiumProcessOwnership.external;
}

// 按驱动状态派生来源；非运行态不保留来源。
AppiumProcessOwnership _appiumOwnershipForStatus(
  StudioRuntimeController controller,
  AppiumProcessStatus status,
) {
  if (status != AppiumProcessStatus.running) {
    return AppiumProcessOwnership.unknown;
  }
  return _currentAppiumOwnership(controller);
}

// 生成驱动就绪短文案。
// 外部驱动只说明来源，不暴露端口、PID 或命令细节。
String _appiumReadyMessage(AppiumProcessOwnership ownership) {
  return switch (ownership) {
    AppiumProcessOwnership.external => '驱动已就绪。外部启动。',
    AppiumProcessOwnership.managed ||
    AppiumProcessOwnership.unknown => '驱动已就绪。',
  };
}

// 生成驱动就绪事件文案，保持控制台短而可读。
String _appiumReadyEvent(AppiumProcessOwnership ownership) {
  return switch (ownership) {
    AppiumProcessOwnership.external => '驱动已就绪。外部启动。',
    AppiumProcessOwnership.managed ||
    AppiumProcessOwnership.unknown => '驱动已就绪。',
  };
}

// 生成本机检查事件文案。
// 有问题时带出第一项可处理检查，避免控制台只重复总状态。
String _dependencyReportEventMessage(LocalDependencyReport report) {
  final issue = _firstActionableDependencyIssue(report);
  if (issue == null) return report.message;
  return '${report.message}${issue.label}：${issue.summary}${issue.nextStep}';
}

// 选出最值得用户先处理的依赖项。
// 会话准备是汇总项，优先展示更具体的上游工具或隧道问题。
LocalDependencyCheck? _firstActionableDependencyIssue(
  LocalDependencyReport report,
) {
  for (final status in const [
    LocalDependencyStatus.error,
    LocalDependencyStatus.warning,
  ]) {
    for (final check in report.checks) {
      if (check.id == 'wda-prerequisites') continue;
      if (check.status == status) return check;
    }
    for (final check in report.checks) {
      if (check.status == status) return check;
    }
  }
  return null;
}

// 判断一次 /status 失败后是否适合自动启动本机驱动。
// 端口被占用或响应异常时不自动启动，避免制造第二个问题。
bool _appiumAvailabilityCanStart(String message) {
  return _appiumAvailabilityLooksOffline(message);
}

// 将 Appium 启动失败转成短中文动作。
// 缺少可执行文件时优先提示查环境，而不是继续重试启动。
String _appiumStartFailureMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (error is ProcessException &&
      _hasAny(text, const [
        'no such file or directory',
        'cannot run program',
        'not found',
      ])) {
    return '未找到驱动工具。请点查环境。';
  }
  if (error is ProcessException &&
      _hasAny(text, const ['permission denied', 'operation not permitted'])) {
    return '驱动工具无法启动。请点查环境。';
  }
  return '驱动启动失败。请点查环境。';
}

// 将隧道启动失败转换为用户可处理的短中文。
String _appiumTunnelStartFailureMessage(Object error) {
  final text = error.toString().toLowerCase();
  if (error is AppiumTunnelException) {
    return error.message;
  }
  if (error is ProcessException &&
      _hasAny(text, const [
        'no such file or directory',
        'cannot run program',
        'not found',
      ])) {
    return '未找到隧道工具。请点查环境。';
  }
  if (error is ProcessException &&
      _hasAny(text, const ['permission denied', 'operation not permitted'])) {
    return '隧道无权限启动。请重试密码。';
  }
  return '本机隧道启动失败。请重试密码。';
}

// 将本机隧道失败纳入连接诊断，供 Device、Execute 和状态抽屉统一展示。
RuntimeConnectionDiagnostic _appiumTunnelConnectionDiagnostic({
  required String message,
  required String detail,
}) {
  final bindingUnavailable = message.contains('绑定手机');
  final nextStep = bindingUnavailable
      ? '用数据线连接一台手机并解锁，再点连接设备。'
      : message.contains('密码') || message.contains('权限')
      ? '重新输入 Mac 密码后连接。'
      : '解锁手机，点允许后重试。';
  return RuntimeConnectionDiagnostic(
    type: bindingUnavailable
        ? RuntimeConnectionIssueType.deviceNotVisible
        : RuntimeConnectionIssueType.tunnelUnavailable,
    status: ConnectionStatus.error,
    summary: bindingUnavailable ? '未找到 USB 手机。' : message,
    nextStep: nextStep,
    detail: detail,
  );
}

// 将 Appium /status 探测结果转换为用户可执行的短诊断。
// 检查命令只判断服务是否可达，不在失败时自动启动进程。
({
  AppiumProcessStatus status,
  String message,
  String level,
  String eventMessage,
})
_appiumAvailabilityDiagnostic(AppiumAvailability result) {
  if (result.available) {
    return (
      status: AppiumProcessStatus.running,
      message: '驱动已就绪。',
      level: 'info',
      eventMessage: '驱动已就绪。',
    );
  }

  final status = _appiumAvailabilityLooksOffline(result.message)
      ? AppiumProcessStatus.stopped
      : AppiumProcessStatus.error;
  final message = _appiumAvailabilityMessage(result.message);
  return (
    status: status,
    message: message,
    level: 'warning',
    eventMessage: '驱动检查失败：$message',
  );
}

// 把 Appium 底层连接失败翻译成短中文下一步。
// afterStart 用于区分“没启动”和“启动后仍未响应”两类场景。
String _appiumAvailabilityMessage(String message, {bool afterStart = false}) {
  final trimmed = message.trim();
  if (_appiumAvailabilityLooksOffline(trimmed)) {
    return afterStart
        ? '驱动已启动但未响应。请停止后重启；若仍失败，点查环境。'
        : '未发现本机驱动。请点连接设备；若仍失败，点查环境。';
  }
  if (_appiumAvailabilityLooksTimedOut(trimmed)) {
    return '驱动没有响应。请停止后重启；若仍失败，点查环境。';
  }
  if (_appiumAvailabilityLooksInvalid(trimmed)) {
    return '驱动响应异常。请停止后重启；若仍失败，点查环境。';
  }
  if (trimmed.isEmpty) {
    return '驱动未就绪。请点连接设备；若仍失败，点查环境。';
  }
  return '驱动未就绪。请点连接设备或稍后重查。详情：${_redactConnectionDetail(trimmed)}';
}

// 判断探测失败是否表示本机驱动服务未监听。
// 这类情况下一步应优先提示用户启动驱动。
bool _appiumAvailabilityLooksOffline(String message) {
  final lower = message.toLowerCase();
  return _hasAny(lower, const [
    'unable to reach appium',
    'connection failed',
    'connection refused',
    'failed host lookup',
    'network is unreachable',
  ]);
}

// 判断探测失败是否更像服务无响应。
// 这类情况保守提示重启和环境检查。
bool _appiumAvailabilityLooksTimedOut(String message) {
  final lower = message.toLowerCase();
  return _hasAny(lower, const [
    'timed out while requesting',
    'operation timed out',
    'request timeout',
  ]);
}

// 判断探测失败是否是响应格式或协议异常。
// 这类情况说明端口可能被非 Appium 服务占用。
bool _appiumAvailabilityLooksInvalid(String message) {
  final lower = message.toLowerCase();
  return _hasAny(lower, const [
    'appium response was not an object',
    'invalid appium json',
    'returned http',
  ]);
}
