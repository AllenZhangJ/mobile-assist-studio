part of '../studio_mac_workspace.dart';

// 顶部状态栏，负责用摘要状态呈现设备、驱动、流程和执行状态。
class _TopStatusBar extends StatelessWidget {
  const _TopStatusBar({
    required this.snapshot,
    required this.onOpenCommandCenter,
  });

  final StudioRuntimeSnapshot snapshot;
  final VoidCallback onOpenCommandCenter;

  // 根据 Runtime 快照渲染全局状态入口，流程状态统一走项目级校验。
  @override
  Widget build(BuildContext context) {
    final workflowValidation = _snapshotWorkflowValidation(snapshot);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Color(0xEE05080C),
        border: Border(bottom: BorderSide(color: StudioColors.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'iOS 辅助工作台',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(width: 18),
                Flexible(
                  child: Text(
                    'V2.0 本机工作台',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: StudioColors.muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: '命令',
            child: IconButton(
              key: const ValueKey('open-command-center'),
              onPressed: onOpenCommandCenter,
              icon: const Icon(Icons.search, size: 20),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  _StatusChipButton(
                    controlKey: const ValueKey('top-status-device'),
                    tooltip: '查看设备状态',
                    onPressed: () => _openStatusDetailDrawer(
                      context,
                      snapshot,
                      _StatusDetailFocus.device,
                    ),
                    child: _StatusFromConnection(
                      status: snapshot.connectionStatus,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChipButton(
                    controlKey: const ValueKey('top-status-driver'),
                    tooltip: '查看驱动状态',
                    onPressed: () => _openStatusDetailDrawer(
                      context,
                      snapshot,
                      _StatusDetailFocus.driver,
                    ),
                    child: _StatusFromAppium(status: snapshot.appiumStatus),
                  ),
                  const SizedBox(width: 8),
                  _StatusChipButton(
                    controlKey: const ValueKey('top-status-workflow'),
                    tooltip: '查看流程状态',
                    onPressed: () => _openStatusDetailDrawer(
                      context,
                      snapshot,
                      _StatusDetailFocus.workflow,
                    ),
                    child: StatusPill(
                      label: _workflowStatusLabel(workflowValidation),
                      tone: _workflowStatusTone(workflowValidation),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusChipButton(
                    controlKey: const ValueKey('top-status-run'),
                    tooltip: '查看运行状态',
                    onPressed: () => _openStatusDetailDrawer(
                      context,
                      snapshot,
                      _StatusDetailFocus.run,
                    ),
                    child: _StatusFromRun(status: snapshot.runStatus),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
