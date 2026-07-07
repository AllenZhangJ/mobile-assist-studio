part of '../studio_mac_workspace.dart';

// 会话准备项 helper，负责手机会话和安全截图的运行通道提示。

/// 生成 WDA 手机会话准备项。
/// 会话细节保持摘要化，不展示 endpoint 或底层 payload。
_ReadinessGuideEntry _wdaReadinessEntry(StudioRuntimeSnapshot snapshot) {
  final status = snapshot.connectionStatus;
  if (status == ConnectionStatus.connected) {
    return const _ReadinessGuideEntry(
      label: '手机会话',
      status: '就绪',
      summary: '手机会话已连接此设备。',
      nextStep: '就绪后可截图或运行。',
      tone: StudioStatusTone.ready,
      icon: Icons.settings_input_component_outlined,
    );
  }
  if (status == ConnectionStatus.connecting ||
      status == ConnectionStatus.initializing) {
    return const _ReadinessGuideEntry(
      label: '手机会话',
      status: '构建中',
      summary: '正在准备会话。',
      nextStep: '会话就绪前请保持解锁。',
      tone: StudioStatusTone.running,
      icon: Icons.precision_manufacturing_outlined,
    );
  }
  if (status == ConnectionStatus.waitingForDeveloperTrust) {
    return const _ReadinessGuideEntry(
      label: '手机会话',
      status: '受阻',
      summary: '未信任前会话无法完成。',
      nextStep: '请在手机完成信任后重连。',
      tone: StudioStatusTone.warning,
      icon: Icons.lock_outline,
    );
  }
  if (status == ConnectionStatus.error) {
    final diagnostic = snapshot.lastConnectionDiagnostic;
    if (diagnostic != null) {
      return _connectionDiagnosticReadinessEntry(diagnostic);
    }
    return const _ReadinessGuideEntry(
      label: '手机会话',
      status: '错误',
      summary: '手机会话创建失败。',
      nextStep: '查看控制台里的连接指引。',
      tone: StudioStatusTone.error,
      icon: Icons.error_outline,
    );
  }
  return _ReadinessGuideEntry(
    label: '手机会话',
    status: '等待',
    summary: snapshot.appiumStatus == AppiumProcessStatus.running
        ? '驱动已就绪，连接设备后启动会话。'
        : '会话会等待驱动和设备就绪。',
    nextStep: snapshot.appiumStatus == AppiumProcessStatus.running
        ? '连接设备后创建手机会话。'
        : '点连接设备。',
    tone: StudioStatusTone.offline,
    icon: Icons.settings_input_component_outlined,
  );
}

/// 把结构化连接诊断映射为会话准备项。
/// 这里复用诊断卡的短标签、图标和色调，不另起一套文案规则。
_ReadinessGuideEntry _connectionDiagnosticReadinessEntry(
  RuntimeConnectionDiagnostic diagnostic,
) {
  return _ReadinessGuideEntry(
    label: '手机会话',
    status: _connectionDiagnosticLabel(diagnostic.type),
    summary: diagnostic.summary,
    nextStep: diagnostic.nextStep,
    tone: _connectionDiagnosticTone(diagnostic.type),
    icon: _connectionDiagnosticIcon(diagnostic.type),
  );
}

/// 生成安全截图准备项。
/// 运行中只提示锁定，不并发抢占设备通道。
_ReadinessGuideEntry _safeCaptureReadinessEntry(
  StudioRuntimeSnapshot snapshot,
) {
  if (snapshot.connectionStatus == ConnectionStatus.connected &&
      snapshot.runStatus == RunStatus.idle) {
    return const _ReadinessGuideEntry(
      label: '安全截图',
      status: '就绪',
      summary: '设备空闲，截图不会影响运行。',
      nextStep: '点“截图”刷新预览。',
      tone: StudioStatusTone.ready,
      icon: Icons.screenshot_monitor_outlined,
    );
  }
  if (snapshot.runStatus == RunStatus.running ||
      snapshot.runStatus == RunStatus.stopping) {
    return const _ReadinessGuideEntry(
      label: '安全截图',
      status: '锁定',
      summary: '运行中，截图会谨慎执行。',
      nextStep: '等待当前动作完成。',
      tone: StudioStatusTone.warning,
      icon: Icons.lock_clock_outlined,
    );
  }
  return const _ReadinessGuideEntry(
    label: '安全截图',
    status: '等待',
    summary: '设备就绪后可截图。',
    nextStep: '连接 iPhone，等运行空闲。',
    tone: StudioStatusTone.offline,
    icon: Icons.screenshot_monitor_outlined,
  );
}
