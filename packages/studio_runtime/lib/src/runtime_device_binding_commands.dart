part of '../studio_runtime.dart';

// 自动绑定结果只在 Runtime 内部使用。
// 它帮助一键连接区分已切换、无需切换、跳过和失败。
enum _RuntimeDeviceBindingOutcome { bound, unchanged, skipped, failed }

// Runtime 设备绑定命令。
// 该分片只处理项目设备绑定，不创建 Appium session、不执行 workflow。
extension StudioRuntimeDeviceBindingCommands on StudioRuntimeController {
  // 重新绑定当前唯一 USB 手机。
  // 成功后仅更新配置和内存态，用户仍通过“连接设备”启动会话链路。
  Future<bool> bindCurrentUsbDevice() async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能重绑。')));
      return false;
    }
    if (_deviceConnectionBusy(_snapshot.connectionStatus) ||
        _snapshot.connectionStatus == ConnectionStatus.connected) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '先断开再重绑。')));
      return false;
    }

    _emit(
      _snapshot.copyWith(
        connectionStatus: ConnectionStatus.initializing,
        appiumMessage: '正在查找 USB 手机。',
        events: _appendEvent('info', '正在查找 USB 手机。'),
      ),
    );

    final outcome = await _bindCurrentUsbDeviceForRuntime(
      this,
      force: true,
      emitFailure: true,
      successMessage: '已绑定当前手机。',
      successEvent: '已绑定当前手机。点连接设备。',
      successConnectionStatus: ConnectionStatus.disconnected,
    );
    return outcome == _RuntimeDeviceBindingOutcome.bound ||
        outcome == _RuntimeDeviceBindingOutcome.unchanged;
  }
}

// _autoBindCurrentUsbDeviceForConnection 让“连接设备”自动对齐当前 USB 手机。
// 只有能唯一确认 USB 手机且与当前配置不一致时才写配置。
Future<_RuntimeDeviceBindingOutcome> _autoBindCurrentUsbDeviceForConnection(
  StudioRuntimeController controller,
) {
  return _bindCurrentUsbDeviceForRuntime(
    controller,
    force: false,
    emitFailure: true,
    successMessage: '已切换到当前手机。',
    successEvent: '已自动绑定当前 USB 手机。',
  );
}

// _ensureCurrentUsbDeviceForSession 保证创建 Appium session 前不会使用旧设备。
// 任何直接重连路径都必须先确认当前唯一 USB 手机，否则不向 Appium 发请求。
Future<bool> _ensureCurrentUsbDeviceForSession(
  StudioRuntimeController controller,
) async {
  final outcome = await _bindCurrentUsbDeviceForRuntime(
    controller,
    force: false,
    emitFailure: true,
    successMessage: '已切换到当前手机。',
    successEvent: '已自动绑定当前 USB 手机。',
  );
  return outcome == _RuntimeDeviceBindingOutcome.bound ||
      outcome == _RuntimeDeviceBindingOutcome.unchanged ||
      outcome == _RuntimeDeviceBindingOutcome.skipped;
}

// _retryBindCurrentUsbDeviceForConnection 仅在绑定设备不可用时重试一次。
// 成功切换后，外层连接流程会从本机检查开始重新跑。
Future<bool> _retryBindCurrentUsbDeviceForConnection(
  StudioRuntimeController controller, {
  required bool alreadyRetried,
}) async {
  if (alreadyRetried) return false;
  final issueType = controller._snapshot.lastConnectionDiagnostic?.type;
  if (issueType != RuntimeConnectionIssueType.deviceNotVisible &&
      issueType != RuntimeConnectionIssueType.driverDeviceNotVisible) {
    return false;
  }
  final outcome = await _bindCurrentUsbDeviceForRuntime(
    controller,
    force: false,
    emitFailure: true,
    successMessage: '已切换到当前手机。',
    successEvent: '已自动绑定当前 USB 手机，继续连接。',
  );
  if (outcome == _RuntimeDeviceBindingOutcome.bound ||
      outcome == _RuntimeDeviceBindingOutcome.unchanged) {
    if (issueType == RuntimeConnectionIssueType.driverDeviceNotVisible) {
      return _restartDriverAfterDeviceVisibilityFailure(controller);
    }
    return true;
  }
  return false;
}

