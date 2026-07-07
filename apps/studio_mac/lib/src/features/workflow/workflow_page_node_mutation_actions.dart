part of '../../studio_mac_workspace.dart';

// Workflow 节点复制删除动作，统一处理单选和多选的结构性变更。
extension _WorkflowPageNodeMutationActions on _WorkflowPageState {
  // 复制单个可复制节点，并把选区切到新节点。
  Future<void> _duplicateSelectedNode() async {
    final selectedNodeId = _selectedNodeId;
    if (_workflowGraphEditLocked || selectedNodeId == null) return;
    final workflow = widget.snapshot.workflow;
    final selectedNodes = _selectedNode(workflow, selectedNodeId);
    if (selectedNodes == null ||
        !_workflowNodesCanDuplicate(selectedNodes, workflow)) {
      return;
    }

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final duplicatedNodes = _duplicatedNodesForInsert(workflow, selectedNodes);
    final updatedWorkflow = _workflowInsertingNodesAfter(
      workflow,
      anchorNodeId: selectedNodeId,
      insertedNodes: duplicatedNodes,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _selectedNodeId = duplicatedNodes.id;
        _selectedNodeIds = {duplicatedNodes.id};
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '节点已复制。' : '节点未复制，请看控制台。')),
    );
  }

  // 删除单个可删除节点，Start 和 End 由 helper 保护。
  Future<void> _deleteSelectedNode() async {
    final selectedNodeId = _selectedNodeId;
    if (_workflowGraphEditLocked || selectedNodeId == null) return;
    final workflow = widget.snapshot.workflow;
    final selectedNodes = _selectedNode(workflow, selectedNodeId);
    if (selectedNodes == null ||
        !_workflowNodesCanDuplicate(selectedNodes, workflow)) {
      return;
    }

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final updatedWorkflow = _workflowDeletingNodes(workflow, selectedNodeId);
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _selectedNodeId = null;
        _selectedNodeIds = const <String>{};
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '节点已删除。' : '节点未删除，请看控制台。')),
    );
  }

  // 复制多选节点集合，并保持新节点为当前选区。
  Future<void> _duplicateSelectedNodes() async {
    if (_workflowGraphEditLocked) return;
    final workflow = widget.snapshot.workflow;
    final copyableIds = workflow.nodes
        .where(
          (node) =>
              _selectedNodeIds.contains(node.id) &&
              _workflowNodesCanDuplicate(node, workflow),
        )
        .map((node) => node.id)
        .toList(growable: false);
    if (copyableIds.isEmpty) return;

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final result = _workflowDuplicatingNodes(workflow, copyableIds);
    final updated = await _updateWorkflowWithHistory(result.workflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _selectedEdge = null;
        _selectedNodeIds = result.duplicatedNodeIds;
        _selectedNodeId = result.duplicatedNodeIds.length == 1
            ? result.duplicatedNodeIds.single
            : null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated
              ? '已复制 ${result.duplicatedNodeIds.length} 个节点。'
              : '所选未复制，请看控制台。',
        ),
      ),
    );
  }

  // 删除多选节点集合，逐个套用图删除规则以保持连线可恢复。
  Future<void> _deleteSelectedNodes() async {
    if (_workflowGraphEditLocked) return;
    final workflow = widget.snapshot.workflow;
    final deletableIds = workflow.nodes
        .where((node) => _selectedNodeIds.contains(node.id))
        .where((node) => _workflowNodesCanDuplicate(node, workflow))
        .map((node) => node.id)
        .toSet();
    if (deletableIds.isEmpty) return;

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    var updatedWorkflow = workflow;
    for (final nodeId in deletableIds) {
      updatedWorkflow = _workflowDeletingNodes(updatedWorkflow, nodeId);
    }
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _selectedEdge = null;
        _selectedNodeId = null;
        _selectedNodeIds = const <String>{};
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated ? '已删除 ${deletableIds.length} 个节点。' : '所选未删除，请看控制台。',
        ),
      ),
    );
  }
}
