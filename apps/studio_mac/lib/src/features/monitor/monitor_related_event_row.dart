part of '../../studio_mac_workspace.dart';

// Monitor 相关事件行分片，负责单条事件的脱敏展示。
// 节点名称和事件摘要继续复用 shared helper，不直接展示底层枚举。

// 单条相关事件行，展示时间、状态、轮次、节点和短摘要。
class _RunRelatedEventRow extends StatelessWidget {
  const _RunRelatedEventRow({required this.event});

  final RunEvidenceEvent event;

  // 渲染单条相关事件，隐藏底层 payload 并保留短摘要。
  @override
  Widget build(BuildContext context) {
    final status = event.status;
    final nodeLabel = _monitorNodeDisplayLabel(
      label: event.label,
      nodeType: event.nodeType,
      fallback: '运行',
    );
    final summary = _runEventSummary(event);
    return Container(
      key: ValueKey(
        'run-event-row-${event.type}-${event.nodeId ?? 'run'}-${event.loopIndex ?? '无'}-${event.status ?? '无'}',
      ),
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              event.at == null ? '-' : _timeOnly(event.at!),
              style: const TextStyle(
                color: StudioColors.muted,
                fontFamily: 'Menlo',
                fontSize: 12,
              ),
            ),
          ),
          StatusPill(
            label: status == null
                ? _runEventTypeLabel(event.type)
                : _runTraceStatusLabelForStatus(status),
            tone: _toneForRunEvent(event),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              event.loopIndex == null ? '-' : '第 ${event.loopIndex! + 1} 轮',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nodeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StudioColors.muted,
                    fontFamily: 'Menlo',
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              event.nodeType == null
                  ? _runEventTypeLabel(event.type)
                  : _runNodeTypeLabel(event.nodeType),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}
