part of '../studio_mac_workspace.dart';

// 本机依赖状态 helper，负责把 dependency report 映射成短中文和状态色。

/// 格式化依赖检查时间。
/// 未检查时保持短文案，避免主界面展示空时间。
String _dependencyCheckedAt(LocalDependencyReport report) {
  final checkedAt = report.checkedAt;
  if (checkedAt == null) return '未检查';
  return '已检查 ${_timeOnly(checkedAt)}';
}

/// 返回依赖检查状态短标签。
/// 文案面向普通用户，不暴露底层枚举。
String _dependencyStatusLabel(LocalDependencyStatus status) {
  return switch (status) {
    LocalDependencyStatus.unknown => '未知',
    LocalDependencyStatus.ready => '就绪',
    LocalDependencyStatus.warning => '提醒',
    LocalDependencyStatus.error => '错误',
  };
}

/// 将依赖检查状态映射为 UI 状态色。
/// 所有本机依赖展示复用同一套色调。
StudioStatusTone _toneForDependency(LocalDependencyStatus status) {
  return switch (status) {
    LocalDependencyStatus.unknown => StudioStatusTone.offline,
    LocalDependencyStatus.ready => StudioStatusTone.ready,
    LocalDependencyStatus.warning => StudioStatusTone.warning,
    LocalDependencyStatus.error => StudioStatusTone.error,
  };
}

/// 根据依赖项 ID 返回图标。
/// 未知项使用通用规则图标兜底。
IconData _iconForDependency(String id) {
  return switch (id) {
    'appium-cli' => Icons.hub_outlined,
    'xcode-cli' => Icons.developer_board_outlined,
    'ios-device-tools' => Icons.usb_outlined,
    'ios-tunnel' => Icons.cable_outlined,
    'wda-prerequisites' => Icons.settings_input_component_outlined,
    _ => Icons.rule_folder_outlined,
  };
}
