part of '../../studio_mac_workspace.dart';

// 设备准备指南组件，负责本机检查、操作步骤和边界提示。
class _LocalSetupGuideDrawer extends StatelessWidget {
  const _LocalSetupGuideDrawer({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  /// 渲染本机准备指引抽屉。
  /// 内容只读展示，不执行安装、签名或外部命令。
  @override
  Widget build(BuildContext context) {
    final report = snapshot.dependencyReport;
    final appium = report.checkById('appium-cli');
    final xcode = report.checkById('xcode-cli');
    final deviceTools = report.checkById('ios-device-tools');
    final tunnel = report.checkById('ios-tunnel');
    final wda = report.checkById('wda-prerequisites');
    return Material(
      color: StudioColors.panel,
      child: SizedBox(
        key: const ValueKey('local-setup-guide-drawer'),
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
                        '本机指引',
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
                  '本机驱动、开发工具、手机会话和信任指引。这里只读，不会自动安装或签名。',
                  style: TextStyle(color: StudioColors.muted, height: 1.4),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusPill(
                      label: '${report.readyCount}/${report.checks.length} 就绪',
                      tone: report.hasError
                          ? StudioStatusTone.error
                          : report.hasWarning
                          ? StudioStatusTone.warning
                          : report.readyCount == report.checks.length &&
                                report.checks.isNotEmpty
                          ? StudioStatusTone.ready
                          : StudioStatusTone.offline,
                    ),
                    StatusPill(
                      label: _dependencyCheckedAt(report),
                      tone: StudioStatusTone.offline,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    key: const ValueKey('local-setup-guide-scroll'),
                    children: [
                      _LocalSetupGuideSection(
                        title: '驱动服务',
                        icon: Icons.terminal_outlined,
                        check: appium,
                        fallbackSummary: '驱动服务由应用统一启停。',
                        fallbackNextStep: '点连接设备，失败再查环境。',
                        bullets: const ['驱动只在本机运行。', '应用直接调用驱动。', '中间不加接口服务。'],
                      ),
                      const SizedBox(height: 12),
                      _LocalSetupGuideSection(
                        title: '开发工具',
                        icon: Icons.developer_board_outlined,
                        check: xcode,
                        secondaryCheck: deviceTools,
                        fallbackSummary: '手机会话需要开发工具和设备工具。',
                        fallbackNextStep: '先打开一次开发工具，选好命令行工具，再连接手机。',
                        bullets: const [
                          '当前仅支持一台有线手机。',
                          '开发者模式和信任仍由用户手动处理。',
                          '主界面只显示摘要，细节在控制台。',
                        ],
                      ),
                      const SizedBox(height: 12),
                      _LocalSetupGuideSection(
                        title: '会话与信任',
                        icon: Icons.verified_user_outlined,
                        check: wda,
                        secondaryCheck: tunnel,
                        fallbackSummary: '手机会话依赖驱动、开发工具、有线连接和信任。',
                        fallbackNextStep: '点连接设备；如有提示请在手机信任。',
                        bullets: const [
                          '应用不绕过信任、签名或开发者模式。',
                          '信任需手动完成，不是运行故障。',
                          '会话只展示摘要。',
                        ],
                      ),
                      const SizedBox(height: 12),
                      const _AndroidSetupCard(),
                      const SizedBox(height: 12),
                      const _LocalSetupBoundaryCard(),
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
