part of '../../studio_mac_workspace.dart';

// Dashboard 流程详情分片，负责只读 Drawer 和详情打开动作。
void _openDashboardWorkflowDetail(
  BuildContext context,
  StudioRuntimeSnapshot snapshot,
) {
  // 打开只读流程详情抽屉，不触发设备、运行或 workflow 写入。
  unawaited(
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '关闭摘要',
      barrierColor: Colors.black.withValues(alpha: 0.42),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: _DashboardWorkflowDetailDrawer(snapshot: snapshot),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        );
      },
    ),
  );
}

class _DashboardWorkflowDetailDrawer extends StatelessWidget {
  const _DashboardWorkflowDetailDrawer({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染流程详情抽屉，并在校验失败时展示第一条短中文问题。
  @override
  Widget build(BuildContext context) {
    final workflow = snapshot.workflow;
    final lastRun = snapshot.runHistory.recentRuns.isEmpty
        ? null
        : snapshot.runHistory.recentRuns.first;
    final lastRunAt = lastRun?.finishedAt ?? lastRun?.startedAt;
    final nodeTypes = _workflowNodeTypeSummary(workflow);
    final workflowValidation = _snapshotWorkflowValidation(snapshot);
    return Material(
      key: const ValueKey('dashboard-workflow-detail-drawer'),
      color: StudioColors.panel,
      child: SizedBox(
        width: 440,
        height: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '流程摘要',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '本机流程概览，编辑和运行在对应页面。',
                  style: TextStyle(color: StudioColors.muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    key: const ValueKey('dashboard-workflow-detail-scroll'),
                    children: [
                      _SettingsSection(
                        title: '流程文件',
                        children: [
                          _DrawerField(label: '名称', value: workflow.name),
                          _DrawerField(
                            label: '校验',
                            value: workflowValidation.isValid ? '可运行' : '需修正',
                          ),
                          if (!workflowValidation.isValid)
                            _DrawerField(
                              label: '问题',
                              value: _workflowIssueSummary(workflowValidation),
                            ),
                          _DrawerField(
                            label: '节点',
                            value: '${workflow.nodes.length}',
                          ),
                          _DrawerField(
                            label: '入口节点',
                            value: _workflowNodeDisplayLabel(
                              workflow,
                              workflow.entryNodesId,
                            ),
                          ),
                        ],
                      ),
                      _SettingsSection(
                        title: '节点组成',
                        children: [
                          for (final entry in nodeTypes.entries)
                            _DrawerField(
                              label: entry.key,
                              value: '${entry.value}',
                            ),
                        ],
                      ),
                      _SettingsSection(
                        title: '最近运行',
                        children: [
                          _DrawerField(
                            label: '状态',
                            value: lastRun == null
                                ? '暂无运行'
                                : _runHistoryStatusLabel(lastRun.status),
                          ),
                          _DrawerField(
                            label: '最近运行',
                            value: lastRunAt == null
                                ? '-'
                                : _timeOnly(lastRunAt),
                          ),
                          _DrawerField(
                            label: '成功率',
                            value: _formatPercent(
                              snapshot.runHistory.successRate,
                            ),
                          ),
                        ],
                      ),
                      const _SettingsSection(
                        title: '边界',
                        children: [
                          _DrawerField(label: '范围', value: '只读总览'),
                          _DrawerField(label: '设备动作', value: '无'),
                          _DrawerField(label: '敏感信息', value: '默认隐藏'),
                        ],
                      ),
                    ],
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
