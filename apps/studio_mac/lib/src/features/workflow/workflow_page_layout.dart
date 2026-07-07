part of '../../studio_mac_workspace.dart';

// Workflow 页面主面板布局，承载页头、Tab 和当前内容区装配。
extension _WorkflowPageLayout on _WorkflowPageState {
  /// 构建 Workflow 左侧主面板。
  /// 这里只装配 Toolbar、Tab 和当前视图，不直接实现图编辑语义。
  Widget _buildWorkflowMainPanel({
    required BuildContext context,
    required WorkflowDefinition workflow,
    required WorkflowValidateResult validation,
    required _WorkflowSourceDraft draft,
    required Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId,
    required WorkflowNode? selectedNode,
    required bool graphLocked,
    required String? graphLockReason,
    required bool canEditGraph,
    required bool canOpenExecute,
    required String openExecuteTooltip,
  }) {
    return Expanded(
      flex: 5,
      child: _Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWorkflowToolbar(
              context: context,
              workflow: workflow,
              validation: validation,
              canEditGraph: canEditGraph,
              canOpenExecute: canOpenExecute,
              openExecuteTooltip: openExecuteTooltip,
            ),
            const SizedBox(height: 14),
            _WorkflowTabStrip(
              selectedTab: _selectedTab,
              onSelectTab: (tab) =>
                  _updateWorkflowPageState(() => _selectedTab = tab),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _buildWorkflowTabContent(
                workflow: workflow,
                validation: validation,
                draft: draft,
                diagnosticsByNodeId: diagnosticsByNodeId,
                selectedNode: selectedNode,
                graphLocked: graphLocked,
                graphLockReason: graphLockReason,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建 Workflow 页头工具栏。
  /// 工具栏只转发页面级命令，不直接写 Project DSL。
  Widget _buildWorkflowToolbar({
    required BuildContext context,
    required WorkflowDefinition workflow,
    required WorkflowValidateResult validation,
    required bool canEditGraph,
    required bool canOpenExecute,
    required String openExecuteTooltip,
  }) {
    return _WorkflowPageToolbar(
      workflow: workflow,
      validation: validation,
      canUndo: _canUndoWorkflow,
      canRedo: _canRedoWorkflow,
      canEditGraph: canEditGraph,
      canOpenExecute: canOpenExecute,
      openExecuteTooltip: openExecuteTooltip,
      onUndo: () => unawaited(_undoWorkflowChange()),
      onRedo: () => unawaited(_redoWorkflowChange()),
      onAddNode: (type) => unawaited(_insertNodesFromCanvasMenu(type)),
      onOpenTemplates: _openWorkflowTemplateDrawer,
      onCopySource: () => unawaited(
        _copyPlainText(context, text: _workflowSourceText(workflow)),
      ),
      onOpenExecute: () => widget.onNavigate(4),
    );
  }
}
