part of '../../studio_mac_workspace.dart';

// Workflow Inspector 外壳，负责选择态、节点详情和属性编辑区的整体组合。
class _WorkflowInspector extends StatelessWidget {
  const _WorkflowInspector({
    required this.workflow,
    required this.validation,
    required this.connectionStatus,
    required this.runStatus,
    required this.latestScreenshotAt,
    required this.executionFocus,
    required this.subWorkflows,
    required this.diagnosticsByNodeId,
    required this.selectedNode,
    required this.selectedNodes,
    required this.savingNodes,
    required this.savingGraphEdit,
    required this.onSaveNode,
    required this.onAddEdge,
    required this.onRemoveEdge,
    required this.onInsertNodes,
    required this.onDuplicateNodes,
    required this.onDeleteNodes,
    required this.onDuplicateSelectedNodes,
    required this.onDeleteSelectedNodes,
    required this.onAlignSelectedNodes,
    required this.onDistributeSelectedNodes,
    required this.onAddStarterSubWorkflow,
    required this.onAddCurrentAsSubWorkflow,
    required this.onDeleteSubWorkflow,
  });

  final WorkflowDefinition workflow;
  final WorkflowValidateResult validation;
  final ConnectionStatus connectionStatus;
  final RunStatus runStatus;
  final DateTime? latestScreenshotAt;
  final RuntimeExecutionFocus executionFocus;
  final List<SubWorkflowSummary> subWorkflows;
  final Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId;
  final WorkflowNode? selectedNode;
  final List<WorkflowNode> selectedNodes;
  final bool savingNodes;
  final bool savingGraphEdit;
  final ValueChanged<WorkflowNode> onSaveNode;
  final ValueChanged<String>? onAddEdge;
  final ValueChanged<String>? onRemoveEdge;
  final ValueChanged<WorkflowNodeType>? onInsertNodes;
  final VoidCallback? onDuplicateNodes;
  final VoidCallback? onDeleteNodes;
  final VoidCallback? onDuplicateSelectedNodes;
  final VoidCallback? onDeleteSelectedNodes;
  final ValueChanged<_WorkflowCanvasAlignment>? onAlignSelectedNodes;
  final ValueChanged<_WorkflowCanvasDistribution>? onDistributeSelectedNodes;
  final VoidCallback? onAddStarterSubWorkflow;
  final VoidCallback? onAddCurrentAsSubWorkflow;
  final ValueChanged<SubWorkflowSummary>? onDeleteSubWorkflow;

  @override
  Widget build(BuildContext context) {
    final tapCount = workflow.nodes
        .where((node) => node.type == WorkflowNodeType.tap)
        .length;
    final waitCount = workflow.nodes
        .where((node) => node.type == WorkflowNodeType.wait)
        .length;
    return _Surface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '流程检查',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            _InspectorRow(label: '真源', value: '流程文件'),
            _InspectorRow(label: '模式', value: '画布 / 源码'),
            _InspectorRow(label: '节点', value: '${workflow.nodes.length}'),
            _InspectorRow(label: '点击', value: '$tapCount'),
            _InspectorRow(label: '等待', value: '$waitCount'),
            _InspectorRow(label: '运行锁', value: _runStatusLabel(runStatus)),
            const SizedBox(height: 12),
            StatusPill(
              label: validation.isValid ? '有效' : '需检查',
              tone: validation.isValid
                  ? StudioStatusTone.ready
                  : StudioStatusTone.warning,
            ),
            const SizedBox(height: 18),
            _WorkflowContextPanel(
              connectionStatus: connectionStatus,
              runStatus: runStatus,
              latestScreenshotAt: latestScreenshotAt,
              executionFocus: executionFocus,
            ),
            const SizedBox(height: 18),
            if (selectedNode == null)
              selectedNodes.length > 1
                  ? _MultiNodeInspectorSummary(
                      workflow: workflow,
                      nodes: selectedNodes,
                      locked: runStatus != RunStatus.idle || savingGraphEdit,
                      savingGraphEdit: savingGraphEdit,
                      onDuplicateSelectedNodes: onDuplicateSelectedNodes,
                      onDeleteSelectedNodes: onDeleteSelectedNodes,
                      onAlignSelectedNodes: onAlignSelectedNodes,
                      onDistributeSelectedNodes: onDistributeSelectedNodes,
                    )
                  : const _WorkflowInspectorEmptyState()
            else
              _NodeInspectorEditor(
                workflow: workflow,
                node: selectedNode!,
                subWorkflows: subWorkflows,
                diagnostics:
                    diagnosticsByNodeId[selectedNode!.id] ??
                    const <_WorkflowSourceDiagnostic>[],
                locked: runStatus != RunStatus.idle,
                saving: savingNodes,
                savingGraphEdit: savingGraphEdit,
                onSave: onSaveNode,
                onAddEdge: onAddEdge,
                onRemoveEdge: onRemoveEdge,
                onInsertNodes: onInsertNodes,
                onDuplicateNodes: onDuplicateNodes,
                onDeleteNodes: onDeleteNodes,
                onAddStarterSubWorkflow: onAddStarterSubWorkflow,
                onAddCurrentAsSubWorkflow: onAddCurrentAsSubWorkflow,
                onDeleteSubWorkflow: onDeleteSubWorkflow,
              ),
          ],
        ),
      ),
    );
  }
}
