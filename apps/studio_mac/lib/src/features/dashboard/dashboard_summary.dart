part of '../../studio_mac_workspace.dart';

// Dashboard 摘要分片，负责工作站健康摘要、运行路径和 KPI 卡片。
class _DashboardSummaryPanel extends StatelessWidget {
  const _DashboardSummaryPanel({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染工作站健康摘要，用一句话说明当前可操作状态。
  @override
  Widget build(BuildContext context) {
    final (label, tone, body) = _dashboardHealth(snapshot);
    return _Surface(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(label: label, tone: tone),
                const SizedBox(height: 12),
                const Text(
                  '本机自动化工作台',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StudioColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          const _DashboardArchitectureBadge(),
        ],
      ),
    );
  }
}

class _DashboardArchitectureBadge extends StatelessWidget {
  const _DashboardArchitectureBadge();

  // 渲染简化运行路径，隐藏底层 Appium / WDA 细节。
  @override
  Widget build(BuildContext context) {
    return const _InsetSurface(
      width: 252,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('运行路径', style: TextStyle(fontWeight: FontWeight.w900)),
          SizedBox(height: 8),
          Text(
            '应用 -> 运行时 -> 驱动 -> 手机',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: TextStyle(color: StudioColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _DashboardKpiCard extends StatelessWidget {
  const _DashboardKpiCard({
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;
  final IconData icon;
  final VoidCallback onTap;

  // 渲染可点击 KPI 卡片，并保持中文短标签不撑开布局。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 158,
      child: _Surface(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: StatusPill(label: label, tone: tone),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, size: 18, color: _colorForTone(tone)),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
