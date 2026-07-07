part of '../../studio_mac_workspace.dart';

// 运行详情智能解释面板，通过 Runtime 受控 AI 工具解释本地报告。
class _RunAiExplanationPanel extends StatefulWidget {
  const _RunAiExplanationPanel({
    required this.runId,
    required this.report,
    required this.controller,
  });

  final String runId;
  final RunLocalReport? report;
  final StudioRuntimeController controller;

  // 创建面板本地状态，AI 结果不写入运行详情或报告文件。
  @override
  State<_RunAiExplanationPanel> createState() => _RunAiExplanationPanelState();
}

// 智能解释面板状态，负责一次只发起一个受控工具调用。
class _RunAiExplanationPanelState extends State<_RunAiExplanationPanel> {
  AiToolInvocationResult? _result;
  bool _busy = false;

  // 渲染智能解释入口和最近一次只读结果。
  @override
  Widget build(BuildContext context) {
    final hasReport = widget.report != null;
    final canExplain = hasReport && !_busy;
    return _InsetSurface(
      key: const ValueKey('run-ai-explanation'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '智能解释',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              _CommandButton(
                controlKey: const ValueKey('run-ai-explain-failure'),
                label: _busy ? '生成中' : '解释',
                icon: Icons.psychology_alt_outlined,
                onPressed: canExplain ? _explain : null,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _runAiExplanationIntro(hasReport: hasReport, result: _result),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.4),
          ),
          if (_result != null) ...[
            const SizedBox(height: 10),
            _RunAiExplanationResult(result: _result!),
          ],
        ],
      ),
    );
  }

  // 调用 Runtime AI 工具，保持只读并通过工具门禁审计。
  Future<void> _explain() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.controller.invokeAiTool(
        AiToolInvocationRequest(
          toolId: 'explainRunFailure',
          arguments: <String, Object?>{'runId': widget.runId},
        ),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

// 智能解释结果，只展示脱敏摘要和有限下一步。
class _RunAiExplanationResult extends StatelessWidget {
  const _RunAiExplanationResult({required this.result});

  final AiToolInvocationResult result;

  // 渲染 AI 工具返回的可读摘要。
  @override
  Widget build(BuildContext context) {
    final output = result.output;
    final node = output['node'];
    final reason = output['reason'];
    final nextSteps = output['nextSteps'];
    final steps = nextSteps is List<Object?>
        ? nextSteps.whereType<String>().take(3).toList(growable: false)
        : const <String>[];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.cyan.withValues(alpha: 0.08),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.status == AiToolInvocationStatus.completed
                ? _safeRunAiText(output['summary'], result.message)
                : result.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (node is String && node.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '节点：${node.trim()}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted),
            ),
          ],
          if (reason is String && reason.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '原因：${reason.trim()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted, height: 1.35),
            ),
          ],
          for (final step in steps) ...[
            const SizedBox(height: 6),
            Text(
              '• $step',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

// 生成智能解释空态和结果态说明。
String _runAiExplanationIntro({
  required bool hasReport,
  required AiToolInvocationResult? result,
}) {
  if (!hasReport) return '缺少本地报告，暂时无法解释。';
  if (result == null) return '基于本地报告生成短解释，不读取截图画面。';
  return result.status == AiToolInvocationStatus.completed
      ? '已生成只读解释，结果不会自动修复或重跑。'
      : result.message;
}

// 将 AI 输出字段转成短安全文本。
String _safeRunAiText(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return fallback;
}
