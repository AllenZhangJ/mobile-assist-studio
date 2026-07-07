part of '../../studio_mac_workspace.dart';

// Workflow 画布概览条，负责把当前 DSL 转成可扫读的画布摘要。
// 它是只读 UI，不保存流程、不触发 Runtime，也不展示内部节点 ID。

// 画布概览条组件，展示节点、连线、问题和选区摘要。
class _WorkflowCanvasOverview extends StatelessWidget {
  const _WorkflowCanvasOverview({required this.model});

  final _WorkflowCanvasOverviewModel model;

  // 渲染底部只读摘要，保持短中文和稳定高度。
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: '画布概览',
        child: DecoratedBox(
          key: const ValueKey('workflow-canvas-overview'),
          decoration: BoxDecoration(
            color: StudioColors.panel.withValues(alpha: 0.90),
            border: Border.all(color: StudioColors.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _WorkflowCanvasOverviewChip(
                    icon: Icons.account_tree_outlined,
                    label: '节点 ${model.nodeCount}',
                    tone: StudioStatusTone.running,
                  ),
                  _WorkflowCanvasOverviewChip(
                    icon: Icons.route_outlined,
                    label: '连线 ${model.edgeCount}',
                    tone: StudioStatusTone.ready,
                  ),
                  _WorkflowCanvasOverviewChip(
                    icon: model.issueCount > 0
                        ? Icons.warning_amber_outlined
                        : Icons.verified_outlined,
                    label: '问题 ${model.issueCount}',
                    tone: model.issueTone,
                  ),
                  _WorkflowCanvasOverviewChip(
                    icon: model.hasSelection
                        ? Icons.ads_click_outlined
                        : Icons.crop_free_outlined,
                    label: '选区 ${model.selectionLabel}',
                    tone: model.selectionTone,
                    maxWidth: 240,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 画布概览条状态模型，集中维护从 workflow 派生的只读摘要。
final class _WorkflowCanvasOverviewModel {
  // 创建概览条模型，调用方传入已计算的展示字段。
  const _WorkflowCanvasOverviewModel({
    required this.nodeCount,
    required this.edgeCount,
    required this.issueCount,
    required this.issueTone,
    required this.selectionLabel,
    required this.selectionTone,
    required this.hasSelection,
  });

  final int nodeCount;
  final int edgeCount;
  final int issueCount;
  final StudioStatusTone issueTone;
  final String selectionLabel;
  final StudioStatusTone selectionTone;
  final bool hasSelection;

  // 从 Project DSL 和当前画布状态派生概览，不读取设备或运行时会话。
  factory _WorkflowCanvasOverviewModel.fromWorkflow({
    required WorkflowDefinition workflow,
    required Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId,
    required String? selectedNodeId,
    required Set<String> selectedNodeIds,
    required _WorkflowSelectedEdge? selectedEdge,
  }) {
    final issueCount = diagnosticsByNodeId.values.fold<int>(
      0,
      (total, diagnostics) => total + diagnostics.length,
    );
    final selection = _workflowOverviewSelectionLabel(
      workflow: workflow,
      selectedNodeId: selectedNodeId,
      selectedNodeIds: selectedNodeIds,
      selectedEdge: selectedEdge,
    );
    final hasSelection = selection != '未选择';
    return _WorkflowCanvasOverviewModel(
      nodeCount: workflow.nodes.length,
      edgeCount: _workflowGraphEdges(workflow).length,
      issueCount: issueCount,
      issueTone: issueCount > 0
          ? StudioStatusTone.warning
          : StudioStatusTone.ready,
      selectionLabel: selection,
      selectionTone: hasSelection
          ? StudioStatusTone.running
          : StudioStatusTone.offline,
      hasSelection: hasSelection,
    );
  }
}

// 画布概览条内的单个短标签。
class _WorkflowCanvasOverviewChip extends StatelessWidget {
  const _WorkflowCanvasOverviewChip({
    required this.icon,
    required this.label,
    required this.tone,
    this.maxWidth,
  });

  final IconData icon;
  final String label;
  final StudioStatusTone tone;
  final double? maxWidth;

  // 渲染紧凑指标，超长选区会省略，避免遮挡画布。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 120),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.30)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// 返回当前画布选区的短中文摘要。
String _workflowOverviewSelectionLabel({
  required WorkflowDefinition workflow,
  required String? selectedNodeId,
  required Set<String> selectedNodeIds,
  required _WorkflowSelectedEdge? selectedEdge,
}) {
  if (selectedEdge != null) {
    return _workflowOverviewEdgeLabel(workflow, selectedEdge);
  }
  final selectedCount = selectedNodeIds
      .where((nodeId) => _workflowContainsNodes(workflow, nodeId))
      .length;
  if (selectedCount > 1) return '$selectedCount 个节点';
  final selectedNode = _workflowOverviewSelectedNode(
    workflow,
    selectedNodeId,
    selectedNodeIds,
  );
  if (selectedNode != null) return selectedNode.label;
  return '未选择';
}

// 返回当前选中节点，多选时按 workflow 顺序取第一个展示。
WorkflowNode? _workflowOverviewSelectedNode(
  WorkflowDefinition workflow,
  String? selectedNodeId,
  Set<String> selectedNodeIds,
) {
  final direct = _selectedNode(workflow, selectedNodeId);
  if (direct != null) return direct;
  return workflow.nodes
      .where((node) => selectedNodeIds.contains(node.id))
      .firstOrNull;
}

// 返回选中连线的短中文摘要，不暴露内部节点 ID。
String _workflowOverviewEdgeLabel(
  WorkflowDefinition workflow,
  _WorkflowSelectedEdge edge,
) {
  final from = _nodeLabelById(workflow, edge.fromNodeId);
  final to = _nodeLabelById(workflow, edge.toNodeId);
  if (from == null || to == null) return '已选连线';
  final role = _workflowEdgeRoleLabel(
    workflow,
    fromNodeId: edge.fromNodeId,
    toNodeId: edge.toNodeId,
    kind: edge.kind,
  );
  final path = '$from → $to';
  return role == null ? path : '$role：$path';
}
