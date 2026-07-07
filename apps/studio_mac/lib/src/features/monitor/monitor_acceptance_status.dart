part of '../../studio_mac_workspace.dart';

// V4 验收入口只展示本地线索和复制命令，不直接启动真机动作。
class _V4AcceptanceStatusPanel extends StatelessWidget {
  const _V4AcceptanceStatusPanel({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 组合 V4 验收状态、当前平台和命令复制入口。
  @override
  Widget build(BuildContext context) {
    final summary = _V4AcceptanceStatusSummary.fromSnapshot(snapshot);
    return _Surface(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          const Text(
            'V4 验收',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          StatusPill(label: summary.statusLabel, tone: summary.tone),
          _V4AcceptanceFact(
            label: '当前平台',
            value: summary.platformLabel,
            tone: summary.platformTone,
          ),
          _V4AcceptanceFact(
            label: '本地记录',
            value: summary.localRunLabel,
            tone: summary.localRunTone,
          ),
          _V4AcceptanceFact(
            label: '安卓留档',
            value: summary.androidRunLabel,
            tone: summary.androidRunTone,
          ),
          _V4AcceptanceFact(
            label: '问题记录',
            value: summary.issueLabel,
            tone: summary.issueTone,
          ),
          _V4AcceptanceFact(
            label: '下一步',
            value: summary.nextStepLabel,
            tone: StudioStatusTone.running,
          ),
          _V4AcceptanceRouteCard(summary: summary),
          _CommandButton(
            controlKey: const ValueKey('monitor-copy-v4-full-smoke'),
            label: '复制全量',
            icon: Icons.verified_outlined,
            onPressed: () => _copyPlainText(
              context,
              text: _v4FullSmokeCommand,
              message: '全量命令已复制',
            ),
          ),
          _CommandButton(
            controlKey: const ValueKey('monitor-copy-v4-password-smoke'),
            label: '复制密码版',
            icon: Icons.lock_outline,
            onPressed: () => _copyPlainText(
              context,
              text: _v4PasswordSmokeCommand,
              message: '密码版命令已复制',
            ),
          ),
          _CommandButton(
            controlKey: const ValueKey('monitor-copy-v4-android-smoke'),
            label: '复制安卓',
            icon: Icons.android_outlined,
            onPressed: () => _copyPlainText(
              context,
              text: _v4AndroidSmokeCommand,
              message: '安卓命令已复制',
            ),
          ),
          _CommandButton(
            controlKey: const ValueKey('monitor-copy-v4-acceptance-audit'),
            label: '复制审计',
            icon: Icons.fact_check_outlined,
            onPressed: () => _copyPlainText(
              context,
              text: _v4AcceptanceAuditCommand,
              message: '审计命令已复制',
            ),
          ),
          _CommandButton(
            controlKey: const ValueKey('monitor-copy-v4-acceptance-final'),
            label: '复制终验',
            icon: Icons.task_alt_outlined,
            onPressed: () => _copyPlainText(
              context,
              text: _v4AcceptanceFinalCommand,
              message: '终验命令已复制',
            ),
          ),
        ],
      ),
    );
  }
}

// V4AcceptanceRouteCard 展示现场最短路线，避免用户在多条命令间迷路。
class _V4AcceptanceRouteCard extends StatelessWidget {
  const _V4AcceptanceRouteCard({required this.summary});

  final _V4AcceptanceStatusSummary summary;

