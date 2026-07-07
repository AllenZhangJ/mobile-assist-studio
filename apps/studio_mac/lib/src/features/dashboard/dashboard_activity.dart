part of '../../studio_mac_workspace.dart';

// Dashboard 趋势分片，负责展示最近本机运行活动。
class _DashboardActivityPanel extends StatelessWidget {
  const _DashboardActivityPanel({required this.history});

  final RunHistorySummary history;

  // 渲染最近活动趋势，复用 Monitor 的趋势柱形视觉。
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '趋势',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: history.dailyRuns.isEmpty
                ? const Center(
                    child: Text(
                      '暂无活动',
                      style: TextStyle(color: StudioColors.muted),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final day in history.dailyRuns) ...[
                        Expanded(
                          child: _RunTrendDayBar(
                            day: day,
                            maxRuns: _maxDailyRuns(history.dailyRuns),
                          ),
                        ),
                        if (day != history.dailyRuns.last)
                          const SizedBox(width: 7),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
