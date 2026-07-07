part of '../../studio_mac_workspace.dart';

// Recorder 详情动作，负责打开动作详情抽屉并保存本地草稿。
extension _RecorderDetailActions on _RecorderPageState {
  // 打开动作详情抽屉，保存时替换对应动作，取消时不改时间线。
  Future<void> _openActionsDrawer(_RecordedActions action) async {
    final updated = await showGeneralDialog<_RecordedActions>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭详情',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: _ActionsDetailDrawer(action: action),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
    if (!mounted || updated == null) return;
    final index = _actions.indexWhere((item) => item.id == updated.id);
    if (index == -1) return;
    _mutateActions(() => _actions[index] = updated);
  }
}
