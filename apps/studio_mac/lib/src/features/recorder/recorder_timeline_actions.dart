part of '../../studio_mac_workspace.dart';

// Recorder 时间线动作，负责本地排序、复制、删除和脱敏摘要复制。
extension _RecorderTimelineActions on _RecorderPageState {
  // 清空当前录制动作，供用户重新组织流程。
  void _clearActions() {
    _mutateActions(_actions.clear);
  }

  // 将动作上移一位，只调整本地时间线顺序。
  void _moveActionsUp(_RecordedActions action) {
    final index = _actions.indexWhere((item) => item.id == action.id);
    if (index <= 0) return;
    _mutateActions(() {
      final item = _actions.removeAt(index);
      _actions.insert(index - 1, item);
    });
  }

  // 将动作下移一位，只调整本地时间线顺序。
  void _moveActionsDown(_RecordedActions action) {
    final index = _actions.indexWhere((item) => item.id == action.id);
    if (index == -1 || index >= _actions.length - 1) return;
    _mutateActions(() {
      final item = _actions.removeAt(index);
      _actions.insert(index + 1, item);
    });
  }

  // 复制当前动作到其后方，保留参数和证据但生成新的本地 ID。
  void _duplicateActions(_RecordedActions action) {
    final index = _actions.indexWhere((item) => item.id == action.id);
    if (index == -1) return;
    final duplicated = action.copyWith(
      id: _nextId(),
      label: '复制 ${action.label}',
    );
    _mutateActions(() => _actions.insert(index + 1, duplicated));
  }

  // 删除当前动作，只影响本地录制列表，不删除截图证据。
  void _deleteActions(_RecordedActions action) {
    _mutateActions(() => _actions.removeWhere((item) => item.id == action.id));
  }

  // 复制当前录制动作摘要，只写剪贴板，不展示坐标、明文或截图。
  Future<void> _copyActionsSummary() async {
    await _copyPlainText(context, text: _recordedActionsSummary(_actions));
  }
}
