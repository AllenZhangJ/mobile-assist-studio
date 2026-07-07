part of '../../studio_mac_workspace.dart';

// Workflow Inspector 子流程选择器，承载本机子流程选择、注册和删除入口。

class _SubWorkflowPicker extends StatelessWidget {
  const _SubWorkflowPicker({
    required this.subWorkflows,
    required this.locked,
    required this.selectedWorkflowId,
    required this.onAddStarter,
    required this.onAddCurrent,
    required this.onDelete,
    required this.onSelect,
  });

  final List<SubWorkflowSummary> subWorkflows;
  final bool locked;
  final String selectedWorkflowId;
  final VoidCallback? onAddStarter;
  final VoidCallback? onAddCurrent;
  final ValueChanged<SubWorkflowSummary>? onDelete;
  final ValueChanged<String> onSelect;

  // 构建子流程选择区，可选择目标、注册示例或删除未引用子流程。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('sub-workflow-picker'),
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '可用子流程',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(
                  label: '${subWorkflows.length}',
                  tone: subWorkflows.isEmpty
                      ? StudioStatusTone.offline
                      : StudioStatusTone.ready,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('sub-workflow-add-starter'),
                  onPressed: locked ? null : onAddStarter,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('添加'),
                  style: _subWorkflowActionButtonStyle(),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('sub-workflow-add-current'),
                  onPressed: locked ? null : onAddCurrent,
                  icon: const Icon(Icons.save_alt_outlined, size: 14),
                  label: const Text('存为'),
                  style: _subWorkflowActionButtonStyle(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (subWorkflows.isEmpty)
              const Text(
                '暂无子流程。',
                style: TextStyle(color: StudioColors.muted, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final subWorkflow in subWorkflows)
                    _SubWorkflowChoiceChip(
                      summary: subWorkflow,
                      selected: subWorkflow.workflowId == selectedWorkflowId,
                      locked: locked || !subWorkflow.isValid,
                      deleteLocked:
                          locked ||
                          subWorkflow.workflowId == selectedWorkflowId,
                      onSelect: () => onSelect(subWorkflow.workflowId),
                      onDelete: onDelete == null
                          ? null
                          : () => onDelete!(subWorkflow),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// 子流程选择条目，支持选择和安全删除入口。
// 宽度受限时名称自动省略，避免中文文案撑开 Inspector。
class _SubWorkflowChoiceChip extends StatelessWidget {
  const _SubWorkflowChoiceChip({
    required this.summary,
    required this.selected,
    required this.locked,
    required this.deleteLocked,
    required this.onSelect,
    required this.onDelete,
  });

  final SubWorkflowSummary summary;
  final bool selected;
  final bool locked;
  final bool deleteLocked;
  final VoidCallback onSelect;
  final VoidCallback? onDelete;

  // 构建单个子流程条目，展示名称、节点数、选择和删除入口。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? StudioColors.cyan.withValues(alpha: 0.08)
            : const Color(0xFF050A0F),
        border: Border.all(
          color: selected
              ? StudioColors.cyan.withValues(alpha: 0.52)
              : StudioColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 180),
        child: Row(
          children: [
            Flexible(
              child: TextButton.icon(
                key: ValueKey('sub-workflow-option-${summary.workflowId}'),
                onPressed: locked ? null : onSelect,
                icon: Icon(
                  selected
                      ? Icons.check_circle_outline
                      : Icons.account_tree_outlined,
                  size: 16,
                ),
                label: Text(
                  '${summary.name} ${summary.nodeCount}',
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: selected
                      ? StudioColors.cyan
                      : StudioColors.text,
                  padding: const EdgeInsets.only(left: 10, right: 6),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 32,
              child: IconButton(
                key: ValueKey('sub-workflow-delete-${summary.workflowId}'),
                tooltip: selected ? '先取消选择' : '删除',
                onPressed: deleteLocked ? null : onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                iconSize: 15,
                color: StudioColors.muted,
                disabledColor: StudioColors.border,
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 生成子流程区顶部的小按钮样式，保证短中文在窄面板里稳定显示。
ButtonStyle _subWorkflowActionButtonStyle() {
  return OutlinedButton.styleFrom(
    visualDensity: VisualDensity.compact,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}
