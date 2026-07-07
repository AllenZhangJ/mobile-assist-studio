part of '../../studio_mac_workspace.dart';

// Workflow 连线动作，负责边上插入、连线新增和连线删除。
extension _WorkflowPageEdgeActions on _WorkflowPageState {
  // 在当前选中的连线上插入节点，并保持图结构合法。
  Future<void> _insertNodesOnSelectedEdge(WorkflowNodeType type) async {
    final selectedEdge = _selectedEdge;
    if (_savingGraphEdit || selectedEdge == null) return;
    final workflow = widget.snapshot.workflow;
    if (!_workflowHasSelectedEdge(workflow, selectedEdge)) {
      return;
    }

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final insertedNodes = _newNodesForInsert(workflow, type);
    final updatedWorkflow = _workflowInsertingNodesOnEdge(
      workflow,
      fromNodeId: selectedEdge.fromNodeId,
      toNodeId: selectedEdge.toNodeId,
      kind: selectedEdge.kind,
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
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '已在连线上插入。' : '插入未保存，请看控制台。')),
    );
  }

  // 从当前选中节点添加一条指向目标节点的连线。
  Future<void> _addEdgeFromSelected(String targetNodesId) async {
    final selectedNodeId = _selectedNodeId;
    if (_workflowGraphEditLocked || selectedNodeId == null) return;
    await _addEdge(selectedNodeId, targetNodesId);
  }

  // 从当前选中节点移除一条指向目标节点的连线。
  Future<void> _removeEdgeFromSelected(String targetNodesId) async {
    final selectedNodeId = _selectedNodeId;
    if (_workflowGraphEditLocked || selectedNodeId == null) return;
    await _removeEdge(
      _WorkflowSelectedEdge(
        fromNodeId: selectedNodeId,
        toNodeId: targetNodesId,
        anchor: Offset.zero,
      ),
    );
  }

  // 写入一条 DSL 连线，具体去重和合法性由 graph helper 处理。
  Future<void> _addEdge(String fromNodeId, String toNodeId) async {
    if (_workflowGraphEditLocked) return;
    if (!_workflowCanAddEdge(
      widget.snapshot.workflow,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('连接不符合流程规则。')));
      return;
    }
    final updatedWorkflow = _workflowAddingEdge(
      widget.snapshot.workflow,
      fromNodeId: fromNodeId,
      toNodeId: toNodeId,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '连接已添加。' : '连接未保存，请看控制台。')),
    );
  }

  // 从 DSL 中移除一条连线，并清理当前边选区。
  Future<void> _removeEdge(_WorkflowSelectedEdge edge) async {
    if (_workflowGraphEditLocked) return;
    final updatedWorkflow = _workflowRemovingEdge(
      widget.snapshot.workflow,
      fromNodeId: edge.fromNodeId,
      toNodeId: edge.toNodeId,
      kind: edge.kind,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() => _selectedEdge = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '连接已删除。' : '删除未保存，请看控制台。')),
    );
  }

  // 把选中边重接到新的目标节点，保存后保留边选中态便于继续检查。
  Future<void> _retargetSelectedEdge(String targetNodesId) async {
    final selectedEdge = _selectedEdge;
    if (_workflowGraphEditLocked || selectedEdge == null) return;
    final workflow = widget.snapshot.workflow;
    if (!_workflowHasSelectedEdge(workflow, selectedEdge) ||
        !_workflowContainsNodes(workflow, targetNodesId) ||
        selectedEdge.fromNodeId == targetNodesId ||
        selectedEdge.toNodeId == targetNodesId ||
        !_workflowCanReplaceEdgeTarget(
          workflow,
          fromNodeId: selectedEdge.fromNodeId,
          oldToNodeId: selectedEdge.toNodeId,
          newToNodeId: targetNodesId,
          kind: selectedEdge.kind,
        )) {
      return;
    }
    final updatedWorkflow = _workflowReplacingEdgeTarget(
      workflow,
      fromNodeId: selectedEdge.fromNodeId,
      oldToNodeId: selectedEdge.toNodeId,
      newToNodeId: targetNodesId,
      kind: selectedEdge.kind,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      if (updated) {
        _selectedEdge = _WorkflowSelectedEdge(
          fromNodeId: selectedEdge.fromNodeId,
          toNodeId: targetNodesId,
          anchor: selectedEdge.anchor,
          kind: selectedEdge.kind,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '目标已更新。' : '目标未保存，请看控制台。')),
    );
  }

  // 把选中边移动到新的起点节点，仍通过 Runtime 保存和校验。
  Future<void> _retargetSelectedEdgeSource(String sourceNodesId) async {
    final selectedEdge = _selectedEdge;
    if (_workflowGraphEditLocked || selectedEdge == null) return;
    final workflow = widget.snapshot.workflow;
    if (!_workflowHasSelectedEdge(workflow, selectedEdge) ||
        !_workflowContainsNodes(workflow, sourceNodesId) ||
        selectedEdge.fromNodeId == sourceNodesId ||
        selectedEdge.toNodeId == sourceNodesId ||
        !_workflowCanReplaceEdgeSource(
          workflow,
          oldFromNodeId: selectedEdge.fromNodeId,
          newFromNodeId: sourceNodesId,
          toNodeId: selectedEdge.toNodeId,
          kind: selectedEdge.kind,
        )) {
      return;
    }
    final updatedWorkflow = _workflowReplacingEdgeSource(
      workflow,
      oldFromNodeId: selectedEdge.fromNodeId,
      newFromNodeId: sourceNodesId,
      toNodeId: selectedEdge.toNodeId,
      kind: selectedEdge.kind,
    );
    final updated = await _updateWorkflowWithHistory(updatedWorkflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      if (updated) {
        _selectedEdge = _WorkflowSelectedEdge(
          fromNodeId: sourceNodesId,
          toNodeId: selectedEdge.toNodeId,
          anchor: selectedEdge.anchor,
          kind: selectedEdge.kind,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '起点已更新。' : '起点未保存，请看控制台。')),
    );
  }
}
