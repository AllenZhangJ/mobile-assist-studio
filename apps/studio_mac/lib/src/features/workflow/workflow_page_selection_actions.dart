part of '../../studio_mac_workspace.dart';

// Workflow 选区动作，负责画布快捷键、剪贴板和校验定位。
extension _WorkflowPageSelectionActions on _WorkflowPageState {
  // 画布快捷键入口，只在可视页签响应自动布局。
  void _autoLayoutWorkflowCanvasShortcut() {
    if (_selectedTab != _WorkflowTab.visual) return;
    unawaited(_autoLayoutWorkflowCanvas());
  }

  // 画布删除快捷键入口，按选区类型分派到删边、删多选或删单点。
  void _deleteWorkflowCanvasSelection() {
    if (_selectedTab != _WorkflowTab.visual) return;
    final selectedEdge = _selectedEdge;
    if (selectedEdge != null) {
      unawaited(_removeEdge(selectedEdge));
      return;
    }
    if (_selectedNodeIds.length > 1) {
      unawaited(_deleteSelectedNodes());
      return;
    }
    unawaited(_deleteSelectedNode());
  }

  // 画布复制快捷键入口，支持单节点和多节点复制。
  void _duplicateWorkflowCanvasSelection() {
    if (_selectedTab != _WorkflowTab.visual) return;
    if (_selectedNodeIds.length > 1) {
      unawaited(_duplicateSelectedNodes());
      return;
    }
    unawaited(_duplicateSelectedNode());
  }

  // 复制当前画布选区到页面和系统剪贴板，支持跨流程粘贴。
  void _copyWorkflowCanvasSelection() {
    if (_selectedTab != _WorkflowTab.visual) return;
    final clipboard = _clipboardForCanvasSelection();
    if (clipboard == null) return;
    _updateWorkflowPageState(() => _canvasClipboard = clipboard);
    unawaited(_writeWorkflowCanvasSystemClipboard(clipboard));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${clipboard.nodes.length} 个节点。')),
    );
  }

  // 剪切当前画布选区，先缓存节点并写系统剪贴板再走安全删除。
  void _cutWorkflowCanvasSelection() {
    if (_selectedTab != _WorkflowTab.visual || _workflowGraphEditLocked) {
      return;
    }
    final clipboard = _clipboardForCanvasSelection();
    if (clipboard == null) return;
    _updateWorkflowPageState(() => _canvasClipboard = clipboard);
    unawaited(_writeWorkflowCanvasSystemClipboard(clipboard));
    unawaited(_deleteSelectedNodes());
  }

  // 从当前选区构造可粘贴剪贴板，只保留允许复制的节点。
  _WorkflowCanvasClipboard? _clipboardForCanvasSelection() {
    final workflow = widget.snapshot.workflow;
    final nodeIds = _selectedNodeIds.isNotEmpty
        ? _selectedNodeIds
        : {if (_selectedNodeId case final selectedNodeId?) selectedNodeId};
    final copyableNodes = workflow.nodes
        .where(
          (node) =>
              nodeIds.contains(node.id) &&
              _workflowNodesCanDuplicate(node, workflow),
        )
        .toList(growable: false);
    if (copyableNodes.isEmpty) return null;
    return _WorkflowCanvasClipboard(copyableNodes);
  }

  // 粘贴页面内或系统剪贴板内容，入口仅负责前置状态检查。
  void _pasteWorkflowCanvasSelection() {
    if (_selectedTab != _WorkflowTab.visual || _workflowGraphEditLocked) {
      return;
    }
    unawaited(_pasteWorkflowCanvasSelectionFromAnyClipboard());
  }

  // 画布快捷键入口，确保只有可视页签会响应撤销。
  void _undoWorkflowCanvasChange() {
    if (_selectedTab != _WorkflowTab.visual) return;
    unawaited(_undoWorkflowChange());
  }

  // 画布快捷键入口，确保只有可视页签会响应重做。
  void _redoWorkflowCanvasChange() {
    if (_selectedTab != _WorkflowTab.visual) return;
    unawaited(_redoWorkflowChange());
  }

  // 选中当前 workflow 的所有节点，并清除边选区。
  void _selectAllWorkflowCanvasNodes() {
    if (_selectedTab != _WorkflowTab.visual) return;
    _updateWorkflowPageState(() {
      _selectedEdge = null;
      _selectedNodeId = null;
      _selectedNodeIds = widget.snapshot.workflow.nodes
          .map((node) => node.id)
          .toSet();
    });
  }

  // 清空画布节点和边选区。
  void _clearWorkflowCanvasSelection() {
    if (_selectedTab != _WorkflowTab.visual) return;
    _updateWorkflowPageState(() {
      _selectedEdge = null;
      _selectedNodeId = null;
      _selectedNodeIds = const <String>{};
    });
  }

  // 从校验结果跳转到对应节点；无法定位节点时切到 Source 并选中诊断范围。
  void _openWorkflowValidateDiagnostic(_WorkflowSourceDiagnostic diagnostic) {
    final nodeId = diagnostic.nodeId;
    final workflow = widget.snapshot.workflow;
    if (nodeId != null && workflow.nodes.any((node) => node.id == nodeId)) {
      _updateWorkflowPageState(() {
        _selectedTab = _WorkflowTab.visual;
        _selectedEdge = null;
        _selectedNodeId = nodeId;
        _selectedNodeIds = {nodeId};
      });
      _workflowCanvasFocusNode.requestFocus();
      return;
    }

    _updateWorkflowPageState(() => _selectedTab = _WorkflowTab.source);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selectWorkflowSourceDiagnostic(_sourceController, diagnostic);
    });
  }

  // 选择粘贴锚点，优先使用原始来源，其次使用当前选中节点和入口节点。
  String? _pasteAnchorNodesId(
    WorkflowDefinition workflow,
    _WorkflowCanvasClipboard clipboard,
  ) {
    final existingNodeIds = workflow.nodes.map((node) => node.id).toSet();
    for (final nodeId in clipboard.sourceNodeIds.reversed) {
      if (existingNodeIds.contains(nodeId)) return nodeId;
    }
    final selectedNodes = _selectedNode(workflow, _selectedNodeId);
    if (selectedNodes != null && selectedNodes.type != WorkflowNodeType.end) {
      return selectedNodes.id;
    }
    final entryNodes = _selectedNode(workflow, workflow.entryNodesId);
    if (entryNodes != null && entryNodes.type != WorkflowNodeType.end) {
      return entryNodes.id;
    }
    return null;
  }
}
