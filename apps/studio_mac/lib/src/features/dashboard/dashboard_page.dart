part of '../../studio_mac_workspace.dart';

// 仪表盘页面，负责用简洁指标展示设备、流程和最近运行概况。
class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.snapshot,
    required this.controller,
    required this.onNavigate,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final ValueChanged<int> onNavigate;

  // 渲染 Dashboard 总览，Workflow KPI 统一读取项目级校验结果。
  @override
  Widget build(BuildContext context) {
    final history = snapshot.runHistory;
    final connectedDevices =
        snapshot.connectionStatus == ConnectionStatus.connected ? 1 : 0;
    final todayRuns = _runsForLocalDate(history.dailyRuns, DateTime.now());
    final workflowValidation = _snapshotWorkflowValidation(snapshot);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _DashboardSummaryPanel(snapshot: snapshot),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _DashboardKpiCard(
              label: '已连设备',
              value: '$connectedDevices',
              tone: connectedDevices == 0
                  ? StudioStatusTone.offline
                  : StudioStatusTone.ready,
              icon: Icons.phone_iphone_outlined,
              onTap: () => onNavigate(1),
            ),
            _DashboardKpiCard(
              label: '流程',
              value: '1',
              tone: _workflowStatusTone(workflowValidation),
              icon: Icons.account_tree_outlined,
              onTap: () => onNavigate(3),
            ),
            _DashboardKpiCard(
              label: '今日运行',
              value: '$todayRuns',
              tone: todayRuns == 0
                  ? StudioStatusTone.offline
                  : StudioStatusTone.running,
              icon: Icons.today_outlined,
              onTap: () => onNavigate(4),
            ),
            _DashboardKpiCard(
              label: '成功率',
              value: _formatPercent(history.successRate),
              tone: history.totalRuns == 0
                  ? StudioStatusTone.offline
                  : history.successRate >= 0.95
                  ? StudioStatusTone.ready
                  : StudioStatusTone.warning,
              icon: Icons.monitor_heart_outlined,
              onTap: () => onNavigate(5),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final recent = _DashboardRecentWorkflowPanel(
              snapshot: snapshot,
              controller: controller,
              onNavigate: onNavigate,
            );
            final activity = SizedBox(
              height: 196,
              child: _DashboardActivityPanel(history: history),
            );
            if (constraints.maxWidth < 860) {
              return Column(
                children: [recent, const SizedBox(height: 14), activity],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: recent),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: activity),
              ],
            );
          },
        ),
      ],
    );
  }
}
