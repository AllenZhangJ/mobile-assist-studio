part of '../../studio_mac_workspace.dart';

// Workflow 页头工具栏，集中承载状态、标题和画布级主命令。
class _WorkflowPageToolbar extends StatelessWidget {
  const _WorkflowPageToolbar({
    required this.workflow,
    required this.validation,
    required this.canUndo,
    required this.canRedo,
    required this.canEditGraph,
    required this.canOpenExecute,
    required this.openExecuteTooltip,
    required this.onUndo,
    required this.onRedo,
    required this.onAddNode,
    required this.onOpenTemplates,
    required this.onCopySource,
    required this.onOpenExecute,
  });

  final WorkflowDefinition workflow;
  final WorkflowValidateResult validation;
  final bool canUndo;
  final bool canRedo;
  final bool canEditGraph;
  final bool canOpenExecute;
  final String openExecuteTooltip;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final ValueChanged<WorkflowNodeType> onAddNode;
  final VoidCallback onOpenTemplates;
  final VoidCallback onCopySource;
  final VoidCallback onOpenExecute;

  // 构建工具栏，将页面级动作通过回调交给父级状态处理。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StatusPill(
          label: validation.isValid ? '流程就绪' : '流程提醒',
          tone: validation.isValid
              ? StudioStatusTone.ready
              : StudioStatusTone.warning,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            workflow.name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        Tooltip(
          message: openExecuteTooltip,
          child: FilledButton.icon(
            key: const ValueKey('workflow-open-execute'),
            onPressed: canOpenExecute ? onOpenExecute : null,
            icon: const Icon(Icons.play_circle_outline, size: 16),
            label: const Text('去运行'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: const ValueKey('workflow-undo'),
          tooltip: '撤销',
          onPressed: canUndo ? onUndo : null,
          icon: const Icon(Icons.undo, size: 18),
        ),
        IconButton(
          key: const ValueKey('workflow-redo'),
          tooltip: '重做',
          onPressed: canRedo ? onRedo : null,
          icon: const Icon(Icons.redo, size: 18),
        ),
        PopupMenuButton<WorkflowNodeType>(
          key: const ValueKey('workflow-add-node-menu'),
          tooltip: '添加节点',
          enabled: canEditGraph,
          icon: const Icon(Icons.add_circle_outline, size: 18),
          onSelected: onAddNode,
          itemBuilder: (context) => [
            for (final type in _insertableNodeTypes)
              PopupMenuItem<WorkflowNodeType>(
                value: type,
                child: Row(
                  key: ValueKey('workflow-add-node-${_nodeInsertKey(type)}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_iconForNodes(type), size: 16),
                    const SizedBox(width: 8),
                    Text(_insertNodesLabel(type)),
                  ],
                ),
              ),
          ],
        ),
        IconButton(
          tooltip: '打开模板',
          onPressed: canEditGraph ? onOpenTemplates : null,
          icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
        ),
        IconButton(
          tooltip: '复制源码',
          onPressed: onCopySource,
          icon: const Icon(Icons.copy_all_outlined, size: 18),
        ),
      ],
    );
  }
}

// Workflow 顶部页签条，保持画布、源码和检查的切换入口独立。
class _WorkflowTabStrip extends StatelessWidget {
  const _WorkflowTabStrip({
    required this.selectedTab,
    required this.onSelectTab,
  });

  final _WorkflowTab selectedTab;
  final ValueChanged<_WorkflowTab> onSelectTab;

  // 构建横向页签列表，小屏时允许横向滚动。
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in _WorkflowTab.values) ...[
            _WorkflowTabButton(
              tab: tab,
              selected: selectedTab == tab,
              onPressed: () => onSelectTab(tab),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// Workflow 页签按钮，负责统一页签图标、文案和选中态。
class _WorkflowTabButton extends StatelessWidget {
  const _WorkflowTabButton({
    required this.tab,
    required this.selected,
    required this.onPressed,
  });

  final _WorkflowTab tab;
  final bool selected;
  final VoidCallback onPressed;

  // 构建单个页签按钮，选中态只改变外观不触发额外副作用。
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: ValueKey('workflow-tab-${tab.name}'),
      onPressed: onPressed,
      icon: Icon(tab.icon, size: 16),
      label: Text(tab.label),
      style: TextButton.styleFrom(
        foregroundColor: selected ? StudioColors.cyan : StudioColors.muted,
        backgroundColor: selected
            ? StudioColors.cyan.withValues(alpha: 0.10)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected
                ? StudioColors.cyan.withValues(alpha: 0.36)
                : StudioColors.border,
          ),
        ),
      ),
    );
  }
}
