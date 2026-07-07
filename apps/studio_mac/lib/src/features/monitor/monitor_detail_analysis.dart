part of '../../studio_mac_workspace.dart';

// Monitor 运行详情分析分片，负责问题分析和视觉证据链展示。
class _RunFailureAnalysisPanel extends StatelessWidget {
  const _RunFailureAnalysisPanel({required this.analysis});

  final RunFailureAnalysis analysis;

  // 渲染本地问题分析摘要，不展示底层错误 payload。
  @override
  Widget build(BuildContext context) {
    final issueNodes = _monitorNodeDisplayLabel(
      label: analysis.failedNodeLabel,
      nodeType: analysis.failedNodeType,
      fallback: '无',
    );
    final failedLoop = analysis.failedLoopIndex == null
        ? '-'
        : '第 ${analysis.failedLoopIndex! + 1} 轮';
    final category = _analysisCategoryLabel(analysis.category);
    final reason = _analysisReasonLabel(analysis.reason);
    final issueTone = _toneForAnalysisCategory(analysis.category);
    return _InsetSurface(
      key: const ValueKey('run-failure-analysis'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.troubleshoot, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '问题分析',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(label: category, tone: issueTone),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RunDetailChip(
                label: '问题节点',
                value: issueNodes,
                tone: analysis.failedNodeId == null
                    ? StudioStatusTone.ready
                    : issueTone,
              ),
              _RunDetailChip(
                label: '节点类型',
                value: analysis.failedNodeType == null
                    ? '-'
                    : _runNodeTypeLabel(analysis.failedNodeType),
                tone: StudioStatusTone.offline,
              ),
              _RunDetailChip(
                label: '循环',
                value: failedLoop,
                tone: StudioStatusTone.running,
              ),
              _RunDetailChip(
                label: '节点耗时',
                value: _formatDuration(analysis.failedDuration),
                tone: StudioStatusTone.offline,
              ),
              _RunDetailChip(
                label: '证据',
                value: '${analysis.screenshotEvidenceCount} 张截图',
                tone: analysis.screenshotEvidenceCount == 0
                    ? StudioStatusTone.warning
                    : StudioStatusTone.running,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            reason,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted),
          ),
        ],
      ),
    );
  }
}

class _RunVisualEvidenceChainPanel extends StatelessWidget {
  const _RunVisualEvidenceChainPanel({required this.events});

  final List<RunEvidenceEvent> events;

  // 渲染视觉判断证据链，只展示规则、置信度和后续动作摘要。
  @override
  Widget build(BuildContext context) {
    final visualEvents = events
        .where((event) => event.visualEvidence != null)
        .toList(growable: false);
    return _InsetSurface(
      key: const ValueKey('run-visual-evidence-chain'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '视觉证据',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: '${visualEvents.length} 次检查',
                tone: StudioStatusTone.running,
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final event in visualEvents) ...[
            _RunVisualEvidenceRow(event: event),
            if (event != visualEvents.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RunVisualEvidenceRow extends StatelessWidget {
  const _RunVisualEvidenceRow({required this.event});

  final RunEvidenceEvent event;

  // 渲染单次视觉判断结果，低置信或弹窗命中都以暂停语义表达。
  @override
  Widget build(BuildContext context) {
    final evidence = event.visualEvidence!;
    final passed = evidence.result == true;
    final tone = passed ? StudioStatusTone.ready : StudioStatusTone.warning;
    final node = _monitorNodeDisplayLabel(
      label: event.label,
      nodeType: event.nodeType,
      fallback: '视觉检查',
    );
    return Container(
      key: ValueKey(
        'visual-evidence-row-${event.nodeId}-${event.loopIndex ?? 0}',
      ),
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
              StatusPill(label: passed ? '通过' : '暂停', tone: tone),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RunDetailChip(
                label: '规则',
                value: _visualRuleLabel(evidence.rule),
                tone: StudioStatusTone.running,
              ),
              _RunDetailChip(
                label: '截图',
                value: evidence.screenshotAvailable ? '可用' : '缺失',
                tone: evidence.screenshotAvailable
                    ? StudioStatusTone.ready
                    : StudioStatusTone.warning,
              ),
              _RunDetailChip(
                label: '置信度',
                value:
                    '${_formatVisualConfidence(evidence.confidence)} / ${_formatVisualConfidence(evidence.confidenceThreshold)}',
                tone: tone,
              ),
              _RunDetailChip(
                label: '操作',
                value: _visualActionLabel(evidence),
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            evidence.reason,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// 把视觉守卫动作转换为短中文，避免暴露 Runtime 枚举。
String _visualActionLabel(RunVisualEvidence evidence) {
  final action = evidence.action.trim().toLowerCase();
  if (action == 'continue' || evidence.action == '继续') {
    return '继续到下一节点';
  }
  return '暂停确认';
}
