part of '../../studio_mac_workspace.dart';

// Workflow 节点库组件，负责把可插入节点以分组按钮形式呈现给画布。
class _WorkflowNodePalette extends StatelessWidget {
  const _WorkflowNodePalette({
    required this.selectedNodes,
    required this.entryNodesId,
    required this.locked,
    required this.onAddNodes,
  });

  final WorkflowNode? selectedNodes;
  final String entryNodesId;
  final bool locked;
  final ValueChanged<WorkflowNodeType> onAddNodes;

  @override
  Widget build(BuildContext context) {
    final anchorLabel =
        selectedNodes != null && selectedNodes!.type != WorkflowNodeType.end
        ? selectedNodes!.label
        : '入口';
    return DecoratedBox(
      key: const ValueKey('workflow-node-palette'),
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.widgets_outlined, size: 17),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '节点库',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(
                  label: locked ? '锁定' : '就绪',
                  tone: locked
                      ? StudioStatusTone.offline
                      : StudioStatusTone.ready,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '在 $anchorLabel 后',
              key: const ValueKey('workflow-node-palette-anchor'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                key: const ValueKey('workflow-node-palette-list'),
                children: [
                  _WorkflowNodePaletteSection(
                    title: '操作',
                    types: const [
                      WorkflowNodeType.tap,
                      WorkflowNodeType.wait,
                      WorkflowNodeType.swipe,
                      WorkflowNodeType.input,
                      WorkflowNodeType.snapshot,
                    ],
                    locked: locked,
                    onAddNodes: onAddNodes,
                  ),
                  const SizedBox(height: 12),
                  _WorkflowNodePaletteSection(
                    title: '逻辑',
                    types: const [
                      WorkflowNodeType.loop,
                      WorkflowNodeType.condition,
                      WorkflowNodeType.visualBranch,
                      WorkflowNodeType.waitForTarget,
                    ],
                    locked: locked,
                    onAddNodes: onAddNodes,
                  ),
                  const SizedBox(height: 12),
                  _WorkflowNodePaletteSection(
                    title: '恢复',
                    types: const [
                      WorkflowNodeType.catchNodes,
                      WorkflowNodeType.subWorkflow,
                    ],
                    locked: locked,
                    onAddNodes: onAddNodes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              locked ? '当前状态下画布已锁定。' : '已通过流程校验保存。',
              style: const TextStyle(
                color: StudioColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowNodePaletteSection extends StatelessWidget {
  const _WorkflowNodePaletteSection({
    required this.title,
    required this.types,
    required this.locked,
    required this.onAddNodes,
  });

  final String title;
  final List<WorkflowNodeType> types;
  final bool locked;
  final ValueChanged<WorkflowNodeType> onAddNodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: StudioColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        for (final type in types) ...[
          _WorkflowNodePaletteButton(
            type: type,
            locked: locked,
            onPressed: () => onAddNodes(type),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _WorkflowNodePaletteButton extends StatelessWidget {
  const _WorkflowNodePaletteButton({
    required this.type,
    required this.locked,
    required this.onPressed,
  });

  final WorkflowNodeType type;
  final bool locked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        key: ValueKey('workflow-palette-node-${_nodeInsertKey(type)}'),
        onPressed: locked ? null : onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_iconForNodes(type), size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _nodePaletteLabel(type),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _nodePaletteDescription(type),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudioColors.muted,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
