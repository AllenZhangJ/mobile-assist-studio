part of '../../studio_mac_workspace.dart';

// 生成录制动作线的脱敏摘要，用于本地沟通和人工确认。
String _recordedActionsSummary(List<_RecordedActions> actions) {
  final lines = <String>['录制动作摘要', '数量：${actions.length}'];
  if (actions.isEmpty) {
    return [...lines, '动作：无'].join('\n');
  }
  return [
    ...lines,
    for (var index = 0; index < actions.length; index += 1)
      _recordedActionsSummaryLine(index, actions[index]),
  ].join('\n');
}

// 生成单条动作摘要，默认不包含坐标、输入明文或截图内容。
String _recordedActionsSummaryLine(int index, _RecordedActions action) {
  final evidence = action.evidence.hasImage ? '有图' : '无图';
  return [
    '${index + 1}. ${action.type.label}',
    action.label,
    action.timelineSummary,
    evidence,
  ].join(' · ');
}