  // 渲染 Android 到终验的本地路线，只复制命令不直接执行。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 274,
      child: _InsetSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.route_outlined, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '现场路线',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                _CommandButton(
                  controlKey: const ValueKey('monitor-copy-v4-route'),
                  label: '复制路线',
                  icon: Icons.copy_all_outlined,
                  onPressed: () => _copyPlainText(
                    context,
                    text: _v4AcceptanceRouteCommands,
                    message: '路线已复制',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              summary.routeHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const [
                _V4AcceptanceRouteStep(label: '接安卓'),
                _V4AcceptanceRouteStep(label: '跑安卓'),
                _V4AcceptanceRouteStep(label: '跑全量'),
                _V4AcceptanceRouteStep(label: '终验'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// V4AcceptanceRouteStep 是路线中的短步骤胶囊。
class _V4AcceptanceRouteStep extends StatelessWidget {
  const _V4AcceptanceRouteStep({required this.label});

  final String label;

  // 渲染固定宽度短步骤，防止中文换行撑开验收卡。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.82),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

// V4AcceptanceFact 是验收卡里的紧凑事实块。
class _V4AcceptanceFact extends StatelessWidget {
  const _V4AcceptanceFact({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;

  // 渲染单个短指标，使用固定宽度避免中文文案撑开布局。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);
    return SizedBox(
      width: 118,
      child: _InsetSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// V4AcceptanceStatusSummary 从 Runtime 快照派生 UI 状态，不读取文件或设备。
final class _V4AcceptanceStatusSummary {
  const _V4AcceptanceStatusSummary({
    required this.statusLabel,
    required this.tone,
    required this.platformLabel,
    required this.platformTone,
    required this.localRunLabel,
    required this.localRunTone,
    required this.androidRunLabel,
    required this.androidRunTone,
    required this.issueLabel,
    required this.issueTone,
    required this.nextStepLabel,
    required this.routeHint,
  });

  final String statusLabel;
  final StudioStatusTone tone;
  final String platformLabel;
  final StudioStatusTone platformTone;
  final String localRunLabel;
  final StudioStatusTone localRunTone;
  final String androidRunLabel;
  final StudioStatusTone androidRunTone;
  final String issueLabel;
  final StudioStatusTone issueTone;
  final String nextStepLabel;
  final String routeHint;

  // 根据当前连接平台和本地历史生成保守验收状态。
  factory _V4AcceptanceStatusSummary.fromSnapshot(
    StudioRuntimeSnapshot snapshot,
  ) {
    final history = snapshot.runHistory;
    final issueRuns =
        history.failedRuns + history.pausedRuns + history.stoppedRuns;
    final hasLocalRuns = history.totalRuns > 0;
    final platform = snapshot.mobileRuntime.platform;
    final acceptance = snapshot.v4AcceptanceSummary;
    if (acceptance.hasReport) {
      return _V4AcceptanceStatusSummary(
        statusLabel: acceptance.complete ? '已完成' : '未完成',
        tone: acceptance.complete
            ? StudioStatusTone.ready
            : acceptance.auditOk
            ? StudioStatusTone.warning
            : StudioStatusTone.error,
        platformLabel: _v4PlatformLabel(platform),
        platformTone: _v4PlatformTone(platform),
        localRunLabel: 'iOS ${acceptance.iosRuns}',
        localRunTone: acceptance.iosRuns > 0
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
        androidRunLabel: '安卓 ${acceptance.androidRuns}',
        androidRunTone: acceptance.androidRuns > 0
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
        issueLabel: acceptance.failures.isEmpty
            ? '无'
            : '${acceptance.failures.length} 条',
        issueTone: acceptance.failures.isEmpty
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
        nextStepLabel: _v4AcceptanceNextStepLabel(acceptance),
        routeHint: _v4AcceptanceRouteHint(acceptance),
      );
    }
    return _V4AcceptanceStatusSummary(
      statusLabel: hasLocalRuns ? '待终验' : '待留档',
      tone: issueRuns > 0
          ? StudioStatusTone.warning
          : hasLocalRuns
          ? StudioStatusTone.running
          : StudioStatusTone.offline,
      platformLabel: _v4PlatformLabel(platform),
      platformTone: _v4PlatformTone(platform),
      localRunLabel: hasLocalRuns ? '${history.totalRuns} 条' : '暂无',
      localRunTone: hasLocalRuns
          ? StudioStatusTone.ready
          : StudioStatusTone.offline,
      androidRunLabel: '未知',
      androidRunTone: StudioStatusTone.offline,
      issueLabel: issueRuns > 0 ? '$issueRuns 条' : '无',
      issueTone: issueRuns > 0
          ? StudioStatusTone.warning
          : StudioStatusTone.ready,
      nextStepLabel: _v4NextStepLabel(platform, hasLocalRuns),
      routeHint: _v4RouteHint(platform),
    );
  }
}

// 根据终验报告给出短下一步，避免把长命令挤进指标卡。
String _v4AcceptanceNextStepLabel(V4AcceptanceSummary acceptance) {
  if (acceptance.complete) return '已完成';
  if (!acceptance.hasAndroidRun) return '补安卓';
  if (acceptance.fullSmokeReports == 0 ||
      acceptance.latestFullSmokeLabel != '完整通过') {
    return '跑全量';
  }
  return '跑终验';
}

// 根据终验报告给现场路线卡生成短提示。
String _v4AcceptanceRouteHint(V4AcceptanceSummary acceptance) {
  if (acceptance.complete) return '终验已完成。';
  if (!acceptance.hasAndroidRun) {
    final detail = acceptance.androidDetail;
    if (detail.isNotEmpty && detail != '无安卓状态。') return detail;
    return '接安卓，开调试，点允许。';
  }
  if (acceptance.latestFullSmokeLabel != '完整通过') return '再跑全量 smoke。';
  return '补齐后跑最终验收。';
}

// 将移动平台转成用户可读短标签。
String _v4PlatformLabel(MobilePlatform platform) {
  return switch (platform) {
    MobilePlatform.ios => 'iOS',
    MobilePlatform.android => '安卓',
    MobilePlatform.unknown => '未连',
  };
}

// 将移动平台转成状态色，未知平台不标记为通过。
StudioStatusTone _v4PlatformTone(MobilePlatform platform) {
  return switch (platform) {
    MobilePlatform.ios || MobilePlatform.android => StudioStatusTone.ready,
    MobilePlatform.unknown => StudioStatusTone.offline,
  };
}

// 根据当前平台和历史记录给出最短下一步提示。
String _v4NextStepLabel(MobilePlatform platform, bool hasLocalRuns) {
  if (platform == MobilePlatform.android) return '跑安卓';
  if (platform == MobilePlatform.ios) return hasLocalRuns ? '跑全量' : '先冒烟';
  return '先连接';
}

// 根据当前平台给出现场路线里的短提示。
String _v4RouteHint(MobilePlatform platform) {
  return switch (platform) {
    MobilePlatform.android => '保持亮屏，先跑安卓。',
    MobilePlatform.ios => '补安卓后，再跑全量。',
    MobilePlatform.unknown => '接安卓，开调试，点允许。',
  };
}
