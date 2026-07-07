part of '../studio_mac_workspace.dart';

/// 一键连接主按钮，供 Device 和 Execute 复用。
/// UI 只提交连接意图，完整链路由 Dart Runtime 串行处理。
class _ConnectPrimaryAction extends StatelessWidget {
  const _ConnectPrimaryAction({
    required this.snapshot,
    required this.controller,
    required this.controlKey,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final Key controlKey;

  /// 渲染大号主按钮和一句短提示。
  /// 文案只表达用户动作，不暴露驱动、隧道或会话细节。
  @override
  Widget build(BuildContext context) {
    final disabled = _connectButtonDisabled(snapshot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: controlKey,
          onPressed: disabled
              ? null
              : () => unawaited(
                  _connectDeviceWithOneButton(
                    context,
                    controller: controller,
                    snapshot: snapshot,
                  ),
                ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          icon: Icon(_connectPrimaryIcon(snapshot), size: 20),
          label: Text(
            _connectPrimaryLabel(snapshot),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _connectPrimaryHint(snapshot),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: StudioColors.muted, height: 1.35),
        ),
      ],
    );
  }
}

/// 返回主连接按钮的短文案。
/// 文案跟随连接状态变化，避免用户重复点击同一链路。
String _connectPrimaryLabel(StudioRuntimeSnapshot snapshot) {
  if (snapshot.connectionStatus == ConnectionStatus.connected) return '已连接';
  if (_deviceBusy(snapshot.connectionStatus) ||
      _appiumBusy(snapshot.appiumStatus)) {
    return '连接中';
  }
  if (snapshot.connectionStatus == ConnectionStatus.waitingForDeveloperTrust) {
    return '等信任';
  }
  return '连接设备';
}

/// 返回主连接按钮的短提示。
/// 详细诊断进入指引、状态抽屉和底部控制台。
String _connectPrimaryHint(StudioRuntimeSnapshot snapshot) {
  if (snapshot.connectionStatus == ConnectionStatus.connected) {
    return '现在可以截图或运行。';
  }
  if (_deviceBusy(snapshot.connectionStatus) ||
      _appiumBusy(snapshot.appiumStatus)) {
    return '请稍等，正在自动处理。';
  }
  if (snapshot.connectionStatus == ConnectionStatus.waitingForDeveloperTrust) {
    return '在手机上点信任后继续。';
  }
  if (snapshot.runStatus != RunStatus.idle) {
    return '运行结束后再连接。';
  }
  return '自动检查、启动、连接。';
}

/// 返回主连接按钮图标。
/// 连接中统一显示同步图标，避免暴露多个底层阶段。
IconData _connectPrimaryIcon(StudioRuntimeSnapshot snapshot) {
  if (snapshot.connectionStatus == ConnectionStatus.connected) {
    return Icons.check_circle_outline;
  }
  if (_deviceBusy(snapshot.connectionStatus) ||
      _appiumBusy(snapshot.appiumStatus)) {
    return Icons.sync;
  }
  return Icons.link;
}