// _bindCurrentUsbDeviceForRuntime 负责发现唯一 USB 手机、写配置并同步内存态。
// 手动“重绑”和一键连接自动绑定都复用这里，避免两套设备绑定规则。
Future<_RuntimeDeviceBindingOutcome> _bindCurrentUsbDeviceForRuntime(
  StudioRuntimeController controller, {
  required bool force,
  required bool emitFailure,
  required String successMessage,
  required String successEvent,
  ConnectionStatus? successConnectionStatus,
}) async {
  if (!force &&
      (controller._usbDeviceDiscovery is NoopUsbDeviceDiscovery ||
          controller._deviceBindingStore is NoopDeviceBindingStore)) {
    if (_currentConfiguredDeviceHasInvalidUdidPlaceholder(controller)) {
      if (emitFailure) {
        _emitDeviceBindingFailure(
          controller,
          const RuntimeDeviceBindingException(
            summary: '未找到 USB 手机。',
            nextStep: '用数据线连接一台手机并解锁，再点连接设备。',
            detail: '设备配置不是当前手机。',
          ),
        );
        return _RuntimeDeviceBindingOutcome.failed;
      }
      return _RuntimeDeviceBindingOutcome.skipped;
    }
    return _RuntimeDeviceBindingOutcome.skipped;
  }
  try {
    final device = await _singleCurrentUsbDeviceForRuntime(controller);
    final currentUdid = _currentConfiguredDeviceUdid(controller);
    if (!force && currentUdid == device.udid.trim()) {
      return _RuntimeDeviceBindingOutcome.unchanged;
    }
    final sessionConfig = await controller._deviceBindingStore
        .saveDeviceBinding(device);
    if (controller._tunnelManager.isRunning) {
      await controller._tunnelManager.stop();
    }
    _applyDeviceSessionConfigToRuntime(controller, sessionConfig);
    controller._emit(
      controller._snapshot.copyWith(
        connectionStatus:
            successConnectionStatus ?? controller._snapshot.connectionStatus,
        appiumMessage: successMessage,
        lastConnectionDiagnostic: null,
        events: controller._appendEvent('info', successEvent),
      ),
    );
    return _RuntimeDeviceBindingOutcome.bound;
  } on RuntimeDeviceBindingException catch (error) {
    if (emitFailure) {
      _emitDeviceBindingFailure(controller, error);
      return _RuntimeDeviceBindingOutcome.failed;
    }
    return _RuntimeDeviceBindingOutcome.skipped;
  } on Object catch (error) {
    if (emitFailure) {
      _emitDeviceBindingFailure(
        controller,
        RuntimeDeviceBindingException(
          summary: '重绑失败。',
          nextStep: '检查 USB 连接后重试。',
          detail: _redactConnectionDetail(error.toString()),
        ),
      );
      return _RuntimeDeviceBindingOutcome.failed;
    }
    return _RuntimeDeviceBindingOutcome.skipped;
  }
}

// _singleCurrentUsbDeviceForRuntime 读取当前唯一 USB 手机。
// 没有或多于一台时都进入可操作错误态，不做猜测。
Future<RuntimeUsbDevice> _singleCurrentUsbDeviceForRuntime(
  StudioRuntimeController controller,
) async {
  final devices = await controller._usbDeviceDiscovery.listUsbDevices();
  if (devices.isEmpty) {
    throw const RuntimeDeviceBindingException(
      summary: '未找到 USB 手机。',
      nextStep: '用数据线连接一台手机并解锁。',
    );
  }
  if (devices.length > 1) {
    throw const RuntimeDeviceBindingException(
      summary: '手机过多。',
      nextStep: '只保留一台 USB 手机后重试。',
    );
  }
  return devices.single;
}

// _currentConfiguredDeviceUdid 返回 Runtime 当前绑定的手机标识。
// 该值只用于内部比较，不进入 UI 或日志。
String? _currentConfiguredDeviceUdid(StudioRuntimeController controller) {
  final sessionManager = controller._sessionManager;
  if (sessionManager is DeviceSessionManager) {
    final udid = sessionManager.config.udid;
    if (udid != null && udid.trim().isNotEmpty) return udid.trim();
  }
  final tunnelUdid = controller._tunnelManager.config.udid;
  if (tunnelUdid != null && tunnelUdid.trim().isNotEmpty) {
    return tunnelUdid.trim();
  }
  return null;
}

// _currentConfiguredDeviceHasInvalidUdidPlaceholder 检查会话配置是否仍是占位符。
// 真实项目会先自动绑定；没有绑定能力时直接阻断，避免假 UDID 进入 Appium。
bool _currentConfiguredDeviceHasInvalidUdidPlaceholder(
  StudioRuntimeController controller,
) {
  final sessionManager = controller._sessionManager;
  if (sessionManager is! DeviceSessionManager) return false;
  return sessionManager.config.hasInvalidUdidPlaceholder;
}

