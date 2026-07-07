part of '../studio_mac_workspace.dart';

// 连接诊断卡，供设备页和运行页复用同一套短文案。
class _ConnectionDiagnosticCard extends StatelessWidget {
  const _ConnectionDiagnosticCard({
    required this.diagnostic,
    this.title = '连接受阻',
  });

  final RuntimeConnectionDiagnostic diagnostic;
  final String title;

  // 渲染短诊断和下一步，不展示底层端点、路径或完整设备标识。
  @override
  Widget build(BuildContext context) {
    final tone = _connectionDiagnosticTone(diagnostic.type);
    return _ToneBorderSurface(
      tone: tone,
      child: Column(
        key: const ValueKey('connection-diagnostic-card'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_connectionDiagnosticIcon(diagnostic.type), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: _connectionDiagnosticLabel(diagnostic.type),
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            diagnostic.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            diagnostic.nextStep,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.35),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('copy-connection-diagnostic'),
              onPressed: () => unawaited(
                _copyPlainText(
                  context,
                  text: _connectionDiagnosticCopyText(diagnostic),
                  message: '诊断已复制',
                ),
              ),
              icon: const Icon(Icons.copy_all_outlined, size: 16),
              label: const Text('复制诊断'),
            ),
          ),
        ],
      ),
    );
  }
}

// 将连接问题类型压缩成用户能扫读的短标签。
String _connectionDiagnosticLabel(RuntimeConnectionIssueType type) {
  return switch (type) {
    RuntimeConnectionIssueType.developerTrust => '信任',
    RuntimeConnectionIssueType.deviceLocked => '解锁',
    RuntimeConnectionIssueType.appiumUnavailable => '驱动',
    RuntimeConnectionIssueType.tunnelUnavailable => '隧道',
    RuntimeConnectionIssueType.deviceNotVisible => 'USB',
    RuntimeConnectionIssueType.driverDeviceNotVisible => '驱动',
    RuntimeConnectionIssueType.deviceUnavailable => 'USB',
    RuntimeConnectionIssueType.wdaBuildFailed => '构建',
    RuntimeConnectionIssueType.wdaStartFailed => '会话',
    RuntimeConnectionIssueType.unknown => '检查',
  };
}

// 返回连接问题的状态色，信任和隧道是可处理提醒，其它按错误展示。
StudioStatusTone _connectionDiagnosticTone(RuntimeConnectionIssueType type) {
  return switch (type) {
    RuntimeConnectionIssueType.developerTrust ||
    RuntimeConnectionIssueType.tunnelUnavailable => StudioStatusTone.warning,
    _ => StudioStatusTone.error,
  };
}

// 返回连接问题对应图标，保持各页面视觉一致。
IconData _connectionDiagnosticIcon(RuntimeConnectionIssueType type) {
  return switch (type) {
    RuntimeConnectionIssueType.developerTrust =>
      Icons.admin_panel_settings_outlined,
    RuntimeConnectionIssueType.deviceLocked => Icons.lock_outline,
    RuntimeConnectionIssueType.appiumUnavailable => Icons.hub_outlined,
    RuntimeConnectionIssueType.tunnelUnavailable => Icons.cable_outlined,
    RuntimeConnectionIssueType.deviceNotVisible => Icons.usb_off,
    RuntimeConnectionIssueType.driverDeviceNotVisible =>
      Icons.phone_iphone_outlined,
    RuntimeConnectionIssueType.deviceUnavailable => Icons.usb_outlined,
    RuntimeConnectionIssueType.wdaBuildFailed => Icons.build_circle_outlined,
    RuntimeConnectionIssueType.wdaStartFailed =>
      Icons.settings_input_component_outlined,
    RuntimeConnectionIssueType.unknown => Icons.error_outline,
  };
}

// 生成可分享的连接诊断摘要。
// 内容二次脱敏，避免把端点、路径、完整设备标识复制出去。
String _connectionDiagnosticCopyText(RuntimeConnectionDiagnostic diagnostic) {
  final lines = <String>[
    '连接诊断',
    '问题：${_connectionDiagnosticLabel(diagnostic.type)}',
    '状态：${diagnostic.summary}',
    '下一步：${diagnostic.nextStep}',
  ];
  final detail = _safeRuntimeEventMessage(diagnostic.detail).trim();
  if (detail.isNotEmpty) {
    lines.add('详情：$detail');
  }
  lines.add('边界：本机、单设备、串行、无路径、无端点、无完整标识');
  return lines.join('\n');
}
