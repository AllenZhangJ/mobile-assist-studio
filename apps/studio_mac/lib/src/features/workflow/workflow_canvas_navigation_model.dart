part of '../../studio_mac_workspace.dart';

// Workflow 画布导航模型，负责把 workflow、诊断和搜索词整理成 UI 可直接消费的状态。

// 构建节点导航面板状态，限制搜索结果数量并找出常用定位目标。
_WorkflowNodeNavigatorViewModel _workflowNodeNavigatorViewModel({
  required WorkflowDefinition workflow,
  required Map<String, List<_WorkflowSourceDiagnostic>> diagnosticsByNodeId,
  required RuntimeExecutionFocus executionFocus,
  required String? selectedNodeId,
  required Set<String> selectedNodeIds,
  required String searchQuery,
}) {
  final issueNodeIds = diagnosticsByNodeId.keys
      .where((nodeId) => diagnosticsByNodeId[nodeId]?.isNotEmpty ?? false)
      .toSet();
  final firstIssueNodeId = workflow.nodes
      .where((node) => issueNodeIds.contains(node.id))
      .map((node) => node.id)
      .firstOrNull;
  final selectedFocusNodeId = _workflowNavigatorSelectedNodeId(
    workflow,
    selectedNodeId,
    selectedNodeIds,
  );
  final results = _workflowNavigatorResults(workflow, searchQuery)
      .take(5)
      .map(
        (node) => _WorkflowNavigatorResultItem.fromNode(
          node,
          selected:
              node.id == selectedNodeId || selectedNodeIds.contains(node.id),
          current: executionFocus.activeNodeId == node.id,
          failed: executionFocus.failedNodeId == node.id,
          issueCount: diagnosticsByNodeId[node.id]?.length ?? 0,
        ),
      )
      .toList(growable: false);
  return _WorkflowNodeNavigatorViewModel(
    issueNodeIds: issueNodeIds,
    firstIssueNodeId: firstIssueNodeId,
    selectedFocusNodeId: selectedFocusNodeId,
    results: results,
  );
}

// 节点导航面板状态，只保存展示所需的派生结果。
final class _WorkflowNodeNavigatorViewModel {
  // 创建节点导航面板状态，调用方传入已脱离 UI 的派生结果。
  const _WorkflowNodeNavigatorViewModel({
    required this.issueNodeIds,
    required this.firstIssueNodeId,
    required this.selectedFocusNodeId,
    required this.results,
  });

  final Set<String> issueNodeIds;
  final String? firstIssueNodeId;
  final String? selectedFocusNodeId;
  final List<_WorkflowNavigatorResultItem> results;
}

// 返回导航面板应定位的选中节点，多选时按 workflow 顺序取第一个。
String? _workflowNavigatorSelectedNodeId(
  WorkflowDefinition workflow,
  String? selectedNodeId,
  Set<String> selectedNodeIds,
) {
  if (selectedNodeId != null &&
      workflow.nodes.any((node) => node.id == selectedNodeId)) {
    return selectedNodeId;
  }
  return workflow.nodes
      .where((node) => selectedNodeIds.contains(node.id))
      .map((node) => node.id)
      .firstOrNull;
}

// 节点导航单行展示项，把 DSL 节点转成用户可读的短中文字段。
final class _WorkflowNavigatorResultItem {
  // 创建导航展示项，只保留定位和渲染必需的信息。
  const _WorkflowNavigatorResultItem({
    required this.nodeId,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.selected,
    required this.current,
    required this.failed,
    required this.issueCount,
    required this.tone,
    required this.statusLabel,
  });

  // 从 workflow 节点派生导航展示项，避免 UI 直接拼接内部 ID。
  factory _WorkflowNavigatorResultItem.fromNode(
    WorkflowNode node, {
    required bool selected,
    required bool current,
    required bool failed,
    required int issueCount,
  }) {
    final tone = failed
        ? StudioStatusTone.error
        : current
        ? StudioStatusTone.ready
        : issueCount > 0
        ? StudioStatusTone.warning
        : StudioStatusTone.running;
    return _WorkflowNavigatorResultItem(
      nodeId: node.id,
      title: node.label,
      subtitle:
          '${_nodePaletteLabel(node.type)} · ${_workflowNavigatorNodeHint(node)}',
      type: node.type,
      selected: selected,
      current: current,
      failed: failed,
      issueCount: issueCount,
      tone: tone,
      statusLabel: failed
          ? '失败'
          : current
          ? '当前'
          : issueCount > 0
          ? '$issueCount 个问题'
          : null,
    );
  }

  final String nodeId;
  final String title;
  final String subtitle;
  final WorkflowNodeType type;
  final bool selected;
  final bool current;
  final bool failed;
  final int issueCount;
  final StudioStatusTone tone;
  final String? statusLabel;
}

// 返回导航副标题的短中文提示，隐藏节点 ID 和底层枚举名。
String _workflowNavigatorNodeHint(WorkflowNode node) {
  return switch (node.type) {
    WorkflowNodeType.start => '入口',
    WorkflowNodeType.end => '结束',
    WorkflowNodeType.tap => '点击动作',
    WorkflowNodeType.wait => '${node.parameters['ms'] ?? '-'}ms',
    WorkflowNodeType.swipe => '滑动手势',
    WorkflowNodeType.input => '输入文本',
    WorkflowNodeType.snapshot => '留存画面',
    WorkflowNodeType.condition => '条件分支',
    WorkflowNodeType.visualBranch => '看图判断',
    WorkflowNodeType.waitForTarget => '等待目标',
    WorkflowNodeType.loop => '重复几次',
    WorkflowNodeType.catchNodes => '失败兜底',
    WorkflowNodeType.subWorkflow => '复用步骤',
  };
}
