part of '../../studio_mac_workspace.dart';

const String _v4FullSmokeCommand = 'npm run v4:smoke:full';
const String _v4PasswordSmokeCommand = 'npm run v4:smoke:full:password-stdin';
const String _v4AndroidSmokeCommand = 'npm run v4:android-smoke:full';
const String _v4AcceptanceAuditCommand = 'npm run v4:acceptance-audit';

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
            label: '问题记录',
            value: summary.issueLabel,
            tone: summary.issueTone,
          ),
          _V4AcceptanceFact(
            label: '下一步',
            value: summary.nextStepLabel,
            tone: StudioStatusTone.running,
          ),
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
        ],
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
    required this.issueLabel,
    required this.issueTone,
    required this.nextStepLabel,
  });

  final String statusLabel;
  final StudioStatusTone tone;
  final String platformLabel;
  final StudioStatusTone platformTone;
  final String localRunLabel;
  final StudioStatusTone localRunTone;
  final String issueLabel;
  final StudioStatusTone issueTone;
  final String nextStepLabel;

  // 根据当前连接平台和本地历史生成保守验收状态。
  factory _V4AcceptanceStatusSummary.fromSnapshot(
    StudioRuntimeSnapshot snapshot,
  ) {
    final history = snapshot.runHistory;
    final issueRuns =
        history.failedRuns + history.pausedRuns + history.stoppedRuns;
    final hasLocalRuns = history.totalRuns > 0;
    final platform = snapshot.mobileRuntime.platform;
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
      issueLabel: issueRuns > 0 ? '$issueRuns 条' : '无',
      issueTone: issueRuns > 0
          ? StudioStatusTone.warning
          : StudioStatusTone.ready,
      nextStepLabel: _v4NextStepLabel(platform, hasLocalRuns),
    );
  }
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
