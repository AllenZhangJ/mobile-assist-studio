part of '../../studio_mac_workspace.dart';

// 本地报告面板，负责把 Runtime RunLocalReport 转成用户可扫读的复盘信息。
class _RunLocalReportPanel extends StatelessWidget {
  const _RunLocalReportPanel({required this.report});

  final RunLocalReport report;

  // 渲染报告摘要、问题、事件统计和少量视觉检查，不读取截图文件。
  @override
  Widget build(BuildContext context) {
    final issueTone = _toneForAnalysisCategory(report.issue.category);
    final issueNode = _reportIssueNodeLabel(report.issue);
    return _InsetSurface(
      key: const ValueKey('run-local-report-panel'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '本地报告',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: _runStatusLabelFromText(report.overview.status),
                tone: _toneForRunStatus(report.overview.status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RunDetailChip(
                label: '路径',
                value:
                    '${report.overview.completedSteps}/${report.overview.totalSteps}',
                tone: report.overview.totalSteps == 0
                    ? StudioStatusTone.offline
                    : StudioStatusTone.ready,
              ),
              _RunDetailChip(
                label: '视觉',
                value: '${report.overview.visualCheckCount}',
                tone: report.overview.visualCheckCount == 0
                    ? StudioStatusTone.offline
                    : StudioStatusTone.running,
              ),
              _RunDetailChip(
                label: '截图',
                value: '${report.overview.screenshotCount}',
                tone: report.overview.screenshotCount == 0
                    ? StudioStatusTone.offline
                    : StudioStatusTone.running,
              ),
              _RunDetailChip(
                label: '问题',
                value: _analysisCategoryLabel(report.issue.category),
                tone: issueTone,
              ),
              _RunDetailChip(
                label: '节点',
                value: issueNode,
                tone: issueNode == '无' ? StudioStatusTone.ready : issueTone,
              ),
              _RunDetailChip(
                label: '事件',
                value: '${report.logSummary.totalEvents}',
                tone: report.logSummary.errorEvents == 0
                    ? StudioStatusTone.ready
                    : StudioStatusTone.warning,
              ),
              _RunDetailChip(
                label: '平台',
                value: _reportPlatformLabel(report.platform.platform),
                tone: _reportPlatformTone(report.platform.platform),
              ),
              _RunDetailChip(
                label: '日志',
                value: '${report.platform.logCount}',
                tone: report.platform.logCount == 0
                    ? StudioStatusTone.offline
                    : StudioStatusTone.running,
              ),
              if (report.platform.deviceName != null)
                _RunDetailChip(
                  label: '设备',
                  value: report.platform.deviceName!,
                  tone: StudioStatusTone.running,
                ),
            ],
          ),
          if (report.issue.reason != null) ...[
            const SizedBox(height: 10),
            Text(
              _analysisReasonLabel(report.issue.reason),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            report.platform.hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.4),
          ),
          if (report.visualChecks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _RunReportVisualCheckStrip(checks: report.visualChecks),
          ],
        ],
      ),
    );
  }
}

// 复制报告按钮，导出 Runtime 已脱敏的本地报告 JSON。
class _RunReportCopyButton extends StatelessWidget {
  const _RunReportCopyButton({required this.report});

  final RunLocalReport? report;

  // 渲染报告复制入口；缺少报告时禁用，避免导出弱数据。
  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('copy-run-report-json'),
      tooltip: '复制报告',
      onPressed: report == null ? null : () => _copyReport(context),
      icon: const Icon(Icons.file_copy_outlined),
    );
  }

  // 复制脱敏 JSON，交给用户本地保存或发给 AI 读取。
  Future<void> _copyReport(BuildContext context) async {
    final currentReport = report;
    if (currentReport == null) return;
    await _copyPlainText(
      context,
      text: _runReportJson(currentReport),
      message: '已复制报告。',
    );
  }
}

// 保存报告按钮，委托 Runtime 写入本地脱敏 JSON 文件。
class _RunReportExportButton extends StatefulWidget {
  const _RunReportExportButton({
    required this.runId,
    required this.report,
    required this.controller,
  });

