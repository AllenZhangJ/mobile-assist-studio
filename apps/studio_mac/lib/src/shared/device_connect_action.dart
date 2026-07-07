part of '../studio_mac_workspace.dart';

/// 执行一键连接设备。
/// UI 只负责必要的密码弹窗，完整链路由 Runtime 串行收口。
Future<void> _connectDeviceWithOneButton(
  BuildContext context, {
  required StudioRuntimeController controller,
  required StudioRuntimeSnapshot snapshot,
}) async {
  final needsPassword = _connectNeedsPassword(controller, snapshot);
  final password = needsPassword ? await _requestMacPassword(context) : null;
  if (!context.mounted || (needsPassword && password == null)) {
    return;
  }
  await controller.connectDeviceEndToEnd(adminPassword: password);
  if (!context.mounted ||
      password != null ||
      !_connectRuntimeRequestsPassword(controller.snapshot)) {
    return;
  }
  final retryPassword = await _requestMacPassword(context);
  if (!context.mounted || retryPassword == null) {
    return;
  }
  await controller.connectDeviceEndToEnd(adminPassword: retryPassword);
}

/// 判断本次连接是否需要先收集 Mac 密码。
/// 已确认本机隧道就绪时不打扰用户。
bool _connectNeedsPassword(
  StudioRuntimeController controller,
  StudioRuntimeSnapshot snapshot,
) {
  if (!controller.requiresAppiumTunnel) return false;
  final tunnel = snapshot.dependencyReport.checkById('ios-tunnel');
  if (tunnel?.detail == 'registry-empty') return false;
  return tunnel == null || tunnel.status != LocalDependencyStatus.ready;
}

/// 判断连接按钮是否应该禁用。
/// 停止、运行和已有连接都不允许再启动新连接。
bool _connectButtonDisabled(StudioRuntimeSnapshot snapshot) {
  return _deviceBusy(snapshot.connectionStatus) ||
      _appiumBusy(snapshot.appiumStatus) ||
      snapshot.connectionStatus == ConnectionStatus.connected ||
      snapshot.runStatus != RunStatus.idle;
}

/// 判断 Runtime 是否在刷新本机状态后请求密码。
/// 该分支用于同一次点击内补问密码，避免用户看见错误后再手动点一次。
bool _connectRuntimeRequestsPassword(StudioRuntimeSnapshot snapshot) {
  final diagnostic = snapshot.lastConnectionDiagnostic;
  return snapshot.connectionStatus == ConnectionStatus.error &&
      diagnostic?.type == RuntimeConnectionIssueType.tunnelUnavailable &&
      diagnostic?.summary == '需要本机密码。';
}
