part of '../../studio_mac_workspace.dart';

// 选中连线工具栏，负责在线路上插入节点或删除连接。
class _WorkflowSelectedEdgeToolbar extends StatelessWidget {
  const _WorkflowSelectedEdgeToolbar({
    required this.workflow,
    required this.edge,
    required this.locked,
    required this.onInsertNodes,
    required this.onRetargetSource,
    required this.onRetarget,
    required this.onDelete,
  });

  final WorkflowDefinition workflow;
  final _WorkflowSelectedEdge edge;
  final bool locked;
  final ValueChanged<WorkflowNodeType> onInsertNodes;
  final ValueChanged<String> onRetargetSource;
  final ValueChanged<String> onRetarget;
  final VoidCallback onDelete;

  // 渲染连线浮层，所有编辑动作仍回到 Runtime 校验和保存。
  @override
  Widget build(BuildContext context) {
    final retargetCandidates = _edgeRetargetCandidates(
      workflow,
      edge,
    ).toList(growable: false);
    final sourceCandidates = _edgeSourceCandidates(
      workflow,
      edge,
    ).toList(growable: false);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.94),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.46)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.route_outlined,
              size: 15,
              color: StudioColors.cyan,
            ),
            const SizedBox(width: 7),
            Text(
              _workflowEdgeDisplayLabel(workflow, edge),
              key: const ValueKey('workflow-selected-edge-label'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 8),
            SizedBox.square(
              dimension: 26,
              child: IconButton(
                key: const ValueKey('workflow-edge-insert-tap'),
                tooltip: '在连线上加点击',
                padding: EdgeInsets.zero,
                iconSize: 15,
                onPressed: locked
                    ? null
                    : () => onInsertNodes(WorkflowNodeType.tap),
                icon: const Icon(Icons.touch_app_outlined),
              ),
            ),
            SizedBox.square(
              dimension: 26,
              child: IconButton(
                key: const ValueKey('workflow-edge-insert-wait'),
                tooltip: '在连线上加等待',
                padding: EdgeInsets.zero,
                iconSize: 15,
                onPressed: locked
                    ? null
                    : () => onInsertNodes(WorkflowNodeType.wait),
                icon: const Icon(Icons.timer_outlined),
              ),
            ),
            PopupMenuButton<WorkflowNodeType>(
              key: const ValueKey('workflow-edge-insert-menu'),
              tooltip: '更多节点',
              enabled: !locked,
              icon: const Icon(Icons.add_circle_outline, size: 16),
              onSelected: onInsertNodes,
              itemBuilder: (context) => [
                for (final type in _edgeInsertMenuNodeTypes)
                  PopupMenuItem<WorkflowNodeType>(
                    value: type,
                    child: Row(
                      key: ValueKey(
                        'workflow-edge-insert-${_nodeInsertKey(type)}',
                      ),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconForNodes(type), size: 16),
                        const SizedBox(width: 8),
                        Text(_insertNodesLabel(type)),
                      ],
                    ),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              key: const ValueKey('workflow-edge-retarget-menu'),
              tooltip: '改目标',
              enabled: !locked && retargetCandidates.isNotEmpty,
              icon: const Icon(Icons.alt_route_outlined, size: 16),
              onSelected: onRetarget,
              itemBuilder: (context) => [
                for (final node in retargetCandidates)
                  PopupMenuItem<String>(
                    value: node.id,
                    child: Row(
                      key: ValueKey('workflow-edge-retarget-${node.id}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconForNodes(node.type), size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _workflowNodeDisplayLabel(workflow, node.id),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              key: const ValueKey('workflow-edge-source-menu'),
              tooltip: '改起点',
              enabled: !locked && sourceCandidates.isNotEmpty,
              icon: const Icon(Icons.call_split_outlined, size: 16),
              onSelected: onRetargetSource,
              itemBuilder: (context) => [
                for (final node in sourceCandidates)
                  PopupMenuItem<String>(
                    value: node.id,
                    child: Row(
                      key: ValueKey('workflow-edge-source-${node.id}'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconForNodes(node.type), size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _workflowNodeDisplayLabel(workflow, node.id),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox.square(
              dimension: 26,
              child: IconButton(
                key: const ValueKey('workflow-delete-selected-edge'),
                tooltip: '删除连接',
                padding: EdgeInsets.zero,
                iconSize: 15,
                onPressed: locked ? null : onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
