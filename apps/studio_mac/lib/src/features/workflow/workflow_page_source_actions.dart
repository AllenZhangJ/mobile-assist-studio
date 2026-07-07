part of '../../studio_mac_workspace.dart';

// Workflow Source 动作，负责源码草稿、源码保存和节点草稿保存。
extension _WorkflowPageSourceActions on _WorkflowPageState {
  // 放弃 Source 草稿，回到最近一次 Runtime 快照中的 DSL。
  void _resetSourceDraft() {
    _updateWorkflowPageState(() {
      _sourceController.text = _lastSyncedSource;
      _sourceDirty = false;
    });
  }

  // 保存 Source 页签解析出的 DSL，成功后清理草稿态。
  Future<void> _saveSourceDraft(WorkflowDefinition workflow) async {
    if (_savingSource) return;
    _updateWorkflowPageState(() => _savingSource = true);
    final updated = await _updateWorkflowWithHistory(workflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingSource = false;
      if (updated) {
        _lastSyncedSource = _workflowSourceText(workflow);
        _sourceController.text = _lastSyncedSource;
        _sourceDirty = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '源码已保存。' : '源码未保存，请看控制台。')),
    );
  }

  // 保存 Inspector 中编辑的单个节点，并让 workflow 历史可撤销。
  Future<void> _saveNodesDraft(WorkflowNode node) async {
    if (_savingNodes) return;
    _updateWorkflowPageState(() => _savingNodes = true);
    final updatedWorkflow = _workflowReplacingNodes(
      widget.snapshot.workflow,
      node,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() => _savingNodes = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '节点已保存。' : '节点未保存，请看控制台。')),
    );
  }
}
