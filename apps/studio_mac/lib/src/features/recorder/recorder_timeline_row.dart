part of '../../studio_mac_workspace.dart';

// 录制动作行，默认只展示动作摘要并隐藏坐标。
class _RecordedActionsRow extends StatelessWidget {
  const _RecordedActionsRow({
    required this.index,
    required this.action,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onTap,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDuplicate,
    required this.onDelete,
  });

  final int index;
  final _RecordedActions action;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onTap;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  // 渲染单行动作摘要，详情通过抽屉延后展示。
  @override
  Widget build(BuildContext context) {
    final tone = _toneForRecordedActions(action.type);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: StudioColors.muted,
                  fontFamily: 'Menlo',
                ),
              ),
            ),
            StatusPill(label: action.type.label, tone: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    action.timelineSummary,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudioColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StatusPill(
              label: action.evidence.hasImage ? '有图' : '无图',
              tone: action.evidence.hasImage
                  ? StudioStatusTone.running
                  : StudioStatusTone.offline,
            ),
            const SizedBox(width: 12),
            _RecorderActionIconButton(
              key: ValueKey('recorder-action-up-${action.id}'),
              tooltip: '上移',
              icon: Icons.keyboard_arrow_up,
              onPressed: canMoveUp ? onMoveUp : null,
            ),
            _RecorderActionIconButton(
              key: ValueKey('recorder-action-down-${action.id}'),
              tooltip: '下移',
              icon: Icons.keyboard_arrow_down,
              onPressed: canMoveDown ? onMoveDown : null,
            ),
            _RecorderActionIconButton(
              key: ValueKey('recorder-action-copy-${action.id}'),
              tooltip: '复制',
              icon: Icons.copy,
              onPressed: onDuplicate,
            ),
            _RecorderActionIconButton(
              key: ValueKey('recorder-action-delete-${action.id}'),
              tooltip: '删除',
              icon: Icons.delete_outline,
              onPressed: onDelete,
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              color: StudioColors.muted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
