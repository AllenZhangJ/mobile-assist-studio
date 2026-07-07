part of '../../studio_mac_workspace.dart';

// Workflow 历史动作，统一管理 DSL 更新、撤销、重做和编辑器同步。
extension _WorkflowPageHistoryActions on _WorkflowPageState {
  // 统一提交 Workflow 更新，并在成功后记录可撤销历史。
  Future<bool> _updateWorkflowWithHistory(
    WorkflowDefinition workflow, {
    bool captureHistory = true,
  }) async {
    final beforeWorkflow = widget.snapshot.workflow;
    final updated = await widget.controller.updateWorkflow(workflow);
    if (updated && mounted && captureHistory) {
      _updateWorkflowPageState(() {
        _workflowHistory.captureEdit(before: beforeWorkflow, after: workflow);
      });
    }
    return updated;
  }

  // 执行一次撤销，失败时恢复历史栈并提示用户查看控制台。
  Future<void> _undoWorkflowChange() async {
    if (!_canUndoWorkflow) return;
    final previous = _workflowHistory.takeUndoTarget();
    if (previous == null) return;
    final current = widget.snapshot.workflow;
    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final updated = await _updateWorkflowWithHistory(
      previous,
      captureHistory: false,
    );
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _workflowHistory.commitUndo(current);
        _syncWorkflowEditorAfterHistory(previous);
      } else {
        _workflowHistory.rollbackUndo(previous);
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(updated ? '已撤销。' : '撤销失败，请看控制台。')));
  }

  // 执行一次重做，失败时恢复历史栈并提示用户查看控制台。
  Future<void> _redoWorkflowChange() async {
    if (!_canRedoWorkflow) return;
    final next = _workflowHistory.takeRedoTarget();
    if (next == null) return;
    final current = widget.snapshot.workflow;
    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final updated = await _updateWorkflowWithHistory(
      next,
      captureHistory: false,
    );
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _workflowHistory.commitRedo(current);
        _syncWorkflowEditorAfterHistory(next);
      } else {
        _workflowHistory.rollbackRedo(next);
      }
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(updated ? '已重做。' : '重做失败，请看控制台。')));
  }

  // 历史切换后同步源码、选区和当前页签，避免 UI 留在旧节点上。
  void _syncWorkflowEditorAfterHistory(WorkflowDefinition workflow) {
    _selectedEdge = null;
    _selectedNodeId = null;
    _selectedNodeIds = const <String>{};
    _selectedTab = _WorkflowTab.visual;
    _lastSyncedSource = _workflowSourceText(workflow);
    _sourceController.text = _lastSyncedSource;
    _sourceDirty = false;
  }
}