  final String runId;
  final RunLocalReport? report;
  final StudioRuntimeController controller;

  // 创建保存按钮状态，避免重复点击产生并发导出。
  @override
  State<_RunReportExportButton> createState() => _RunReportExportButtonState();
}

// 保存报告按钮状态，只管理导出中的短暂 UI 状态。
class _RunReportExportButtonState extends State<_RunReportExportButton> {
  bool _exporting = false;

  // 渲染报告保存入口；缺少报告或导出中时禁用。
  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('export-run-report-json'),
      tooltip: _exporting ? '保存中' : '存报告',
      onPressed: widget.report == null || _exporting ? null : _exportReport,
      icon: Icon(_exporting ? Icons.hourglass_top : Icons.save_alt_outlined),
    );
  }

  // 调用 Runtime 导出报告，只展示安全相对文件名。
  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await widget.controller.exportRunReport(widget.runId);
    if (!mounted) return;
    setState(() => _exporting = false);
    messenger?.clearSnackBars();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(result == null ? '报告未存。' : '报告已存：${result.relativePath}'),
      ),
    );
  }
}

// 视觉检查条带，限制行数避免报告面板撑爆抽屉。
class _RunReportVisualCheckStrip extends StatelessWidget {
  const _RunReportVisualCheckStrip({required this.checks});

  final List<RunReportVisualCheck> checks;

  // 渲染最多三条视觉检查摘要，完整细节仍在视觉证据链里查看。
  @override
  Widget build(BuildContext context) {
    final visibleChecks = checks.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '视觉复盘',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            StatusPill(
              label: '${checks.length} 次',
              tone: StudioStatusTone.running,
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final check in visibleChecks) ...[
          _RunReportVisualCheckRow(check: check),
          if (check != visibleChecks.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

// 单条视觉检查摘要，展示节点、置信度、动作和短原因。
class _RunReportVisualCheckRow extends StatelessWidget {
  const _RunReportVisualCheckRow({required this.check});

  final RunReportVisualCheck check;

  // 渲染视觉检查行，低置信和未命中都用提醒色表达。
  @override
  Widget build(BuildContext context) {
    final passed = check.result == true;
    final tone = passed ? StudioStatusTone.ready : StudioStatusTone.warning;
    final node = _monitorNodeDisplayLabel(
      label: check.label,
      nodeType: check.nodeType,
      fallback: '视觉检查',
    );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.64),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(label: passed ? '通过' : '待看', tone: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                _formatVisualConfidence(check.confidence),
                style: const TextStyle(color: StudioColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _reportVisualReason(check),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// 生成报告导出 JSON，只使用 Runtime 报告模型的脱敏输出。
String _runReportJson(RunLocalReport report) {
  return const JsonEncoder.withIndent('  ').convert(report.toJson());
}

// 把报告问题节点转成短中文，避免主界面暴露底层 node id。
String _reportIssueNodeLabel(RunReportIssue issue) {
  return _monitorNodeDisplayLabel(
    label: issue.nodeLabel,
    nodeType: issue.nodeType,
    fallback: issue.nodeId == null ? '无' : '节点',
  );
}

// 把视觉报告原因压缩成用户能看懂的短句。
String _reportVisualReason(RunReportVisualCheck check) {
  final action = check.action.trim().toLowerCase();
  final prefix = action == 'continue' || check.action == '继续' ? '继续' : '暂停';
  return '$prefix：${check.reason}';
}

// 把平台字段转成短中文，旧记录显示未知。
String _reportPlatformLabel(String platform) {
  switch (platform) {
    case 'ios':
      return 'iOS';
    case 'android':
      return '安卓';
    default:
      return '未知';
  }
}

// 平台识别成功用运行色，旧记录保持离线色。
StudioStatusTone _reportPlatformTone(String platform) {
  return platform == 'unknown'
      ? StudioStatusTone.offline
      : StudioStatusTone.running;
}
