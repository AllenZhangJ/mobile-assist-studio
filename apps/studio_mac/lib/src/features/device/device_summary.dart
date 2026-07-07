part of '../../studio_mac_workspace.dart';

// 设备摘要面板，负责把连接、驱动和截图状态压成用户可读摘要。
class _DeviceSummaryPanel extends StatelessWidget {
  const _DeviceSummaryPanel({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  /// 渲染设备状态摘要和关键事实。
  /// 这里不展示底层端点，只给用户看可操作状态。
  @override
  Widget build(BuildContext context) {
    final hasPreview = snapshot.latestScreenshotBase64 != null;
    final diagnostic = snapshot.lastConnectionDiagnostic;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设备',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Text(
            _deviceSummaryMessage(snapshot),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.45),
          ),
          if (diagnostic != null &&
              snapshot.connectionStatus != ConnectionStatus.connected) ...[
            const SizedBox(height: 12),
            _ConnectionDiagnosticCard(diagnostic: diagnostic),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(
                label: _deviceStatusLabel(snapshot.connectionStatus),
                tone: _toneForConnection(snapshot.connectionStatus),
              ),
              StatusPill(
                label: _appiumStatusLabel(snapshot.appiumStatus),
                tone: _toneForAppium(snapshot.appiumStatus),
              ),
              StatusPill(
                label: hasPreview ? '预览就绪' : '无预览',
                tone: hasPreview
                    ? StudioStatusTone.ready
                    : StudioStatusTone.offline,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DeviceFactRow(label: '模式', value: '单台有线手机'),
          _DeviceFactRow(
            label: '会话',
            value: snapshot.sessionId == null
                ? '未连接'
                : _shortSession(snapshot.sessionId!),
          ),
          _DeviceFactRow(
            label: '截图',
            value: snapshot.latestScreenshotAt == null
                ? '暂无截图'
                : _timeOnly(snapshot.latestScreenshotAt!),
          ),
        ],
      ),
    );
  }
}

// 设备事实行，统一摘要面板内的 label/value 排版。
class _DeviceFactRow extends StatelessWidget {
  const _DeviceFactRow({required this.label, required this.value});

  final String label;
  final String value;

  /// 渲染一行短事实。
  /// 右侧值固定省略，避免中文或会话摘要撑开面板。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
