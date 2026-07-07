part of '../../studio_mac_workspace.dart';

// Workflow 节点插入动作，负责 Inspector、画布菜单和节点库的新增入口。
extension _WorkflowPageNodeInsertActions on _WorkflowPageState {
  // 从 Inspector 在当前节点后插入新节点，结束节点后不允许插入。
  Future<void> _insertNodesAfterSelected(WorkflowNodeType type) async {
    final selectedNodeId = _selectedNodeId;
    if (_savingGraphEdit || selectedNodeId == null) return;
    final workflow = widget.snapshot.workflow;
    final selectedNodes = _selectedNode(workflow, selectedNodeId);
    if (selectedNodes == null || selectedNodes.type == WorkflowNodeType.end) {
      return;
    }

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final insertedNodes = _newNodesForInsert(workflow, type);
    final updatedWorkflow = _workflowInsertingNodesAfter(
      workflow,
      anchorNodeId: selectedNodeId,
      insertedNodes: insertedNodes,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) _selectedNodeId = insertedNodes.id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '节点已插入。' : '节点未插入，请看控制台。')),
    );
  }

  // 从画布菜单插入节点，优先接到当前选中节点，否则接到入口节点。
  Future<void> _insertNodesFromCanvasMenu(WorkflowNodeType type) async {
    if (_workflowGraphEditLocked) return;
    final workflow = widget.snapshot.workflow;
    final selectedNodes = _selectedNode(workflow, _selectedNodeId);
    final anchorNodeId =
        selectedNodes != null && selectedNodes.type != WorkflowNodeType.end
        ? selectedNodes.id
        : workflow.entryNodesId;
    final anchorNodes = _selectedNode(workflow, anchorNodeId);
    if (anchorNodes == null || anchorNodes.type == WorkflowNodeType.end) {
      return;
    }

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final insertedNodes = _newNodesForInsert(workflow, type);
    final updatedWorkflow = _workflowInsertingNodesAfter(
      workflow,
      anchorNodeId: anchorNodeId,
      insertedNodes: insertedNodes,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _selectedEdge = null;
        _selectedNodeId = insertedNodes.id;
        _selectedNodeIds = {insertedNodes.id};
        _selectedTab = _WorkflowTab.visual;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '节点已添加。' : '节点未添加，请看控制台。')),
    );
  }
}
