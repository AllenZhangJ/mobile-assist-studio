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
            label: '批次',
            value: summary.batchProgressLabel,
            tone: summary.batchProgressTone,
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
              text: _v4PromptSmokeCommand,
              message: '密码版命令已复制',
            ),
          ),
          _CommandButton(
            controlKey: const ValueKey('monitor-copy-v4-ios-password-smoke'),
            label: '复制iOS',
            icon: Icons.phone_iphone_outlined,
            onPressed: () => _copyPlainText(
              context,
              text: _v4IosPromptSmokeCommand,
              message: 'iOS 命令已复制',
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
                    text: summary.routeCommands,
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
              children: [
                for (final step in summary.routeSteps)
                  _V4AcceptanceRouteStep(label: step),
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
    required this.batchProgressLabel,
    required this.batchProgressTone,
    required this.androidRunLabel,
    required this.androidRunTone,
    required this.issueLabel,
    required this.issueTone,
    required this.nextStepLabel,
    required this.routeHint,
    required this.routeCommands,
    required this.routeSteps,
  });

  final String statusLabel;
  final StudioStatusTone tone;
  final String platformLabel;
  final StudioStatusTone platformTone;
  final String localRunLabel;
  final StudioStatusTone localRunTone;
  final String batchProgressLabel;
  final StudioStatusTone batchProgressTone;
  final String androidRunLabel;
  final StudioStatusTone androidRunTone;
  final String issueLabel;
  final StudioStatusTone issueTone;
  final String nextStepLabel;
  final String routeHint;
  final String routeCommands;
  final List<String> routeSteps;

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
        batchProgressLabel: acceptance.batchProgressLabel,
        batchProgressTone: _v4BatchProgressTone(acceptance),
        androidRunLabel: '安卓 ${acceptance.androidRuns}',
        androidRunTone: acceptance.androidRuns > 0
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
        issueLabel: acceptance.gateGaps.isNotEmpty
            ? '${acceptance.gateGaps.length} 条'
            : acceptance.failures.isEmpty
            ? '无'
            : '${acceptance.failures.length} 条',
        issueTone: acceptance.gateGaps.isEmpty && acceptance.failures.isEmpty
            ? StudioStatusTone.ready
            : StudioStatusTone.warning,
        nextStepLabel: _v4AcceptanceNextStepLabel(acceptance),
        routeHint: _v4AcceptanceRouteHint(acceptance),
        routeCommands: _v4AcceptanceRouteCommandsFor(acceptance),
        routeSteps: _v4AcceptanceRouteStepsFor(acceptance),
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
      batchProgressLabel: '未读',
      batchProgressTone: StudioStatusTone.offline,
      androidRunLabel: '未知',
      androidRunTone: StudioStatusTone.offline,
      issueLabel: issueRuns > 0 ? '$issueRuns 条' : '无',
      issueTone: issueRuns > 0
          ? StudioStatusTone.warning
          : StudioStatusTone.ready,
      nextStepLabel: _v4NextStepLabel(platform, hasLocalRuns),
      routeHint: _v4RouteHint(platform),
      routeCommands: _v4AcceptanceRouteCommands,
      routeSteps: const ['接安卓', '跑安卓', '跑全量', '终验'],
    );
  }
}

// 根据批次进度给出短状态色，旧报告缺少批次时降级为离线。
StudioStatusTone _v4BatchProgressTone(V4AcceptanceSummary acceptance) {
  if (acceptance.totalBatchCount == 0) return StudioStatusTone.offline;
  if (acceptance.completedBatchCount == acceptance.totalBatchCount) {
    return StudioStatusTone.ready;
  }
  return StudioStatusTone.warning;
}

// 根据终验报告给出短下一步，避免把长命令挤进指标卡。
String _v4AcceptanceNextStepLabel(V4AcceptanceSummary acceptance) {
  if (acceptance.complete) return '已完成';
  if (acceptance.fieldChecklist.isNotEmpty) {
    return _v4ChecklistStepLabel(acceptance.fieldChecklist.first.title);
  }
  if (_v4AcceptanceNeedsIosTunnel(acceptance)) return '补iOS';
  if (_v4AcceptanceNeedsIosSmoke(acceptance)) return '跑iOS';
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
  if (acceptance.fieldChecklist.isNotEmpty) {
    return _v4ChecklistRouteHint(acceptance.fieldChecklist.first.title);
  }
  if (_v4AcceptanceNeedsIosTunnel(acceptance)) return '先补 iOS 隧道，再接安卓。';
  if (_v4AcceptanceNeedsIosSmoke(acceptance)) return '先补 iOS 冒烟。';
  if (!acceptance.hasAndroidRun) {
    final detail = acceptance.androidDetail;
    if (detail.isNotEmpty && detail != '无安卓状态。') return detail;
    return '接安卓，开调试，点允许。';
  }
  if (acceptance.latestFullSmokeLabel != '完整通过') return '再跑全量 smoke。';
  return '补齐后跑最终验收。';
}

