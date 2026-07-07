part of '../../studio_mac_workspace.dart';

// Monitor 截图回放区，负责单张 evidence 的加载状态、图片展示和前后切换。
class _RunEvidenceReplayPanel extends StatelessWidget {
  const _RunEvidenceReplayPanel({
    required this.ref,
    required this.index,
    required this.total,
    required this.evidenceFuture,
    required this.onPrevious,
    required this.onNext,
  });

  final RunScreenshotEvidenceRef ref;
  final int index;
  final int total;
  final Future<List<int>?> evidenceFuture;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  // 构建单张截图回放区，显示索引和前后切换控制。
  @override
  Widget build(BuildContext context) {
    final label = _monitorNodeDisplayLabel(
      label: ref.label,
      nodeType: ref.nodeType,
      fallback: '截图节点',
    );
    return Container(
      key: const ValueKey('run-evidence-replay'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.62),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.slideshow_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '截图回放',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: '第 ${index + 1}/$total 张',
                tone: StudioStatusTone.running,
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                key: const ValueKey('evidence-replay-previous'),
                tooltip: '上一张',
                onPressed: onPrevious,
                icon: const Icon(Icons.chevron_left, size: 18),
              ),
              const SizedBox(width: 6),
              IconButton.outlined(
                key: const ValueKey('evidence-replay-next'),
                tooltip: '下一张',
                onPressed: onNext,
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<int>?>(
            future: evidenceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _EvidencePreviewFrame(
                  child: Text(
                    '加载证据...',
                    style: TextStyle(color: StudioColors.muted),
                  ),
                );
              }
              final bytes = snapshot.data;
              if (bytes == null || bytes.isEmpty) {
                return const _EvidencePreviewFrame(
                  child: Text(
                    '证据不可用',
                    style: TextStyle(color: StudioColors.muted),
                  ),
                );
              }
              return _EvidencePreviewFrame(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.memory(
                    Uint8List.fromList(bytes),
                    key: ValueKey(
                      'evidence-filmstrip-image-${ref.nodeId}-${ref.loopIndex ?? index}',
                    ),
                    height: 220,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
