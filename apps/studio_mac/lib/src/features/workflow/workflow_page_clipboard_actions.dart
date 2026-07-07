part of '../../studio_mac_workspace.dart';

// Workflow 剪贴板落盘动作，负责把页面内剪贴板写回 DSL。
extension _WorkflowPageClipboardActions on _WorkflowPageState {
  // 执行剪贴板粘贴，写入 DSL 后把选区切到新节点集合。
  Future<void> _pasteWorkflowCanvasClipboard(
    _WorkflowCanvasClipboard clipboard,
  ) async {
    if (_workflowGraphEditLocked || clipboard.nodes.isEmpty) return;
    final workflow = widget.snapshot.workflow;
    final anchorNodeId = _pasteAnchorNodesId(workflow, clipboard);
    if (anchorNodeId == null) return;
    final entryNodes = _selectedNode(workflow, anchorNodeId);
    if (entryNodes == null || entryNodes.type == WorkflowNodeType.end) return;

    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final result = _workflowPastingClipboardNodes(
      workflow,
      clipboard,
      anchorNodeId: anchorNodeId,
    );
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
        _canvasClipboard = _WorkflowCanvasClipboard.fromWorkflow(
          result.workflow,
          result.duplicatedNodeIds,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updated
              ? '已粘贴 ${result.duplicatedNodeIds.length} 个节点。'
              : '粘贴未保存，请看控制台。',
        ),
      ),
    );
  }
}
