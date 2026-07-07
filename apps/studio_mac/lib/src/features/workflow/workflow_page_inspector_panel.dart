part of '../../studio_mac_workspace.dart';

// Workflow 右侧 Inspector 装配，负责把当前选择态映射到 Inspector。
extension _WorkflowPageInspectorPanel on _WorkflowPageState {
  /// 构建 Workflow 右侧 Inspector。
  /// Inspector 只消费当前选择态，保存动作继续走 Runtime validator。
  Widget _buildWorkflowInspectorPanel({
    required WorkflowDefinition workflow,
    required WorkflowValidateResult validation,
    required Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId,
    required WorkflowNode? selectedNode,
    required List<WorkflowNode> selectedNodes,
  }) {
    return Expanded(
      flex: 2,
      child: _WorkflowInspector(
        workflow: workflow,
        validation: validation,
        connectionStatus: widget.snapshot.connectionStatus,
        runStatus: widget.snapshot.runStatus,
        latestScreenshotAt: widget.snapshot.latestScreenshotAt,
        executionFocus: widget.snapshot.executionFocus,
        subWorkflows: widget.snapshot.subWorkflows,
        diagnosticsByNodeId: diagnosticsByNodeId,
        selectedNode: selectedNode,
        selectedNodes: selectedNodes,
        savingNodes: _savingNodes,
        savingGraphEdit: _savingGraphEdit,
        onSaveNode: (node) => unawaited(_saveNodesDraft(node)),
        onAddEdge: selectedNode == null
            ? null
            : (targetNodesId) => unawaited(_addEdgeFromSelected(targetNodesId)),
        onRemoveEdge: selectedNode == null
            ? null
            : (targetNodesId) =>
                  unawaited(_removeEdgeFromSelected(targetNodesId)),
        onInsertNodes: selectedNode == null
            ? null
            : (type) => unawaited(_insertNodesAfterSelected(type)),
        onDuplicateNodes: selectedNode == null
            ? null
            : () => unawaited(_duplicateSelectedNode()),
        onDeleteNodes: selectedNode == null
            ? null
            : () => unawaited(_deleteSelectedNode()),
        onDuplicateSelectedNodes: selectedNodes.length > 1
            ? () => unawaited(_duplicateSelectedNodes())
            : null,
        onDeleteSelectedNodes: selectedNodes.length > 1
            ? () => unawaited(_deleteSelectedNodes())
            : null,
        onAlignSelectedNodes: selectedNodes.length > 1
            ? _alignWorkflowCanvasSelection
            : null,
        onDistributeSelectedNodes: selectedNodes.length > 2
            ? _distributeWorkflowCanvasSelection
            : null,
        onAddStarterSubWorkflow: () => unawaited(_registerStarterSubWorkflow()),
        onAddCurrentAsSubWorkflow: () =>
            unawaited(_registerCurrentWorkflowAsSubWorkflow()),
        onDeleteSubWorkflow: (summary) =>
            unawaited(_confirmDeleteSubWorkflow(summary)),
      ),
    );
  }
}
