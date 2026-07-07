part of '../../studio_mac_workspace.dart';

// Dashboard 最近流程行，只负责展示流程摘要和行内按钮。
// 具体 Runtime 写入由外部动作回调完成，行组件保持纯展示。
class _DashboardWorkflowRow extends StatelessWidget {
  const _DashboardWorkflowRow({
    required this.workflowName,
    required this.status,
    required this.lastRun,
    required this.successRate,
    required this.nodeCount,
    required this.workflowValidation,
    required this.isFavorite,
    required this.workflowActionsLocked,
    required this.onToggleFavorite,
    required this.onDuplicate,
    required this.onDelete,
    required this.onOpenDetails,
    required this.onOpenWorkflow,
    required this.onOpenExecute,
  });

  final String workflowName;
  final String status;
  final DateTime? lastRun;
  final double successRate;
  final int nodeCount;
  final WorkflowValidateResult workflowValidation;
  final bool isFavorite;
  final bool workflowActionsLocked;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenWorkflow;
  final VoidCallback onOpenExecute;

  // 渲染单个流程摘要行，运行入口只依赖传入的校验结果。
  @override
  Widget build(BuildContext context) {
    return _InsetSurface(
      child: Row(
        children: [
          StatusPill(label: status, tone: _toneForDashboardWorkflow(status)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workflowName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '$nodeCount 个节点 · 最近运行 ${lastRun == null ? '-' : _timeOnly(lastRun!)}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: StudioColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _DashboardWorkflowRowActions(
            successRate: successRate,
            isFavorite: isFavorite,
            workflowActionsLocked: workflowActionsLocked,
            workflowValidation: workflowValidation,
            onToggleFavorite: onToggleFavorite,
            onDuplicate: onDuplicate,
            onDelete: onDelete,
            onOpenDetails: onOpenDetails,
            onOpenWorkflow: onOpenWorkflow,
            onOpenExecute: onOpenExecute,
          ),
        ],
      ),
    );
  }
}

// Dashboard 最近流程按钮组，统一承载收藏、复制、删除和跳转入口。
// 按钮只调用回调，不直接读取 Runtime 或修改 Project DSL。
class _DashboardWorkflowRowActions extends StatelessWidget {
  const _DashboardWorkflowRowActions({
    required this.successRate,
    required this.isFavorite,
    required this.workflowActionsLocked,
    required this.workflowValidation,
    required this.onToggleFavorite,
    required this.onDuplicate,
    required this.onDelete,
    required this.onOpenDetails,
    required this.onOpenWorkflow,
    required this.onOpenExecute,
  });

  final double successRate;
  final bool isFavorite;
  final bool workflowActionsLocked;
  final WorkflowValidateResult workflowValidation;
  final VoidCallback onToggleFavorite;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onOpenDetails;
  final VoidCallback onOpenWorkflow;
  final VoidCallback onOpenExecute;

  // 渲染成功率和行内图标按钮，保持紧凑避免中文撑开布局。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _formatPercent(successRate),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.end,
          children: [
            IconButton.outlined(
              key: const ValueKey('dashboard-workflow-favorite'),
              tooltip: isFavorite ? '取消收藏' : '收藏',
              onPressed: onToggleFavorite,
              color: isFavorite ? StudioColors.amber : null,
              icon: Icon(isFavorite ? Icons.star : Icons.star_border, size: 17),
            ),
            IconButton.outlined(
              key: const ValueKey('dashboard-workflow-copy'),
              tooltip: workflowActionsLocked ? '运行中不可复制' : '复制',
              onPressed: workflowActionsLocked ? null : onDuplicate,
              icon: const Icon(Icons.copy_outlined, size: 17),
            ),
            IconButton.outlined(
              key: const ValueKey('dashboard-workflow-delete'),
              tooltip: workflowActionsLocked ? '运行中不可删除' : '删除',
              onPressed: workflowActionsLocked ? null : onDelete,
              icon: const Icon(Icons.delete_outline, size: 17),
            ),
            IconButton.outlined(
              key: const ValueKey('dashboard-workflow-details'),
              tooltip: '流程详情',
              onPressed: onOpenDetails,
              icon: const Icon(Icons.info_outline, size: 17),
            ),
            IconButton.outlined(
              key: const ValueKey('dashboard-open-workflow'),
              tooltip: '打开流程',
              onPressed: onOpenWorkflow,
              icon: const Icon(Icons.account_tree_outlined, size: 17),
            ),
            IconButton.outlined(
              key: const ValueKey('dashboard-open-execute'),
              tooltip: workflowValidation.isValid ? '去运行' : '需修正',
              onPressed: workflowValidation.isValid ? onOpenExecute : null,
              icon: const Icon(Icons.play_circle_outline, size: 17),
            ),
          ],
        ),
      ],
    );
  }
}
