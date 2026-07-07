part of '../../studio_mac_workspace.dart';

// 单条节点轨迹行，负责节点摘要和本地截图证据的按需读取。
class _RunNodeTraceRow extends StatefulWidget {
  const _RunNodeTraceRow({
    required this.runId,
    required this.trace,
    required this.controller,
    required this.revealEvidenceByDefault,
  });

  final String runId;
  final RunNodeTrace trace;
  final StudioRuntimeController controller;
  final bool revealEvidenceByDefault;

  // 创建单行截图 reveal 状态。
  @override
  State<_RunNodeTraceRow> createState() => _RunNodeTraceRowState();
}

class _RunNodeTraceRowState extends State<_RunNodeTraceRow> {
  Future<List<int>?>? _evidenceFuture;
  late bool _expanded;

  // 初始化截图展开状态，默认展开时才读取本地截图。
  @override
  void initState() {
    super.initState();
    final screenshotPath = widget.trace.screenshotPath;
    _expanded = widget.revealEvidenceByDefault && screenshotPath != null;
    if (_expanded && screenshotPath != null) {
      _evidenceFuture = widget.controller.readRunScreenshotEvidence(
        widget.runId,
        screenshotPath,
      );
    }
  }

  // 切换单行截图证据显示，首次展开时读取图片。
  void _toggleEvidence() {
    setState(() {
      _expanded = !_expanded;
      final screenshotPath = widget.trace.screenshotPath;
      if (_expanded && _evidenceFuture == null && screenshotPath != null) {
        _evidenceFuture = widget.controller.readRunScreenshotEvidence(
          widget.runId,
          screenshotPath,
        );
      }
    });
  }

  // 渲染单个节点轨迹行，展示用户可读节点名和状态摘要。
  @override
  Widget build(BuildContext context) {
    final trace = widget.trace;
    return Column(
      key: ValueKey('run-trace-row-${trace.nodeId}-${trace.loopIndex ?? 0}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusPill(
              label: _runTraceStatusLabel(trace),
              tone: _toneForRunTrace(trace),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 68,
              child: Text(
                trace.loopIndex == null ? '-' : '第 ${trace.loopIndex! + 1} 轮',
                style: const TextStyle(color: StudioColors.muted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _monitorNodeDisplayLabel(
                  label: trace.label,
                  nodeType: trace.nodeType,
                ),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: Text(
                _runNodeTypeLabel(trace.nodeType),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: StudioColors.muted),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 76,
              child: Text(
                _formatDuration(trace.duration),
                textAlign: TextAlign.right,
                style: const TextStyle(color: StudioColors.muted),
              ),
            ),
          ],
        ),
        if (trace.screenshotPath != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 92),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const StatusPill(label: '截图证据', tone: StudioStatusTone.running),
                OutlinedButton.icon(
                  key: ValueKey(
                    'screenshot-evidence-toggle-${trace.nodeId}-${trace.loopIndex ?? 0}',
                  ),
                  onPressed: _toggleEvidence,
                  icon: Icon(
                    _expanded ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  label: Text(_expanded ? '隐藏' : '查看'),
                ),
              ],
            ),
          ),
        ],
        if (_expanded && _evidenceFuture != null) ...[
          const SizedBox(height: 10),
          FutureBuilder<List<int>?>(
            future: _evidenceFuture,
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
                      'screenshot-evidence-image-${widget.trace.nodeId}-${widget.trace.loopIndex ?? 0}',
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
      ],
    );
  }
}