// _applyDeviceSessionConfigToRuntime 把新的设备配置同步到当前 Runtime 依赖。
// 这样用户不需要重启应用即可继续点“连接设备”。
void _applyDeviceSessionConfigToRuntime(
  StudioRuntimeController controller,
  DeviceSessionConfig sessionConfig,
) {
  final sessionManager = controller._sessionManager;
  if (sessionManager is DeviceSessionManager) {
    sessionManager.updateConfig(sessionConfig);
  }
  final tunnelConfig = controller._tunnelManager.config.copyWith(
    udid: sessionConfig.udid,
  );
  controller._tunnelManager.updateConfig(tunnelConfig);
  controller.requiresAppiumTunnel = sessionConfig.requiresAppiumTunnel;
}

// _emitDeviceBindingFailure 把绑定失败纳入统一连接诊断。
// 失败详情保持脱敏，供 Device、Execute 和状态抽屉复用。
void _emitDeviceBindingFailure(
  StudioRuntimeController controller,
  RuntimeDeviceBindingException error,
) {
  final diagnostic = _deviceBindingDiagnostic(error);
  controller._emit(
    controller._snapshot.copyWith(
      connectionStatus: diagnostic.status,
      appiumMessage: diagnostic.summary,
      lastConnectionDiagnostic: diagnostic,
      events: controller._appendEvent('warning', diagnostic.eventMessage),
    ),
  );
}

// _deviceBindingDiagnostic 把重绑错误纳入统一连接诊断。
// UI 复用同一诊断卡，不展示底层路径、端点或完整设备标识。
RuntimeConnectionDiagnostic _deviceBindingDiagnostic(
  RuntimeDeviceBindingException error,
) {
  return RuntimeConnectionDiagnostic(
    type: RuntimeConnectionIssueType.deviceUnavailable,
    status: ConnectionStatus.error,
    summary: error.summary,
    nextStep: error.nextStep,
    detail: error.detail,
  );
}

// 绑定手机已确认但驱动仍报不可见时，重置当前端口驱动后再试一次。
// 受控驱动正常 stop；外部旧驱动只按当前 host/port 精准清理。
Future<bool> _restartDriverAfterDeviceVisibilityFailure(
  StudioRuntimeController controller,
) async {
  if (!controller._processManager.isRunning) {
    return _resetExternalDriverAfterDeviceVisibilityFailure(controller);
  }
  controller._emit(
    controller._snapshot.copyWith(
      events: controller._appendEvent('info', '正在重新准备驱动。'),
    ),
  );
  await controller.stopAppium();
  return true;
}

// 清理外部旧 Appium 后交回一键连接主循环重新启动受控驱动。
// 清理后会复查端口，确保没有误报“已重置”。
Future<bool> _resetExternalDriverAfterDeviceVisibilityFailure(
  StudioRuntimeController controller,
) async {
  final availability = await controller._availabilityProbe.check();
  if (!availability.available) return true;
  controller._emit(
    controller._snapshot.copyWith(
      appiumMessage: '正在重置旧驱动。',
      events: controller._appendEvent('info', '正在重置旧驱动。'),
    ),
  );
  try {
    await controller._appiumCleaner.cleanStaleAppium(
      config: controller._processManager.config,
    );
  } on Object catch (error) {
    final detail = _redactConnectionDetail(error.toString());
    final diagnostic = RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.driverDeviceNotVisible,
      status: ConnectionStatus.error,
      summary: '驱动未识别手机。',
      nextStep: '关闭外部驱动，再点连接设备。',
      detail: detail,
    );
    controller._emit(
      controller._snapshot.copyWith(
        connectionStatus: diagnostic.status,
        appiumMessage: diagnostic.summary,
        lastConnectionDiagnostic: diagnostic,
        events: controller._appendEvent('warning', diagnostic.eventMessage),
      ),
    );
    return false;
  }
  final afterClean = await controller._availabilityProbe.check();
  if (afterClean.available) {
    final diagnostic = const RuntimeConnectionDiagnostic(
      type: RuntimeConnectionIssueType.driverDeviceNotVisible,
      status: ConnectionStatus.error,
      summary: '驱动未识别手机。',
      nextStep: '关闭外部驱动，再点连接设备。',
      detail: '旧驱动仍在运行。',
    );
    controller._emit(
      controller._snapshot.copyWith(
        connectionStatus: diagnostic.status,
        appiumMessage: diagnostic.summary,
        lastConnectionDiagnostic: diagnostic,
        events: controller._appendEvent('warning', diagnostic.eventMessage),
      ),
    );
    return false;
  }
  controller._emit(
    controller._snapshot.copyWith(
      appiumStatus: AppiumProcessStatus.stopped,
      appiumOwnership: AppiumProcessOwnership.unknown,
      appiumMessage: '旧驱动已重置。',
      events: controller._appendEvent('info', '旧驱动已重置。'),
    ),
  );
  return true;
}
