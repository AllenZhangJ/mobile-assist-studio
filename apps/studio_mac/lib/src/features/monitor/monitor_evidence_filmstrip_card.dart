part of '../../studio_mac_workspace.dart';

// Monitor 证据胶片卡片，只展示单张截图证据的摘要和 reveal 入口。
class _RunEvidenceFilmstripCard extends StatelessWidget {
  const _RunEvidenceFilmstripCard({
    super.key,
    required this.evidenceRef,
    required this.index,
    required this.revealed,
    required this.onToggle,
  });

  final RunScreenshotEvidenceRef evidenceRef;
  final int index;
  final bool revealed;
  final VoidCallback onToggle;

  // 渲染单张截图证据引用，用户点击后才 reveal 本地图像。
  @override
  Widget build(BuildContext context) {
    final label = _monitorNodeDisplayLabel(
      label: evidenceRef.label,
      nodeType: evidenceRef.nodeType,
      fallback: '截图节点',
    );
    return Container(
      width: 224,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: revealed
            ? StudioColors.cyan.withValues(alpha: 0.12)
            : StudioColors.panel,
        border: Border.all(
          color: revealed ? StudioColors.cyan : StudioColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: _runTraceStatusLabelForStatus(evidenceRef.status),
                tone: _toneForRunTraceStatus(evidenceRef.status),
              ),
              const Spacer(),
              Text(
                evidenceRef.loopIndex == null
                    ? '#${index + 1}'
                    : '第 ${evidenceRef.loopIndex! + 1} 轮',
                style: const TextStyle(color: StudioColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            [
              _runNodeTypeLabel(evidenceRef.nodeType),
              _formatDuration(evidenceRef.duration),
            ].join(' / '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              key: ValueKey(
                'evidence-filmstrip-toggle-${evidenceRef.nodeId}-${evidenceRef.loopIndex ?? index}',
              ),
              onPressed: onToggle,
              icon: Icon(
                revealed ? Icons.visibility_off : Icons.visibility,
                size: 16,
              ),
              label: Text(revealed ? '隐藏' : '查看'),
            ),
          ),
        ],
      ),
    );
  }
}
