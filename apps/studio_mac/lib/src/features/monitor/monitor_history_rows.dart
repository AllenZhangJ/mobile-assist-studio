part of '../../studio_mac_workspace.dart';

// 单条运行记录行，负责展示摘要并打开本地详情。
class _RunHistoryRow extends StatelessWidget {
  const _RunHistoryRow({
    required this.entry,
    required this.loading,
    required this.onOpen,
  });

  final RunHistoryEntry entry;
  final bool loading;
  final VoidCallback onOpen;

  // 渲染运行摘要行，避免展示 run id、路径或底层 payload。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          StatusPill(
            label: _runHistoryStatusLabel(entry.status),
            tone: _toneForRunStatus(entry.status),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.workflowName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${entry.completedLoops}/${entry.loops} 轮',
            style: const TextStyle(color: StudioColors.muted),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 88,
            child: Text(
              entry.finishedAt == null ? '-' : _timeOnly(entry.finishedAt!),
              textAlign: TextAlign.right,
              style: const TextStyle(color: StudioColors.muted),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            key: ValueKey('run-detail-${entry.runId}'),
            onPressed: loading ? null : onOpen,
            icon: Icon(
              loading ? Icons.hourglass_top : Icons.open_in_new,
              size: 16,
            ),
            label: Text(loading ? '加载中' : '详情'),
          ),
        ],
      ),
    );
  }
}

// 打开运行详情抽屉，只读取传入详情，不直接访问文件或设备。
Future<void> _showRunDetailDrawer(
  BuildContext context, {
  required RunHistoryEntry entry,
  required RunDetail? detail,
  required RunLocalReport? report,
  required StudioRuntimeController controller,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    barrierDismissible: true,
    barrierLabel: '关闭详情',
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) => _RunDetailDrawer(
      entry: entry,
      detail: detail,
      report: report,
      controller: controller,
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}
