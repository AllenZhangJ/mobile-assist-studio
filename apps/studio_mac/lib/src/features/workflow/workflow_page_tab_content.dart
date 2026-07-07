part of '../../studio_mac_workspace.dart';

// Workflow Tab 内容装配，负责画布、源码和检查的页面切换。
extension _WorkflowPageTabContent on _WorkflowPageState {
  /// 构建当前 Workflow Tab 内容。
  /// 画布、源码和检查共用同一 Project DSL 真源。
  Widget _buildWorkflowTabContent({
    required WorkflowDefinition workflow,
    required WorkflowValidateResult validation,
    required _WorkflowSourceDraft draft,
    required Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId,
    required WorkflowNode? selectedNode,
    required bool graphLocked,
    required String? graphLockReason,
  }) {
    return switch (_selectedTab) {
      _WorkflowTab.visual => _buildWorkflowVisualTab(
        workflow: workflow,
        diagnosticsByNodeId: diagnosticsByNodeId,
        selectedNode: selectedNode,
        graphLocked: graphLocked,
        graphLockReason: graphLockReason,
      ),
      _WorkflowTab.source => _WorkflowSourceView(
        controller: _sourceController,
        draft: draft,
        dirty: _sourceDirty,
        saving: _savingSource,
        locked: widget.snapshot.runStatus != RunStatus.idle,
        onReset: _resetSourceDraft,
        onSave: draft.workflow == null
            ? null
            : () => unawaited(_saveSourceDraft(draft.workflow!)),
      ),
      _WorkflowTab.validate => _WorkflowValidateView(
        workflow: workflow,
        validation: validation,
        onSelectDiagnostic: _openWorkflowValidateDiagnostic,
      ),
    };
  }

  /// 构建 Workflow 画布 Tab。
  /// 选择态和图编辑命令仍由页面动作分片统一收口。
  Widget _buildWorkflowVisualTab({
    required WorkflowDefinition workflow,
    required Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId,
    required WorkflowNode? selectedNode,
    required bool graphLocked,
    required String? graphLockReason,
  }) {
    return _WorkflowVisualTab(
      workflow: workflow,
      targetLibrary: widget.snapshot.targetLibrary,
      connectionStatus: widget.snapshot.connectionStatus,
      mobileRuntime: widget.snapshot.mobileRuntime,
      settings: widget.snapshot.settings,
      diagnosticsByNodeId: diagnosticsByNodeId,
      nodeEvidenceByNodeId: _latestNodeEvidenceByNodeId,
      executionFocus: widget.snapshot.executionFocus,
      selectedNode: selectedNode,
      selectedNodeId: _selectedNodeId,
      selectedNodeIds: _selectedNodeIds,
      selectedEdge: _selectedEdge,
      locked: graphLocked,
      lockReason: graphLockReason,
      canvasFocusNode: _workflowCanvasFocusNode,
      viewportCommand: _workflowCanvasViewportCommand,
      onDeleteSelection: _deleteWorkflowCanvasSelection,
      onDuplicateSelection: _duplicateWorkflowCanvasSelection,
      onCopySelection: _copyWorkflowCanvasSelection,
      onCutSelection: _cutWorkflowCanvasSelection,
      onPasteSelection: _pasteWorkflowCanvasSelection,
      onUndoChange: _undoWorkflowCanvasChange,
      onRedoChange: _redoWorkflowCanvasChange,
      onSelectAllNodes: _selectAllWorkflowCanvasNodes,
      onClearSelection: _clearWorkflowCanvasSelection,
      onAutoLayoutShortcut: _autoLayoutWorkflowCanvasShortcut,
      onNudgeSelection: _nudgeWorkflowCanvasSelection,
      onAddNodes: (type) => unawaited(_insertNodesFromCanvasMenu(type)),
      onSelectNode: _selectSingleWorkflowNodeFromCanvas,
      onSelectNodes: _selectWorkflowNodesFromCanvas,
      onSelectEdge: _selectWorkflowEdgeFromCanvas,
      onInsertNodesOnEdge: (type) =>
          unawaited(_insertNodesOnSelectedEdge(type)),
      onRetargetSelectedEdgeSource: (sourceNodesId) =>
          unawaited(_retargetSelectedEdgeSource(sourceNodesId)),
      onRetargetSelectedEdge: (targetNodesId) =>
          unawaited(_retargetSelectedEdge(targetNodesId)),
      onMoveNode: (node, position) =>
          unawaited(_moveWorkflowNode(node, position)),
      onMoveNodes: (positionsByNodeId) =>
          unawaited(_moveWorkflowNodes(positionsByNodeId)),
      onConnectNodes: (fromNodeId, toNodeId) =>
          unawaited(_addEdge(fromNodeId, toNodeId)),
      onRemoveEdge: (edge) => unawaited(_removeEdge(edge)),
      onAutoLayout: () => unawaited(_autoLayoutWorkflowCanvas()),
    );
  }
}
