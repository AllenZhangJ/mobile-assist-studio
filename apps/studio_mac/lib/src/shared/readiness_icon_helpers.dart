part of '../studio_mac_workspace.dart';

// 准备度图标 helper，统一紧凑状态行的图标映射。

/// 返回准备项状态图标。
/// 与状态色保持一致，用于紧凑行展示。
IconData _iconForReadiness(StudioStatusTone tone) {
  return switch (tone) {
    StudioStatusTone.ready => Icons.check_circle_outline,
    StudioStatusTone.warning => Icons.hourglass_top,
    StudioStatusTone.error => Icons.error_outline,
    StudioStatusTone.offline => Icons.radio_button_unchecked,
    StudioStatusTone.running => Icons.sync,
  };
}
