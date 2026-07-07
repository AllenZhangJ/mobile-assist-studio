part of '../../studio_mac_workspace.dart';

// 设备操作面板，负责连接、驱动、截图和本机指引入口。
class _DeviceActionPanel extends StatelessWidget {
  const _DeviceActionPanel({
    required this.snapshot,
    required this.controller,
    required this.canCapture,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final bool canCapture;

  /// 渲染设备页的安全操作按钮。
  /// 按钮禁用逻辑在 UI 和 Runtime 双层兜底。
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '操作',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _ConnectPrimaryAction(
            snapshot: snapshot,
            controller: controller,
            controlKey: const ValueKey('device-connect-one-button'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CommandButton(
                controlKey: const ValueKey('check-local-stack'),
                label: '查环境',
                icon: Icons.rule_folder_outlined,
                onPressed: _localCheckDisabled(snapshot)
                    ? null
                    : () => controller.refreshDependencyReport(),
              ),
              _CommandButton(
                controlKey: const ValueKey('open-local-setup-guide'),
                label: '指引',
                icon: Icons.integration_instructions_outlined,
                onPressed: () async => _openLocalSetupGuide(context, snapshot),
              ),
              _CommandButton(
                controlKey: const ValueKey('device-stop-driver'),
                label: '停止驱动',
                icon: Icons.stop,
                onPressed: _stopDriverDisabled(snapshot)
                    ? null
                    : () => controller.stopAppium(),
              ),
              _CommandButton(
                controlKey: const ValueKey('device-bind-usb'),
                label: '重绑',
                icon: Icons.usb_outlined,
                onPressed: _bindButtonDisabled(snapshot)
                    ? null
                    : () => controller.bindCurrentUsbDevice(),
              ),
              _CommandButton(
                label: '断开',
                icon: Icons.link_off,
                onPressed:
                    _deviceBusy(snapshot.connectionStatus) ||
                        snapshot.connectionStatus != ConnectionStatus.connected
                    ? null
                    : () => controller.disconnectDevice(),
              ),
              _CommandButton(
                label: '截图',
                icon: Icons.screenshot_monitor_outlined,
                onPressed: canCapture
                    ? () =>
                          controller.captureScreenshot(reason: 'device-preview')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.appiumOwnership == AppiumProcessOwnership.external
                ? '外部驱动可直接使用。'
                : '按提示输入密码，应用会自动连接。',
            style: TextStyle(color: StudioColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}

/// 判断重绑按钮是否应该禁用。
/// 运行、连接中和已连接时都不允许改设备绑定。
bool _bindButtonDisabled(StudioRuntimeSnapshot snapshot) {
  return _deviceBusy(snapshot.connectionStatus) ||
      _appiumBusy(snapshot.appiumStatus) ||
      snapshot.connectionStatus == ConnectionStatus.connected ||
      snapshot.runStatus != RunStatus.idle;
}

/// 判断本机检查按钮是否应该禁用。
/// 连接、驱动处理或运行中不再插入额外检查，避免打乱主链路。
bool _localCheckDisabled(StudioRuntimeSnapshot snapshot) {
  return _deviceBusy(snapshot.connectionStatus) ||
      _appiumBusy(snapshot.appiumStatus) ||
      snapshot.runStatus != RunStatus.idle;
}

/// 判断停止驱动按钮是否应该禁用。
/// 连接链路处理中不允许停止驱动，避免破坏一键连接状态机。
bool _stopDriverDisabled(StudioRuntimeSnapshot snapshot) {
  return _deviceBusy(snapshot.connectionStatus) ||
      _appiumBusy(snapshot.appiumStatus) ||
      snapshot.runStatus != RunStatus.idle ||
      snapshot.appiumOwnership == AppiumProcessOwnership.external ||
      snapshot.appiumStatus == AppiumProcessStatus.stopped;
}

/// 打开本机指引抽屉。
/// 抽屉只读展示准备信息，不自动安装、不启动外部命令。
Future<void> _openLocalSetupGuide(
  BuildContext context,
  StudioRuntimeSnapshot snapshot,
) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭指引',
    barrierColor: Colors.black.withValues(alpha: 0.52),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: _LocalSetupGuideDrawer(snapshot: snapshot),
      );
    },
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      );
    },
  );
}
