part of '../../studio_mac_workspace.dart';

// Recorder 流程生成动作，负责 Promote 和生成后的安全导航。
extension _RecorderWorkflowActions on _RecorderPageState {
  // 将当前动作转换为 Project DSL，并交给 runtime 校验保存。
  Future<void> _promoteToWorkflow() async {
    final actions = <_RecordedActions>[];
    for (final action in _actions) {
      if (action.type == _RecordedActionsType.tap &&
          action.x != null &&
          action.y != null) {
        final targetRef = _targetIdForRecordedAction(action);
        final target = RuntimeTargetDefinition.coordinate(
          id: targetRef,
          label: action.target,
          x: action.x!,
          y: action.y!,
          viewportWidth: _previewScreenshotSize?.width.round(),
          viewportHeight: _previewScreenshotSize?.height.round(),
        );
        final saved = await widget.controller.upsertTarget(target);
        if (!saved) {
          if (!mounted) return;
          _setWorkflowGenerated(false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('目标未保存。')));
          return;
        }
        actions.add(action.copyWith(targetRef: targetRef));
      } else {
        actions.add(action);
      }
    }
    final workflow = _workflowFromRecordedActions(actions);
    final updated = await widget.controller.updateWorkflow(workflow);
    if (!mounted) return;
    _setWorkflowGenerated(updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(updated ? '已生成流程。' : '流程已生成，但有提醒。')));
  }

  // 打开生成后的 Workflow 画布，便于继续编辑。
  void _openGeneratedWorkflow() {
    widget.onNavigate(3);
  }

  // 打开运行页，只做导航，不直接启动任务。
  void _openGeneratedExecute() {
    widget.onNavigate(4);
  }
}

// 为录制动作生成稳定目标 ID，重复生成时覆盖同一个目标资产。
String _targetIdForRecordedAction(_RecordedActions action) {
  final raw = action.id.trim().replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-');
  return 'recorder_${raw.isEmpty ? 'action' : raw}';
}
