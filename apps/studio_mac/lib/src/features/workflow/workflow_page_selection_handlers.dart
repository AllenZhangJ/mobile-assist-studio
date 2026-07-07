part of '../../studio_mac_workspace.dart';

// Workflow 画布选择处理，统一维护节点选区和连线选区互斥关系。
extension _WorkflowPageSelectionHandlers on _WorkflowPageState {
  /// 选中单个画布节点。
  /// 该动作只更新页面选择态，不直接写 Project DSL。
  void _selectSingleWorkflowNodeFromCanvas(WorkflowNode node) {
    _updateWorkflowPageState(() {
      _workflowCanvasFocusNode.requestFocus();
      _selectedNodeId = node.id;
      _selectedNodeIds = {node.id};
      _selectedEdge = null;
    });
  }

  /// 选中多个画布节点。
  /// 多选时右侧 Inspector 展示批量摘要，单选时同步当前节点。
  void _selectWorkflowNodesFromCanvas(Set<String> nodeIds) {
    _updateWorkflowPageState(() {
      _workflowCanvasFocusNode.requestFocus();
      _selectedNodeIds = nodeIds;
      _selectedNodeId = nodeIds.length == 1 ? nodeIds.single : null;
      _selectedEdge = null;
    });
  }

  /// 选中画布连线。
  /// 连线选中后清空节点选区，避免 Inspector 同时指向两类目标。
  void _selectWorkflowEdgeFromCanvas(_WorkflowSelectedEdge? edge) {
    _updateWorkflowPageState(() {
      _workflowCanvasFocusNode.requestFocus();
      _selectedEdge = edge;
      if (edge != null) {
        _selectedNodeId = null;
        _selectedNodeIds = const <String>{};
      }
    });
  }
}
