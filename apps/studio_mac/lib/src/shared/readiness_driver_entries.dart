part of '../studio_mac_workspace.dart';

// 驱动准备项 helper，负责把本机驱动状态转成用户可理解的下一步。

/// 生成驱动服务准备项。
/// 只表达用户下一步，不暴露 Appium 进程细节。
_ReadinessGuideEntry _appiumReadinessEntry(AppiumProcessStatus status) {
  return switch (status) {
    AppiumProcessStatus.running => const _ReadinessGuideEntry(
      label: '驱动服务',
      status: '就绪',
      summary: '本机驱动可用。',
      nextStep: '解锁 iPhone 后连接。',
      tone: StudioStatusTone.ready,
      icon: Icons.hub_outlined,
    ),
    AppiumProcessStatus.starting => const _ReadinessGuideEntry(
      label: '驱动服务',
      status: '启动中',
      summary: '正在等待本机驱动。',
      nextStep: '请保持窗口打开直到就绪。',
      tone: StudioStatusTone.running,
      icon: Icons.sync,
    ),
    AppiumProcessStatus.stopping => const _ReadinessGuideEntry(
      label: '驱动服务',
      status: '停止中',
      summary: '服务正在关闭。',
      nextStep: '等待进程结束后再启动。',
      tone: StudioStatusTone.warning,
      icon: Icons.pause_circle_outline,
    ),
    AppiumProcessStatus.error => const _ReadinessGuideEntry(
      label: '驱动服务',
      status: '错误',
      summary: '驱动需处理后才能连接设备。',
      nextStep: '点连接设备；仍失败再查环境。',
      tone: StudioStatusTone.error,
      icon: Icons.error_outline,
    ),
    AppiumProcessStatus.stopped => const _ReadinessGuideEntry(
      label: '驱动服务',
      status: '离线',
      summary: '当前无可用驱动服务。',
      nextStep: '点连接设备。',
      tone: StudioStatusTone.offline,
      icon: Icons.radio_button_unchecked,
    ),
  };
}
