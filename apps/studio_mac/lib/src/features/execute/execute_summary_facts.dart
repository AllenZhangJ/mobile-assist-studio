part of '../../studio_mac_workspace.dart';

// Execute 运行事实分片，展示设备、驱动、会话和截图的短状态。
// 这里不展示完整设备标识、端点或原始 WebDriver 数据。

// 运行事实面板，展示设备、驱动、会话和截图的短状态。
class _ExecuteRuntimeFacts extends StatelessWidget {
  const _ExecuteRuntimeFacts({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染设备、驱动、会话和截图等运行前事实。
  @override
  Widget build(BuildContext context) {
    return _InsetSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('运行状态', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _DeviceFactRow(
            label: '设备',
            value: _deviceStatusLabel(snapshot.connectionStatus),
          ),
          const SizedBox(height: 10),
          _DeviceFactRow(
            label: '驱动',
            value: _appiumStatusLabel(snapshot.appiumStatus),
          ),
          const SizedBox(height: 10),
          _DeviceFactRow(
            label: '会话',
            value: snapshot.sessionId == null
                ? '未连接'
                : _shortSession(snapshot.sessionId!),
          ),
          const SizedBox(height: 10),
          _DeviceFactRow(
            label: '上次截图',
            value: snapshot.latestScreenshotAt == null
                ? '暂无截图'
                : _timeOnly(snapshot.latestScreenshotAt!),
          ),
        ],
      ),
    );
  }
}