// 判断终验下一步是否要求先补 iOS 隧道。
bool _v4AcceptanceNeedsIosTunnel(V4AcceptanceSummary acceptance) {
  return acceptance.nextSteps.any(
    (step) =>
        step.contains(_v4IosPromptSmokeCommand) ||
        step.contains(_v4IosPasswordSmokeCommand),
  );
}

// 判断终验下一步是否要求补 iOS 单平台冒烟。
bool _v4AcceptanceNeedsIosSmoke(V4AcceptanceSummary acceptance) {
  return acceptance.nextSteps.any((step) => step.contains(_v4IosSmokeCommand));
}

// 由终验报告里的下一步命令生成现场路线，避免 UI 和报告互相漂移。
String _v4AcceptanceRouteCommandsFor(V4AcceptanceSummary acceptance) {
  final commands = <String>[];
  void addCommand(String command) {
    if (!commands.contains(command)) commands.add(command);
  }

  for (final item in acceptance.fieldChecklist) {
    final command = item.command;
    if (command != null) addCommand(command);
  }
  if (commands.isNotEmpty) return commands.join('\n');

  if (_v4AcceptanceNeedsIosTunnel(acceptance)) {
    addCommand(_v4IosPromptSmokeCommand);
  } else if (_v4AcceptanceNeedsIosSmoke(acceptance)) {
    addCommand(_v4IosSmokeCommand);
  }
  if (acceptance.nextSteps.any(
        (step) => step.contains(_v4AndroidSmokeCommand),
      ) ||
      !acceptance.hasAndroidRun) {
    addCommand(_v4AndroidSmokeCommand);
  }
  if (acceptance.nextSteps.any((step) => step.contains(_v4FullSmokeCommand)) ||
      acceptance.latestFullSmokeLabel != '完整通过') {
    addCommand(_v4FullSmokeCommand);
  }
  addCommand(_v4AcceptanceFinalCommand);
  return commands.join('\n');
}

// 生成短步骤胶囊，保持中文简短且允许自动换行。
List<String> _v4AcceptanceRouteStepsFor(V4AcceptanceSummary acceptance) {
  final steps = <String>[];
  void addStep(String label) {
    if (!steps.contains(label)) steps.add(label);
  }

  for (final item in acceptance.fieldChecklist) {
    addStep(_v4ChecklistStepLabel(item.title));
  }
  if (steps.isNotEmpty) return List<String>.unmodifiable(steps);

  if (_v4AcceptanceNeedsIosTunnel(acceptance)) {
    addStep('连iOS');
    addStep('跑iOS');
  } else if (_v4AcceptanceNeedsIosSmoke(acceptance)) {
    addStep('跑iOS');
  }
  if (!acceptance.hasAndroidRun ||
      acceptance.nextSteps.any(
        (step) => step.contains(_v4AndroidSmokeCommand),
      )) {
    addStep('接安卓');
    addStep('跑安卓');
  }
  if (acceptance.latestFullSmokeLabel != '完整通过' ||
      acceptance.nextSteps.any((step) => step.contains(_v4FullSmokeCommand))) {
    addStep('跑全量');
  }
  addStep('终验');
  return List<String>.unmodifiable(steps);
}

// 将终验清单标题压缩成路线胶囊短文案。
String _v4ChecklistStepLabel(String title) {
  final normalized = title.replaceAll(' ', '').replaceAll('Android', '安卓');
  if (normalized.contains('iOS')) return '补iOS';
  if (normalized.contains('安卓')) return '补安卓';
  if (normalized.contains('全量')) return '跑全量';
  if (normalized.contains('终验')) return '终验';
  if (normalized.length <= 4) return normalized;
  return normalized.substring(0, 4);
}

// 将终验清单首项转成用户能扫读的一句话。
String _v4ChecklistRouteHint(String title) {
  final label = _v4ChecklistStepLabel(title);
  return switch (label) {
    '补iOS' => '按清单先补 iOS。',
    '补安卓' => '按清单先补安卓。',
    '跑全量' => '按清单跑全量。',
    '终验' => '按清单做终验。',
    _ => '按终验清单继续。',
  };
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
