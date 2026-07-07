part of '../../studio_mac_workspace.dart';

// Dashboard 最近流程面板，负责把 Runtime 快照整理成一张本机流程卡片。
// 收藏、复制、删除和行内按钮分别拆到独立分片，避免入口文件膨胀。
class _DashboardRecentWorkflowPanel extends StatelessWidget {
  const _DashboardRecentWorkflowPanel({
    required this.snapshot,
    required this.controller,
    required this.onNavigate,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final ValueChanged<int> onNavigate;

  // 渲染最近流程卡片，并把动作入口交给 Dashboard 动作分片。
  @override
  Widget build(BuildContext context) {
    final lastRun = snapshot.runHistory.recentRuns.isEmpty
        ? null
        : snapshot.runHistory.recentRuns.first;
    final isFavorite = snapshot.settings.favoriteWorkflowIds.contains(
      snapshot.workflow.id,
    );
    final workflowActionsLocked = snapshot.runStatus != RunStatus.idle;
    final workflowValidation = _snapshotWorkflowValidation(snapshot);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '最近流程',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            '本机流程摘要。',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: StudioColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _DashboardWorkflowRow(
            workflowName: snapshot.workflow.name,
            status: lastRun == null
                ? '就绪'
                : _runHistoryStatusLabel(lastRun.status),
            lastRun: lastRun?.finishedAt ?? lastRun?.startedAt,
            successRate: snapshot.runHistory.successRate,
            nodeCount: snapshot.workflow.nodes.length,
            workflowValidation: workflowValidation,
            isFavorite: isFavorite,
            workflowActionsLocked: workflowActionsLocked,
            onToggleFavorite: () => unawaited(_toggleFavorite(context)),
            onDuplicate: () => unawaited(_duplicateWorkflow(context)),
            onDelete: () => unawaited(_confirmDeleteWorkflow(context)),
            onOpenDetails: () =>
                _openDashboardWorkflowDetail(context, snapshot),
            onOpenWorkflow: () => onNavigate(3),
            onOpenExecute: () => onNavigate(4),
          ),
        ],
      ),
    );
  }
}
