part of '../../studio_mac_workspace.dart';

// Workflow Inspector 多选摘要，负责多节点统计、批量操作入口和选中节点展示。
// 该分片只改变编辑器交互入口，不直接写 Project DSL 或触发设备动作。
class _MultiNodeInspectorSummary extends StatelessWidget {
  const _MultiNodeInspectorSummary({
    required this.workflow,
    required this.nodes,
    required this.locked,
    required this.savingGraphEdit,
    required this.onDuplicateSelectedNodes,
    required this.onDeleteSelectedNodes,
    required this.onAlignSelectedNodes,
    required this.onDistributeSelectedNodes,
  });

  final WorkflowDefinition workflow;
  final List<WorkflowNode> nodes;
  final bool locked;
  final bool savingGraphEdit;
  final VoidCallback? onDuplicateSelectedNodes;
  final VoidCallback? onDeleteSelectedNodes;
  final ValueChanged<_WorkflowCanvasAlignment>? onAlignSelectedNodes;
  final ValueChanged<_WorkflowCanvasDistribution>? onDistributeSelectedNodes;

  // 渲染多选摘要和批量操作入口，展示层只使用节点短中文标签。
  @override
  Widget build(BuildContext context) {
    final stats = _multiNodeInspectorStats(workflow: workflow, nodes: nodes);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: StudioColors.border),
        const SizedBox(height: 8),
        const Text(
          '多选',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        StatusPill(
          label: '已选 ${nodes.length} 个',
          tone: StudioStatusTone.running,
        ),
        const SizedBox(height: 12),
        _InspectorRow(label: '点击', value: '${stats.tapCount}'),
        _InspectorRow(label: '等待', value: '${stats.waitCount}'),
        _InspectorRow(label: '可复制', value: '${stats.mutableCount}'),
        _InspectorRow(label: '可删', value: '${stats.mutableCount}'),
        const SizedBox(height: 12),
        _MultiNodeInspectorActions(
          locked: locked,
          savingGraphEdit: savingGraphEdit,
          duplicableCount: stats.mutableCount,
          deletableCount: stats.mutableCount,
          onDuplicateSelectedNodes: onDuplicateSelectedNodes,
          onDeleteSelectedNodes: onDeleteSelectedNodes,
          onAlignSelectedNodes: onAlignSelectedNodes,
          onDistributeSelectedNodes: onDistributeSelectedNodes,
        ),
        const SizedBox(height: 12),
        _MultiNodeInspectorChips(workflow: workflow, nodes: nodes),
        const SizedBox(height: 12),
        const Text(
          '位置调整只影响画布布局，运行仍按流程连线执行。',
          style: TextStyle(color: StudioColors.muted, height: 1.4),
        ),
      ],
    );
  }
}
