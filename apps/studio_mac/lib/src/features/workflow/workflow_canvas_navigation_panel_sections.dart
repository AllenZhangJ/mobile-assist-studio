part of '../../studio_mac_workspace.dart';

// Workflow 节点导航面板区块，承载标题、搜索、快捷定位和结果列表。

// 节点导航标题行，展示节点数量并提供收起入口。
class _WorkflowNodeNavigatorHeader extends StatelessWidget {
  const _WorkflowNodeNavigatorHeader({
    required this.nodeCount,
    required this.onToggleExpanded,
  });

  final int nodeCount;
  final VoidCallback onToggleExpanded;

  // 渲染紧凑标题，避免导航面板遮挡主要画布。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.travel_explore_outlined, size: 16),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            '节点导航',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        StatusPill(label: '$nodeCount 个节点', tone: StudioStatusTone.running),
        SizedBox.square(
          dimension: 26,
          child: IconButton(
            key: const ValueKey('workflow-node-navigator-close'),
            tooltip: '收起导航',
            padding: EdgeInsets.zero,
            iconSize: 14,
            onPressed: onToggleExpanded,
            icon: const Icon(Icons.close),
          ),
        ),
      ],
    );
  }
}

// 节点导航搜索框，负责搜索输入和清空搜索。
class _WorkflowNodeSearchField extends StatelessWidget {
  const _WorkflowNodeSearchField({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  // 渲染短搜索框，搜索状态由画布 State 统一持有。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: TextField(
        key: const ValueKey('workflow-node-search'),
        controller: searchController,
        onChanged: onSearchChanged,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          isDense: true,
          hintText: '搜节点',
          prefixIcon: const Icon(Icons.search, size: 16),
          suffixIcon: searchQuery.trim().isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('workflow-node-search-clear'),
                  tooltip: '清空搜索',
                  icon: const Icon(Icons.close, size: 14),
                  onPressed: onClearSearch,
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}

// 节点导航快捷定位区，负责当前、选中、失败和问题入口。
class _WorkflowNavigatorQuickActions extends StatelessWidget {
  const _WorkflowNavigatorQuickActions({
    required this.model,
    required this.executionFocus,
    required this.onFocusNode,
  });

  final _WorkflowNodeNavigatorViewModel model;
  final RuntimeExecutionFocus executionFocus;
  final ValueChanged<String> onFocusNode;

  // 渲染快捷定位按钮，禁用不可用的目标。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _WorkflowNavigatorChip(
          key: const ValueKey('workflow-navigator-current'),
          buttonKey: const ValueKey('workflow-navigator-current-button'),
          label: '当前',
          icon: Icons.play_circle_outline,
          enabled: executionFocus.activeNodeId != null,
          onPressed: executionFocus.activeNodeId == null
              ? null
              : () => onFocusNode(executionFocus.activeNodeId!),
        ),
        _WorkflowNavigatorChip(
          key: const ValueKey('workflow-navigator-selected'),
          buttonKey: const ValueKey('workflow-navigator-selected-button'),
          label: '选中',
          icon: Icons.my_location_outlined,
          enabled: model.selectedFocusNodeId != null,
          onPressed: model.selectedFocusNodeId == null
              ? null
              : () => onFocusNode(model.selectedFocusNodeId!),
        ),
        _WorkflowNavigatorChip(
          key: const ValueKey('workflow-navigator-failed'),
          buttonKey: const ValueKey('workflow-navigator-failed-button'),
          label: '失败',
          icon: Icons.error_outline,
          enabled: executionFocus.failedNodeId != null,
          onPressed: executionFocus.failedNodeId == null
              ? null
              : () => onFocusNode(executionFocus.failedNodeId!),
        ),
        _WorkflowNavigatorChip(
          key: const ValueKey('workflow-navigator-issues'),
          buttonKey: const ValueKey('workflow-navigator-issues-button'),
          label: '问题 ${model.issueNodeIds.length}',
          icon: Icons.report_problem_outlined,
          enabled: model.firstIssueNodeId != null,
          onPressed: model.firstIssueNodeId == null
              ? null
              : () => onFocusNode(model.firstIssueNodeId!),
        ),
      ],
    );
  }
}

// 节点导航结果列表，只展示模型层派生出的安全短文案。
class _WorkflowNavigatorResultsList extends StatelessWidget {
  const _WorkflowNavigatorResultsList({
    required this.results,
    required this.onFocusNode,
  });

  final List<_WorkflowNavigatorResultItem> results;
  final ValueChanged<String> onFocusNode;

  // 渲染搜索结果或空态，点击只执行画布定位。
  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          '无匹配节点',
          key: ValueKey('workflow-node-search-empty'),
          style: TextStyle(color: StudioColors.muted, fontSize: 12),
        ),
      );
    }
    return Column(
      children: [
        for (final node in results) ...[
          _WorkflowNavigatorResult(
            item: node,
            onPressed: () => onFocusNode(node.nodeId),
          ),
          if (node != results.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}
