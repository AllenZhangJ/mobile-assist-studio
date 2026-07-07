part of '../../studio_mac_workspace.dart';

// Dashboard 最近流程动作分片，只承载本机流程的安全快捷命令。
// 所有写入都通过 Dart Runtime，不连接设备、不启动运行。
extension _DashboardRecentWorkflowActions on _DashboardRecentWorkflowPanel {
  // 收藏只写本机设置，用于标记当前流程，不触发设备动作。
  Future<void> _toggleFavorite(BuildContext context) async {
    final wasFavorite = snapshot.settings.favoriteWorkflowIds.contains(
      snapshot.workflow.id,
    );
    final saved = await controller.toggleCurrentWorkflowFavorite();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(saved ? (wasFavorite ? '已取消' : '已收藏') : '未保存')),
    );
  }

  // 复制通过 Runtime 生成当前流程副本，页面只展示结果反馈。
  Future<void> _duplicateWorkflow(BuildContext context) async {
    final saved = await controller.duplicateCurrentWorkflow();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(saved ? '已复制' : '未复制')));
  }

  // 删除前给出确认，确认后由 Runtime 回到基础模板。
  Future<void> _confirmDeleteWorkflow(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除流程？'),
          content: const Text('会回到基础模板，设备不会动作。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final saved = await controller.resetCurrentWorkflowToTemplate();
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(saved ? '已删除' : '未删除')));
  }
}
