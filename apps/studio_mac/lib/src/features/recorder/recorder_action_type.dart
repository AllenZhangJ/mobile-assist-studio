part of '../../studio_mac_workspace.dart';

// 录制动作类型，负责用户可读的动作名称。
enum _RecordedActionsType {
  tap('点击'),
  wait('等待'),
  swipe('滑动'),
  input('输入');

  // 创建录制动作类型，并绑定短中文标签。
  const _RecordedActionsType(this.label);

  final String label;
}

// 为录制动作选择状态色，保持时间线的短摘要表达。
StudioStatusTone _toneForRecordedActions(_RecordedActionsType type) {
  return switch (type) {
    _RecordedActionsType.tap => StudioStatusTone.ready,
    _RecordedActionsType.wait => StudioStatusTone.warning,
    _RecordedActionsType.swipe => StudioStatusTone.running,
    _RecordedActionsType.input => StudioStatusTone.ready,
  };
}
