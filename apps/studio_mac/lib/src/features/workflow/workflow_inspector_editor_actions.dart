part of '../../studio_mac_workspace.dart';

// 节点连接编辑分片，负责展示、删除和新增 next 连接。
class _NodeInspectorConnections extends StatelessWidget {
  const _NodeInspectorConnections({
    required this.workflow,
    required this.node,
    required this.edgeTargets,
    required this.edgeTargetId,
    required this.canAddEdge,
    required this.canRemoveEdge,
    required this.onEdgeTargetChanged,
    required this.onAddEdge,
    required this.onRemoveEdge,
  });

  final WorkflowDefinition workflow;
  final WorkflowNode node;
  final List<WorkflowNode> edgeTargets;
  final String? edgeTargetId;
  final bool canAddEdge;
  final bool canRemoveEdge;
  final ValueChanged<String?> onEdgeTargetChanged;
  final ValueChanged<String>? onAddEdge;
  final ValueChanged<String>? onRemoveEdge;

  // 渲染连接区，所有变更仍通过页面动作写回 Project DSL。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: StudioColors.border),
        const SizedBox(height: 8),
        const Text(
          '连接',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        if (node.next.isEmpty)
          const Text(
            '无后续连接。',
            style: TextStyle(color: StudioColors.muted, fontSize: 12),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final nextId in node.next)
                _EdgePill(
                  key: ValueKey('node-edge-remove-$nextId'),
                  label: _workflowNodeDisplayLabel(workflow, nextId),
                  removeButtonKey: ValueKey('node-edge-remove-button-$nextId'),
                  onRemove: canRemoveEdge
                      ? () => onRemoveEdge?.call(nextId)
                      : null,
                ),
            ],
          ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: const ValueKey('node-inspector-edge-target'),
          initialValue: edgeTargetId,
          isExpanded: true,
          items: [
            for (final node in edgeTargets)
              DropdownMenuItem<String>(
                value: node.id,
                child: Text(
                  _nodeInspectorTargetLabel(node),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: canAddEdge ? onEdgeTargetChanged : null,
          decoration: _inspectorInputDecoration('连接到'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            key: const ValueKey('node-inspector-add-edge'),
            onPressed: canAddEdge && edgeTargetId != null
                ? () => onAddEdge?.call(edgeTargetId!)
                : null,
            icon: const Icon(Icons.add_link_outlined, size: 18),
            label: const Text('加连接'),
          ),
        ),
      ],
    );
  }
}

// 返回 Inspector 连接候选的短中文标签，隐藏内部节点 ID。
String _nodeInspectorTargetLabel(WorkflowNode node) {
  return '${node.label} · ${_nodePaletteLabel(node.type)}';
}

// 节点画布动作分片，负责插入、复制和删除入口。
class _NodeInspectorCanvasActions extends StatelessWidget {
  const _NodeInspectorCanvasActions({
    required this.canInsert,
    required this.canDuplicate,
    required this.canDelete,
    required this.onInsertNodes,
    required this.onDuplicateNodes,
    required this.onDeleteNodes,
  });

  final bool canInsert;
  final bool canDuplicate;
  final bool canDelete;
  final ValueChanged<WorkflowNodeType>? onInsertNodes;
  final VoidCallback? onDuplicateNodes;
  final VoidCallback? onDeleteNodes;

  // 渲染节点级画布操作，动作本身仍由 Workflow 页面统一保存。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: StudioColors.border),
        const SizedBox(height: 8),
        const Text(
          '画布操作',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in _insertableNodeTypes)
              OutlinedButton.icon(
                key: ValueKey('node-inspector-insert-${_nodeInsertKey(type)}'),
                onPressed: canInsert && onInsertNodes != null
                    ? () => onInsertNodes!(type)
                    : null,
                icon: Icon(_iconForNodes(type), size: 18),
                label: Text(_insertNodesLabel(type)),
              ),
            OutlinedButton.icon(
              key: const ValueKey('node-inspector-duplicate-node'),
              onPressed: canDuplicate ? onDuplicateNodes : null,
              icon: const Icon(Icons.copy_outlined, size: 18),
              label: const Text('复制'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('node-inspector-delete-node'),
              onPressed: canDelete ? onDeleteNodes : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('删除'),
            ),
          ],
        ),
      ],
    );
  }
}

// 草稿状态分片，用短状态告诉用户是否可保存。
class _NodeInspectorDraftStatus extends StatelessWidget {
  const _NodeInspectorDraftStatus({required this.locked, required this.error});

  final bool locked;
  final String? error;

  // 渲染草稿校验状态，避免主编辑器直接堆叠状态 UI。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(
          label: error == null ? '草稿就绪' : '草稿提醒',
          tone: error == null
              ? StudioStatusTone.ready
              : StudioStatusTone.warning,
        ),
        const SizedBox(height: 8),
        Text(
          locked ? '运行中已锁定。' : error ?? '可保存节点基础信息。',
          style: const TextStyle(color: StudioColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
