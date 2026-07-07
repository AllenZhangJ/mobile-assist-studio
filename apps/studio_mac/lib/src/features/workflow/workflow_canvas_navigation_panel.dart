part of '../../studio_mac_workspace.dart';

// Workflow 节点导航展开面板，负责组合标题、搜索、快捷定位和结果列表。
class _WorkflowNodeNavigatorPanel extends StatelessWidget {
  const _WorkflowNodeNavigatorPanel({
    required this.workflow,
    required this.model,
    required this.executionFocus,
    required this.searchController,
    required this.searchQuery,
    required this.onToggleExpanded,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFocusNode,
  });

  final WorkflowDefinition workflow;
  final _WorkflowNodeNavigatorViewModel model;
  final RuntimeExecutionFocus executionFocus;
  final TextEditingController searchController;
  final String searchQuery;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onFocusNode;

  // 渲染完整导航面板，所有按钮只触发画布定位回调。
  @override
  Widget build(BuildContext context) {
    return _WorkflowNavigatorSurface(
      child: SizedBox(
        width: 316,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WorkflowNodeNavigatorHeader(
                nodeCount: workflow.nodes.length,
                onToggleExpanded: onToggleExpanded,
              ),
              const SizedBox(height: 8),
              _WorkflowNodeSearchField(
                searchController: searchController,
                searchQuery: searchQuery,
                onSearchChanged: onSearchChanged,
                onClearSearch: onClearSearch,
              ),
              const SizedBox(height: 8),
              _WorkflowNavigatorQuickActions(
                model: model,
                executionFocus: executionFocus,
                onFocusNode: onFocusNode,
              ),
              const SizedBox(height: 8),
              _WorkflowNavigatorResultsList(
                results: model.results,
                onFocusNode: onFocusNode,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
