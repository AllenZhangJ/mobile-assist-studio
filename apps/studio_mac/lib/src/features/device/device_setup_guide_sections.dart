part of '../../studio_mac_workspace.dart';

// 设备本机指引分片，承载准备项卡片、复制命令和 V2.0 边界提示。

class _LocalSetupGuideSection extends StatelessWidget {
  const _LocalSetupGuideSection({
    required this.title,
    required this.icon,
    required this.check,
    required this.fallbackSummary,
    required this.fallbackNextStep,
    required this.bullets,
    this.secondaryCheck,
  });

  final String title;
  final IconData icon;
  final LocalDependencyCheck? check;
  final LocalDependencyCheck? secondaryCheck;
  final String fallbackSummary;
  final String fallbackNextStep;
  final List<String> bullets;

  /// 渲染一组本机准备项。
  /// 主检查和次检查都来自脱敏后的 dependency report。
  @override
  Widget build(BuildContext context) {
    final primary = check;
    final secondary = secondaryCheck;
    final tone = primary == null
        ? StudioStatusTone.offline
        : _toneForDependency(primary.status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
        border: Border.all(color: _colorForTone(tone).withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: _colorForTone(tone)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusPill(
                  label: primary == null
                      ? '未知'
                      : _dependencyStatusLabel(primary.status),
                  tone: tone,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              primary?.summary ?? fallbackSummary,
              style: const TextStyle(color: StudioColors.muted, height: 1.4),
            ),
            if (primary?.detail != null) ...[
              const SizedBox(height: 8),
              _ReadinessInlineStep(label: '详情', value: primary!.detail!),
            ],
            const SizedBox(height: 8),
            _ReadinessInlineStep(
              label: '下个',
              value: primary?.nextStep ?? fallbackNextStep,
            ),
            if (secondary != null) ...[
              const SizedBox(height: 8),
              _ReadinessInlineStep(
                label: secondary.label,
                value: _dependencyInlineSummary(secondary),
              ),
            ],
            if (_shouldShowTunnelAction(primary) ||
                _shouldShowTunnelAction(secondary)) ...[
              const SizedBox(height: 8),
              const _LocalSetupCopyCommandButton(command: _iosTunnelCommand),
              const SizedBox(height: 8),
              const _LocalTunnelSteps(),
            ],
            const SizedBox(height: 10),
            for (final bullet in bullets) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: StudioColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
              if (bullet != bullets.last) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

/// 生成依赖检查的内联摘要。
/// 详情为空时只返回短状态，避免出现空括号。
String _dependencyInlineSummary(LocalDependencyCheck check) {
  final detail = check.detail;
  final prefix = '${_dependencyStatusLabel(check.status)} - ${check.summary}';
  if (detail == null || detail.isEmpty) return prefix;
  return '$prefix（$detail）';
}

/// 判断是否展示本机隧道复制命令。
/// 只有隧道缺失或异常时才给出手动动作。
bool _shouldShowTunnelAction(LocalDependencyCheck? check) {
  if (check == null || check.id != 'ios-tunnel') return false;
  return check.status == LocalDependencyStatus.warning ||
      check.status == LocalDependencyStatus.error;
}

class _LocalSetupCopyCommandButton extends StatelessWidget {
  const _LocalSetupCopyCommandButton({required this.command});

  final String command;

  /// 渲染复制命令按钮。
  /// 按钮只写剪贴板，不直接启动命令。
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: const ValueKey('copy-local-tunnel-command'),
        icon: const Icon(Icons.content_copy, size: 16),
        label: const Text('复制隧道'),
        onPressed: () async {
          await _copyPlainText(context, text: command);
        },
      ),
    );
  }
}

class _LocalTunnelSteps extends StatelessWidget {
  const _LocalTunnelSteps();

  /// 渲染本机隧道说明。
  /// 主路径是一键连接，复制命令只作为高级备用。
  @override
  Widget build(BuildContext context) {
    const steps = <String>[
      '点连接设备，输入 Mac 密码。',
      '解锁 iPhone，弹窗时点允许。',
      '应用会继续准备驱动。',
      '成功后即可截图或运行。',
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.cyan.withValues(alpha: 0.06),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '隧道步骤',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < steps.length; index += 1) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${index + 1}.',
                      style: const TextStyle(
                        color: StudioColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: const TextStyle(fontSize: 12, height: 1.35),
                    ),
                  ),
                ],
              ),
              if (index != steps.length - 1) const SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _AndroidSetupCard extends StatelessWidget {
  const _AndroidSetupCard({required this.check});

  final LocalDependencyCheck? check;

  /// 渲染 Android 真机 smoke 的现场准备说明。
  /// 这里只复制安全命令，不启动 ADB、驱动或真机动作。
  @override
  Widget build(BuildContext context) {
    final current = check;
    final tone = current == null
        ? StudioStatusTone.offline
        : _toneForDependency(current.status);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.cyan.withValues(alpha: 0.06),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.android_outlined, size: 17),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '安卓准备',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(
                  label: current == null
                      ? '未知'
                      : _dependencyStatusLabel(current.status),
                  tone: tone,
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('copy-android-smoke-command'),
                  icon: const Icon(Icons.content_copy, size: 16),
                  label: const Text('复制安卓'),
                  onPressed: () async {
                    await _copyPlainText(context, text: _v4AndroidSmokeCommand);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              current?.summary ?? '终验还缺安卓真机留档。',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: StudioColors.muted, height: 1.4),
            ),
            const SizedBox(height: 8),
            _ReadinessInlineStep(
              label: '下个',
              value: current?.nextStep ?? '开 USB 调试，插线并点允许。',
            ),
            if (current?.detail != null) ...[
              const SizedBox(height: 8),
              _ReadinessInlineStep(label: '详情', value: current!.detail!),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const [
                _AndroidSetupStep(label: '开调试'),
                _AndroidSetupStep(label: '插数据线'),
                _AndroidSetupStep(label: '点允许'),
                _AndroidSetupStep(label: '跑安卓'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AndroidSetupStep extends StatelessWidget {
  const _AndroidSetupStep({required this.label});

  final String label;

  /// 渲染 Android 准备短步骤，保持紧凑不撑开抽屉。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.72),
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

class _LocalSetupBoundaryCard extends StatelessWidget {
  const _LocalSetupBoundaryCard();

  /// 渲染 V2.0 本机边界提示。
  /// 用短文案提醒不上传、不绕过系统限制。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.amber.withValues(alpha: 0.07),
        border: Border.all(color: StudioColors.amber.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusPill(label: '边界', tone: StudioStatusTone.warning),
            SizedBox(height: 10),
            Text(
              'V2.0 只做本机工作台。证书和信任只提示，不上传，也不加中间服务。',
              style: TextStyle(color: StudioColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
