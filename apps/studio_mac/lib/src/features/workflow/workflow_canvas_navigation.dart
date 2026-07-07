part of '../../studio_mac_workspace.dart';

// Workflow 节点导航器，负责搜索、定位当前节点和跳转问题节点。
class _WorkflowNodeNavigator extends StatelessWidget {
  const _WorkflowNodeNavigator({
    required this.workflow,
    required this.diagnosticsByNodeId,
    required this.executionFocus,
    required this.selectedNodeId,
    required this.selectedNodeIds,
    required this.expanded,
    required this.searchController,
    required this.searchQuery,
    required this.onToggleExpanded,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFocusNode,
  });

  final WorkflowDefinition workflow;
  final Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId;
  final RuntimeExecutionFocus executionFocus;
  final String? selectedNodeId;
  final Set<String> selectedNodeIds;
  final bool expanded;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFocusNode;

  // 渲染折叠按钮或完整导航面板，所有跳转只改变画布视口。
  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return _WorkflowNodeNavigatorCollapsed(
        onToggleExpanded: onToggleExpanded,
      );
    }

    final model = _workflowNodeNavigatorViewModel(
      workflow: workflow,
      diagnosticsByNodeId: diagnosticsByNodeId,
      executionFocus: executionFocus,
      selectedNodeId: selectedNodeId,
      selectedNodeIds: selectedNodeIds,
      searchQuery: searchQuery,
    );
    return _WorkflowNodeNavigatorPanel(
      workflow: workflow,
      model: model,
      executionFocus: executionFocus,
      searchController: searchController,
      searchQuery: searchQuery,
      onToggleExpanded: onToggleExpanded,
      onSearchChanged: onSearchChanged,
      onClearSearch: onClearSearch,
      onFocusNode: onFocusNode,
    );
  }
}
