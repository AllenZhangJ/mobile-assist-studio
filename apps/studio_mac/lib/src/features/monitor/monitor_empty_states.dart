part of '../../studio_mac_workspace.dart';

// 运行详情通用空态，供时间轴和相关事件复用。
class _RunDetailEmptyState extends StatelessWidget {
  const _RunDetailEmptyState({this.message = '暂无运行证据'});

  final String message;

  // 渲染运行详情空态。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: StudioColors.muted)),
    );
  }
}

// Monitor 页面通用空态，供记录列表和筛选结果复用。
class _MonitorEmptyState extends StatelessWidget {
  const _MonitorEmptyState({this.message = '暂无记录'});

  final String message;

  // 渲染 Monitor 页面空态。
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: const TextStyle(color: StudioColors.muted)),
    );
  }
}
