part of '../studio_mac_workspace.dart';

// 工作区容器，负责把当前导航映射到具体页面。
class _Workspace extends StatelessWidget {
  const _Workspace({
    required this.title,
    required this.snapshot,
    required this.controller,
    required this.selectedIndex,
    required this.onNavigate,
    required this.monitorFocusRequest,
    required this.onOpenMonitorFocus,
    required this.onMonitorFocusConsumed,
  });

  final String title;
  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final int selectedIndex;
  final ValueChanged<int> onNavigate;
  final _MonitorFocusRequest? monitorFocusRequest;
  final void Function(String runId, String? nodeId) onOpenMonitorFocus;
  final ValueChanged<int> onMonitorFocusConsumed;

  // 构建统一工作区面板，页面内容交给 PageContent 分派。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: WorkspacePanel(
        title: title,
        trailing: Text(
          '桌面主入口',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: StudioColors.muted),
        ),
        child: _PageContent(
          index: selectedIndex,
          snapshot: snapshot,
          controller: controller,
          onNavigate: onNavigate,
          monitorFocusRequest: monitorFocusRequest,
          onOpenMonitorFocus: onOpenMonitorFocus,
          onMonitorFocusConsumed: onMonitorFocusConsumed,
        ),
      ),
    );
  }
}

// 页面分发器，保持 Shell 不直接依赖各页面构建细节。
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.index,
    required this.snapshot,
    required this.controller,
    required this.onNavigate,
    required this.monitorFocusRequest,
    required this.onOpenMonitorFocus,
    required this.onMonitorFocusConsumed,
  });

  final int index;
  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final ValueChanged<int> onNavigate;
  final _MonitorFocusRequest? monitorFocusRequest;
  final void Function(String runId, String? nodeId) onOpenMonitorFocus;
  final ValueChanged<int> onMonitorFocusConsumed;

  // 根据一级导航索引切换 L1-L6 页面。
  @override
  Widget build(BuildContext context) {
    return switch (index) {
      0 => _DashboardPage(
        snapshot: snapshot,
        controller: controller,
        onNavigate: onNavigate,
      ),
      1 => _DevicePage(snapshot: snapshot, controller: controller),
      2 => _RecorderPage(
        snapshot: snapshot,
        controller: controller,
        onNavigate: onNavigate,
      ),
      3 => _WorkflowPage(
        snapshot: snapshot,
        controller: controller,
        onNavigate: onNavigate,
        onOpenMonitorFocus: onOpenMonitorFocus,
      ),
      4 => _ExecutePage(snapshot: snapshot, controller: controller),
      _ => _MonitorPage(
        snapshot: snapshot,
        controller: controller,
        focusRequest: monitorFocusRequest,
        onFocusConsumed: onMonitorFocusConsumed,
      ),
    };
  }
}
