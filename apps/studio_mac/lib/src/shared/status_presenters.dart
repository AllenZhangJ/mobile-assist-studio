part of '../studio_mac_workspace.dart';

// 状态展示 presenter，统一连接、驱动和运行状态的短文案与色调。
// 该层只做快照到 UI 展示的映射，不读取设备、不触发运行。

// 返回连接状态的短文案和色调，供顶部状态、详情和摘要复用。
({String label, StudioStatusTone tone}) _connectionStatusPresentation(
  ConnectionStatus status,
) {
  return switch (status) {
    ConnectionStatus.connected => (label: '设备就绪', tone: StudioStatusTone.ready),
    ConnectionStatus.error => (label: '设备错误', tone: StudioStatusTone.error),
    ConnectionStatus.waitingForDeveloperTrust => (
      label: '需要信任',
      tone: StudioStatusTone.warning,
    ),
    ConnectionStatus.initializing || ConnectionStatus.connecting => (
      label: '连接中',
      tone: StudioStatusTone.running,
    ),
    ConnectionStatus.disconnecting => (
      label: '断开中',
      tone: StudioStatusTone.warning,
    ),
    ConnectionStatus.disconnected => (
      label: '设备离线',
      tone: StudioStatusTone.offline,
    ),
  };
}

// 返回驱动状态的短文案和色调，避免页面各自维护 Appium 状态映射。
({String label, StudioStatusTone tone}) _appiumStatusPresentation(
  AppiumProcessStatus status,
) {
  return switch (status) {
    AppiumProcessStatus.running => (
      label: '驱动运行',
      tone: StudioStatusTone.ready,
    ),
    AppiumProcessStatus.starting => (
      label: '驱动启动',
      tone: StudioStatusTone.running,
    ),
    AppiumProcessStatus.stopping => (
      label: '驱动停止',
      tone: StudioStatusTone.warning,
    ),
    AppiumProcessStatus.error => (label: '驱动错误', tone: StudioStatusTone.error),
    AppiumProcessStatus.stopped => (
      label: '驱动离线',
      tone: StudioStatusTone.offline,
    ),
  };
}

// 返回运行状态的短文案和色调，保持主界面只展示摘要态。
({String label, StudioStatusTone tone}) _runStatusPresentation(
  RunStatus status,
) {
  return switch (status) {
    RunStatus.idle => (label: '空闲', tone: StudioStatusTone.ready),
    RunStatus.running => (label: '运行中', tone: StudioStatusTone.running),
    RunStatus.paused => (label: '已暂停', tone: StudioStatusTone.warning),
    RunStatus.stopping => (label: '停止中', tone: StudioStatusTone.warning),
  };
}

// 返回连接状态色调，供只需要颜色、不需要文案的组件使用。
StudioStatusTone _toneForConnection(ConnectionStatus status) {
  return _connectionStatusPresentation(status).tone;
}

// 返回驱动状态色调，供准备度、设备摘要和详情卡复用。
StudioStatusTone _toneForAppium(AppiumProcessStatus status) {
  return _appiumStatusPresentation(status).tone;
}

// 返回用户可读的设备状态短文案。
String _deviceStatusLabel(ConnectionStatus status) {
  return _connectionStatusPresentation(status).label;
}

// 返回用户可读的驱动状态短文案。
String _appiumStatusLabel(AppiumProcessStatus status) {
  return _appiumStatusPresentation(status).label;
}

// 返回运行状态说明，用于状态详情抽屉的摘要区域。
String _runStatusSummary(RunStatus status) {
  return switch (status) {
    RunStatus.idle => '当前没有运行任务。',
    RunStatus.running => '流程正在串行运行。',
    RunStatus.paused => '运行已暂停，等待人工处理。',
    RunStatus.stopping => '正在等待当前动作完成。',
  };
}

// 返回运行状态下一步建议，保持错误处理指引集中维护。
String _runStatusNextStep(RunStatus status) {
  return switch (status) {
    RunStatus.idle => '确认设备和流程后开始运行。',
    RunStatus.running => '需要中止时使用安全停止。',
    RunStatus.paused => '处理问题后安全收口。',
    RunStatus.stopping => '等待动作结束后回到空闲。',
  };
}

// 返回运行状态图标，供状态详情卡保持一致的视觉提示。
IconData _iconForLiveRunStatus(RunStatus status) {
  return switch (status) {
    RunStatus.idle => Icons.check_circle_outline,
    RunStatus.running => Icons.play_circle_outline,
    RunStatus.paused => Icons.pause_circle_outline,
    RunStatus.stopping => Icons.stop_circle_outlined,
  };
}
