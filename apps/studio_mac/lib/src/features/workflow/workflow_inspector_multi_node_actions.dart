part of '../../studio_mac_workspace.dart';

// 多选批量操作按钮组，集中处理禁用态和保存中文案。
class _MultiNodeInspectorActions extends StatelessWidget {
  const _MultiNodeInspectorActions({
    required this.locked,
    required this.savingGraphEdit,
    required this.duplicableCount,
    required this.deletableCount,
    required this.onDuplicateSelectedNodes,
    required this.onDeleteSelectedNodes,
    required this.onAlignSelectedNodes,
    required this.onDistributeSelectedNodes,
  });

  final bool locked;
  final bool savingGraphEdit;
  final int duplicableCount;
  final int deletableCount;
  final VoidCallback? onDuplicateSelectedNodes;
  final VoidCallback? onDeleteSelectedNodes;
  final ValueChanged<_WorkflowCanvasAlignment>? onAlignSelectedNodes;
  final ValueChanged<_WorkflowCanvasDistribution>? onDistributeSelectedNodes;

  // 渲染批量复制、删除、对齐和均分按钮，所有真实写入仍由页面动作分片处理。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          key: const ValueKey('multi-node-duplicate-selected'),
          onPressed: locked || duplicableCount == 0
              ? null
              : onDuplicateSelectedNodes,
          icon: Icon(
            savingGraphEdit ? Icons.hourglass_top : Icons.copy_all_outlined,
            size: 18,
          ),
          label: Text(
            savingGraphEdit ? '复制中...' : '复制所选',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('multi-node-delete-selected'),
          onPressed: locked || deletableCount == 0
              ? null
              : onDeleteSelectedNodes,
          icon: Icon(
            savingGraphEdit ? Icons.hourglass_top : Icons.delete_sweep_outlined,
            size: 18,
          ),
          label: Text(
            savingGraphEdit ? '删除中...' : '删除所选',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _MultiNodeAlignButton(
          buttonKey: const ValueKey('multi-node-align-left'),
          locked: locked,
          savingGraphEdit: savingGraphEdit,
          label: '左齐',
          icon: Icons.align_horizontal_left_outlined,
          onPressed: onAlignSelectedNodes == null
              ? null
              : () => onAlignSelectedNodes?.call(_WorkflowCanvasAlignment.left),
        ),
        _MultiNodeAlignButton(
          buttonKey: const ValueKey('multi-node-align-right'),
          locked: locked,
          savingGraphEdit: savingGraphEdit,
          label: '右齐',
          icon: Icons.align_horizontal_right_outlined,
          onPressed: onAlignSelectedNodes == null
              ? null
              : () =>
                    onAlignSelectedNodes?.call(_WorkflowCanvasAlignment.right),
        ),
        _MultiNodeAlignButton(
          buttonKey: const ValueKey('multi-node-align-top'),
          locked: locked,
          savingGraphEdit: savingGraphEdit,
          label: '顶齐',
          icon: Icons.align_vertical_top_outlined,
          onPressed: onAlignSelectedNodes == null
              ? null
              : () => onAlignSelectedNodes?.call(_WorkflowCanvasAlignment.top),
        ),
        _MultiNodeAlignButton(
          buttonKey: const ValueKey('multi-node-align-bottom'),
          locked: locked,
          savingGraphEdit: savingGraphEdit,
          label: '底齐',
          icon: Icons.align_vertical_bottom_outlined,
          onPressed: onAlignSelectedNodes == null
              ? null
              : () =>
                    onAlignSelectedNodes?.call(_WorkflowCanvasAlignment.bottom),
        ),
        _MultiNodeAlignButton(
          buttonKey: const ValueKey('multi-node-distribute-horizontal'),
          locked: locked,
          savingGraphEdit: savingGraphEdit,
          label: '横向均分',
          icon: Icons.swap_horiz,
          onPressed: onDistributeSelectedNodes == null
              ? null
              : () => onDistributeSelectedNodes?.call(
                  _WorkflowCanvasDistribution.horizontal,
                ),
        ),
        _MultiNodeAlignButton(
          buttonKey: const ValueKey('multi-node-distribute-vertical'),
          locked: locked,
          savingGraphEdit: savingGraphEdit,
          label: '纵向均分',
          icon: Icons.swap_vert,
          onPressed: onDistributeSelectedNodes == null
              ? null
              : () => onDistributeSelectedNodes?.call(
                  _WorkflowCanvasDistribution.vertical,
                ),
        ),
      ],
    );
  }
}
