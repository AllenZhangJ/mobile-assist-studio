part of '../../studio_mac_workspace.dart';

// 多选节点标签列表，只展示用户可读节点名，不暴露内部节点 ID。
class _MultiNodeInspectorChips extends StatelessWidget {
  const _MultiNodeInspectorChips({required this.workflow, required this.nodes});

  final WorkflowDefinition workflow;
  final List<WorkflowNode> nodes;

  // 渲染当前选中节点集合，用于快速确认批量操作范围。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final node in nodes)
          Chip(
            key: ValueKey('multi-selected-node-${node.id}'),
            label: Text(
              _workflowNodeDisplayLabel(workflow, node.id),
              overflow: TextOverflow.ellipsis,
            ),
            avatar: Icon(_iconForNodes(node.type), size: 16),
          ),
      ],
    );
  }
}
