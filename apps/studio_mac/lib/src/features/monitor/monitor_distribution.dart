part of '../../studio_mac_workspace.dart';

// 运行状态分布面板，展示完成、失败、暂停和停止的比例。
class _RunStatusDistributionPanel extends StatelessWidget {
  const _RunStatusDistributionPanel({required this.history});

  final RunHistorySummary history;

  // 渲染状态分布条和简短计数 chip。
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '状态分布',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          _RunDistributionBar(history: history),
          const SizedBox(height: 12),
          Expanded(
            child: Wrap(
              runSpacing: 8,
              spacing: 8,
              children: [
                _RunDistributionChip(
                  label: '完成',
                  value: history.completedRuns,
                  tone: StudioStatusTone.ready,
                ),
                _RunDistributionChip(
                  label: '失败',
                  value: history.failedRuns,
                  tone: StudioStatusTone.error,
                ),
                _RunDistributionChip(
                  label: '暂停',
                  value: history.pausedRuns,
                  tone: StudioStatusTone.warning,
                ),
                _RunDistributionChip(
                  label: '已停',
                  value: history.stoppedRuns,
                  tone: StudioStatusTone.warning,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 横向比例条，按运行状态切分颜色段。
class _RunDistributionBar extends StatelessWidget {
  const _RunDistributionBar({required this.history});

  final RunHistorySummary history;

  // 根据本地运行总数计算每个状态的可见比例。
  @override
  Widget build(BuildContext context) {
    final total = math.max(1, history.totalRuns);
    final segments = <({int value, Color color})>[
      (value: history.completedRuns, color: StudioColors.green),
      (value: history.failedRuns, color: StudioColors.red),
      (value: history.pausedRuns, color: StudioColors.amber),
      (value: history.stoppedRuns, color: StudioColors.muted),
    ].where((segment) => segment.value > 0).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 12,
        color: StudioColors.background.withValues(alpha: 0.72),
        child: Row(
          children: segments.isEmpty
              ? [
                  Expanded(
                    child: ColoredBox(
                      color: StudioColors.muted.withValues(alpha: 0.24),
                    ),
                  ),
                ]
              : [
                  for (final segment in segments)
                    Expanded(
                      flex: math.max(1, (segment.value / total * 1000).round()),
                      child: ColoredBox(color: segment.color),
                    ),
                ],
        ),
      ),
    );
  }
}

// 状态计数 chip，保持统一的颜色点和数字布局。
class _RunDistributionChip extends StatelessWidget {
  const _RunDistributionChip({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final int value;
  final StudioStatusTone tone;

  // 渲染最小宽度 chip，避免中文状态被挤压。
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 96),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.44),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _colorForTone(tone),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
