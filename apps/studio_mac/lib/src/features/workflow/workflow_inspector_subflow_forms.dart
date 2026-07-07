part of '../../studio_mac_workspace.dart';

// Inspector 子流程表单，负责本地子流程选择与受控入口。

// Sub Workflow 参数字段，负责选择本地已注册子流程。
class _SubWorkflowParameterFields extends StatelessWidget {
  const _SubWorkflowParameterFields({
    required this.enabled,
    required this.workflowIdController,
    required this.inputMapController,
    required this.subWorkflows,
    required this.onAddStarterSubWorkflow,
    required this.onAddCurrentAsSubWorkflow,
    required this.onDeleteSubWorkflow,
  });

  final bool enabled;
  final TextEditingController workflowIdController;
  final TextEditingController inputMapController;
  final List<SubWorkflowSummary> subWorkflows;
  final VoidCallback? onAddStarterSubWorkflow;
  final VoidCallback? onAddCurrentAsSubWorkflow;
  final ValueChanged<SubWorkflowSummary>? onDeleteSubWorkflow;

  // 渲染子流程选择器，注册和删除仍走 Runtime 的受控入口。
  @override
  Widget build(BuildContext context) {
    final selectedWorkflowId = workflowIdController.text.trim();
    final selectedSubWorkflow = _selectedSubWorkflowSummary(
      subWorkflows,
      selectedWorkflowId,
    );
    return Column(
      children: [
        const SizedBox(height: 10),
        _SelectedSubWorkflowSummary(
          key: const ValueKey('node-inspector-workflow-id'),
          selected: selectedSubWorkflow,
          rawWorkflowId: selectedWorkflowId,
        ),
        const SizedBox(height: 10),
        _SubWorkflowInputMapField(
          enabled: enabled,
          controller: inputMapController,
        ),
        const SizedBox(height: 10),
        _SubWorkflowPicker(
          subWorkflows: subWorkflows,
          locked: !enabled,
          selectedWorkflowId: selectedWorkflowId,
          onAddStarter: onAddStarterSubWorkflow,
          onAddCurrent: onAddCurrentAsSubWorkflow,
          onDelete: onDeleteSubWorkflow,
          onSelect: (workflowId) {
            workflowIdController.text = workflowId;
          },
        ),
      ],
    );
  }
}

// 当前子流程摘要，只展示名称和节点数，不要求用户理解 workflowId。
class _SelectedSubWorkflowSummary extends StatelessWidget {
  const _SelectedSubWorkflowSummary({
    super.key,
    required this.selected,
    required this.rawWorkflowId,
  });

  final SubWorkflowSummary? selected;
  final String rawWorkflowId;

  // 渲染只读选择状态，缺失引用只给用户可理解的提醒。
  @override
  Widget build(BuildContext context) {
    final label = selected == null
        ? rawWorkflowId.isEmpty
              ? '未选择'
              : '未找到子流程'
        : '${selected!.name} · ${selected!.nodeCount} 节点';
    final tone = selected == null
        ? StudioStatusTone.warning
        : selected!.isValid
        ? StudioStatusTone.ready
        : StudioStatusTone.warning;
    return InputDecorator(
      decoration: _inspectorInputDecoration('子流程'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(
            label: selected == null
                ? '待选'
                : selected!.isValid
                ? '可用'
                : '有问题',
            tone: tone,
          ),
        ],
      ),
    );
  }
}

// 根据内部 workflowId 查找子流程摘要，UI 层只展示查找后的友好文案。
SubWorkflowSummary? _selectedSubWorkflowSummary(
  List<SubWorkflowSummary> subWorkflows,
  String workflowId,
) {
  if (workflowId.isEmpty) return null;
  for (final summary in subWorkflows) {
    if (summary.workflowId == workflowId) return summary;
  }
  return null;
}
