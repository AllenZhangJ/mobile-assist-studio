part of '../../studio_mac_workspace.dart';

// Execute 最近证据分片，负责把本地运行历史转成短入口。
// 详情仍复用 Monitor 的 Run Detail Drawer，不创建第二套视图。

// 最近一次运行证据入口，负责把历史记录转成可打开的短摘要。
class _ExecuteLatestRunPanel extends StatelessWidget {
  const _ExecuteLatestRunPanel({
    required this.entry,
    required this.loading,
    required this.onOpen,
  });

  final RunHistoryEntry? entry;
  final bool loading;
  final VoidCallback? onOpen;

  // 渲染最近一次运行证据入口，详情读取仍由 Runtime 提供。
  @override
  Widget build(BuildContext context) {
    final entry = this.entry;
    return _InsetSurface(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '上次证据',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: entry == null ? '无记录' : entry.status,
                tone: entry == null
                    ? StudioStatusTone.offline
                    : _toneForRunStatus(entry.status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entry == null)
            const Text(
              '暂无证据',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: StudioColors.muted),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.workflowName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${entry.completedLoops}/${entry.loops} 轮 · ${entry.finishedAt == null ? '运行中' : _timeOnly(entry.finishedAt!)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: StudioColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  key: const ValueKey('execute-last-run-detail'),
                  onPressed: loading ? null : onOpen,
                  icon: Icon(
                    loading ? Icons.hourglass_top : Icons.open_in_new,
                    size: 16,
                  ),
                  label: Text(loading ? '加载中' : '详情'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
