part of '../../studio_mac_workspace.dart';

// Workflow 节点行组件，负责单个节点卡片的状态、端口和操作按钮展示。
class _WorkflowNodeRow extends StatelessWidget {
  const _WorkflowNodeRow({
    required this.workflow,
    required this.node,
    required this.entry,
    required this.capabilityBadge,
    required this.diagnostics,
    required this.evidenceSummary,
    required this.executionState,
    required this.selected,
    required this.locked,
    required this.onSelect,
  });

  final WorkflowDefinition workflow;
  final WorkflowNode node;
  final bool entry;
  final _WorkflowNodeCapabilityBadge? capabilityBadge;
  final List<_WorkflowSourceDiagnostic> diagnostics;
  final _WorkflowNodeEvidenceSummary? evidenceSummary;
  final _WorkflowNodeExecutionState executionState;
  final bool selected;
  final bool locked;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final tone = _toneForNodes(node.type);
    final executionColor = _colorForExecutionState(executionState, tone);
    final hasDiagnostics = diagnostics.isNotEmpty;
    final evidenceSummary = this.evidenceSummary;
    final hasEvidence = evidenceSummary?.hasEvidence ?? false;
    final statusPills = <Widget>[
      if (entry) const StatusPill(label: '入口', tone: StudioStatusTone.running),
      if (hasDiagnostics)
        KeyedSubtree(
          key: ValueKey('workflow-node-issue-${node.id}'),
          child: StatusPill(
            label: '${diagnostics.length} 个问题',
            tone: StudioStatusTone.warning,
          ),
        ),
      if (evidenceSummary != null && hasEvidence)
        KeyedSubtree(
          key: ValueKey('workflow-node-evidence-${node.id}'),
          child: StatusPill(
            label: evidenceSummary.badgeLabel,
            tone: evidenceSummary.badgeTone,
          ),
        ),
      if (capabilityBadge case final _WorkflowNodeCapabilityBadge badge)
        Tooltip(
          message: badge.detail,
          child: KeyedSubtree(
            key: ValueKey('workflow-node-capability-${node.id}'),
            child: StatusPill(label: badge.label, tone: badge.tone),
          ),
        ),
      if (executionState != _WorkflowNodeExecutionState.idle)
        StatusPill(
          label: _labelForExecutionState(executionState),
          tone: _toneForExecutionState(executionState),
        ),
    ];
    return InkWell(
      key: ValueKey('workflow-node-${node.id}'),
      borderRadius: BorderRadius.circular(8),
      onTap: onSelect,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? StudioColors.cyan.withValues(alpha: 0.10)
              : _backgroundForExecutionState(executionState),
          border: Border.all(
            color: selected
                ? StudioColors.cyan.withValues(alpha: 0.52)
                : hasDiagnostics
                ? StudioColors.amber.withValues(alpha: 0.62)
                : executionState == _WorkflowNodeExecutionState.idle
                ? StudioColors.border
                : executionColor.withValues(alpha: 0.58),
            width:
                hasDiagnostics ||
                    executionState == _WorkflowNodeExecutionState.active
                ? 1.8
                : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (executionState == _WorkflowNodeExecutionState.active)
              BoxShadow(
                color: executionColor.withValues(alpha: 0.22),
                blurRadius: 18,
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _colorForTone(tone).withValues(alpha: 0.12),
                border: Border.all(
                  color: _colorForTone(tone).withValues(alpha: 0.42),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_iconForNodes(node.type), color: _colorForTone(tone)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          node.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (statusPills.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: _workflowNodePillsWithGaps(statusPills),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _nodeSummary(node),
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
            Icon(
              locked ? Icons.lock_outline : Icons.drag_indicator,
              color: StudioColors.muted,
              size: 16,
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 118,
              child: Text(
                _nodeBranchSummary(workflow, node),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: StudioColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 给节点卡片状态胶囊添加统一间距，避免每个状态组合手写条件。
List<Widget> _workflowNodePillsWithGaps(List<Widget> pills) {
  return <Widget>[
    for (var index = 0; index < pills.length; index += 1) ...[
      if (index > 0) const SizedBox(width: 8),
      pills[index],
    ],
  ];
}
