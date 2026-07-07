part of '../../studio_mac_workspace.dart';

// 录制时间轴组件，负责动作列表外壳和行展示。
class _RecorderTimeline extends StatelessWidget {
  const _RecorderTimeline({
    required this.recording,
    required this.actions,
    required this.onOpenActions,
    required this.onMoveActionsUp,
    required this.onMoveActionsDown,
    required this.onDuplicateActions,
    required this.onDeleteActions,
    required this.onCopySummary,
  });

  final bool recording;
  final List<_RecordedActions> actions;
  final ValueChanged<_RecordedActions> onOpenActions;
  final ValueChanged<_RecordedActions> onMoveActionsUp;
  final ValueChanged<_RecordedActions> onMoveActionsDown;
  final ValueChanged<_RecordedActions> onDuplicateActions;
  final ValueChanged<_RecordedActions> onDeleteActions;
  final VoidCallback? onCopySummary;

  // 渲染时间线外壳，动作为空时只展示引导文案。
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RecorderTimelineHeader(
            recording: recording,
            onCopySummary: onCopySummary,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: actions.isEmpty
                ? const _RecorderTimelineEmpty()
                : ListView.separated(
                    key: const ValueKey('recorder-action-timeline'),
                    itemCount: actions.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: StudioColors.border, height: 12),
                    itemBuilder: (context, index) {
                      return _RecordedActionsRow(
                        index: index,
                        action: actions[index],
                        canMoveUp: index > 0,
                        canMoveDown: index < actions.length - 1,
                        onTap: () => onOpenActions(actions[index]),
                        onMoveUp: () => onMoveActionsUp(actions[index]),
                        onMoveDown: () => onMoveActionsDown(actions[index]),
                        onDuplicate: () => onDuplicateActions(actions[index]),
                        onDelete: () => onDeleteActions(actions[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
