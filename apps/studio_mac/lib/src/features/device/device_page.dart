part of '../../studio_mac_workspace.dart';

// 设备页入口与侧栏面板，负责展示当前设备状态、准备项和连接动作。
class _DevicePage extends StatelessWidget {
  const _DevicePage({required this.snapshot, required this.controller});

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;

  /// 渲染设备页双栏骨架。
  /// 左侧承载状态与动作，右侧保留实时预览。
  @override
  Widget build(BuildContext context) {
    final canCapture =
        snapshot.connectionStatus == ConnectionStatus.connected &&
        snapshot.runStatus == RunStatus.idle;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 336,
            child: ListView(
              key: const ValueKey('device-side-scroll'),
              children: [
                _DeviceSummaryPanel(snapshot: snapshot),
                const SizedBox(height: 14),
                _DeviceReadinessPanel(snapshot: snapshot),
                const SizedBox(height: 14),
                _DeviceActionPanel(
                  snapshot: snapshot,
                  controller: controller,
                  canCapture: canCapture,
                ),
                const SizedBox(height: 14),
                _DeviceInspectorPanel(
                  snapshot: snapshot,
                  controller: controller,
                ),
                const SizedBox(height: 14),
                _DeviceTargetLibraryPanel(
                  snapshot: snapshot,
                  controller: controller,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _DevicePreview(snapshot: snapshot, controller: controller),
          ),
        ],
      ),
    );
  }
}
