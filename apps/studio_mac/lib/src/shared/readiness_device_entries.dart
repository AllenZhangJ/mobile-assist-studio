part of '../studio_mac_workspace.dart';

// 设备准备项 helper，负责手机连接、信任、会话和安全截图提示。

/// 生成 USB 手机准备项。
/// 连接态文案保持短句，方便 Device、Status 和 Console 共用。
_ReadinessGuideEntry _usbDeviceReadinessEntry(ConnectionStatus status) {
  return switch (status) {
    ConnectionStatus.connected => const _ReadinessGuideEntry(
      label: '手机',
      status: '就绪',
      summary: '已连接本机手机。',
      nextStep: '预览和运行时请保持解锁。',
      tone: StudioStatusTone.ready,
      icon: Icons.usb_outlined,
    ),
    ConnectionStatus.initializing ||
    ConnectionStatus.connecting => const _ReadinessGuideEntry(
      label: '手机',
      status: '连接中',
      summary: '正在创建设备会话。',
      nextStep: '请等待连接完成。',
      tone: StudioStatusTone.running,
      icon: Icons.sync,
    ),
    ConnectionStatus.waitingForDeveloperTrust => const _ReadinessGuideEntry(
      label: '手机',
      status: '等待中',
      summary: '设备可用，等待信任。',
      nextStep: '请在手机信任开发者后重连。',
      tone: StudioStatusTone.warning,
      icon: Icons.verified_user_outlined,
    ),
    ConnectionStatus.disconnecting => const _ReadinessGuideEntry(
      label: '手机',
      status: '关闭中',
      summary: '正在安全断开设备。',
      nextStep: '请等待断开完成。',
      tone: StudioStatusTone.warning,
      icon: Icons.link_off,
    ),
    ConnectionStatus.error => const _ReadinessGuideEntry(
      label: '手机',
      status: '错误',
      summary: '设备连接失败，需要处理。',
      nextStep: '查看控制台，解锁手机后重连。',
      tone: StudioStatusTone.error,
      icon: Icons.error_outline,
    ),
    ConnectionStatus.disconnected => const _ReadinessGuideEntry(
      label: '手机',
      status: '离线',
      summary: '当前未连接手机。',
      nextStep: '插入并解锁手机，然后连接。',
      tone: StudioStatusTone.offline,
      icon: Icons.phone_iphone_outlined,
    ),
  };
}

/// 生成开发者信任准备项。
/// 信任是用户操作，应用只提示不绕过。
_ReadinessGuideEntry _developerTrustReadinessEntry(ConnectionStatus status) {
  if (status == ConnectionStatus.waitingForDeveloperTrust) {
    return const _ReadinessGuideEntry(
      label: '开发者信任',
      status: '操作',
      summary: '首次启动前需要手动信任。',
      nextStep: '请在手机信任证书后重连。',
      tone: StudioStatusTone.warning,
      icon: Icons.admin_panel_settings_outlined,
    );
  }
  if (status == ConnectionStatus.connected) {
    return const _ReadinessGuideEntry(
      label: '开发者信任',
      status: '就绪',
      summary: '当前设备可运行会话。',
      nextStep: '当前无需信任。',
      tone: StudioStatusTone.ready,
      icon: Icons.verified_outlined,
    );
  }
  if (status == ConnectionStatus.error) {
    return const _ReadinessGuideEntry(
      label: '开发者信任',
      status: '校验',
      summary: '会话失败时请检查信任。',
      nextStep: '仅按控制台提示处理手机设置。',
      tone: StudioStatusTone.warning,
      icon: Icons.fact_check_outlined,
    );
  }
  return const _ReadinessGuideEntry(
    label: '开发者信任',
    status: '等待',
    summary: '首次真机连接时会校验信任。',
    nextStep: '点连接设备。',
    tone: StudioStatusTone.offline,
    icon: Icons.shield_outlined,
  );
}
