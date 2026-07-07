part of '../../studio_mac_workspace.dart';

// Monitor 截图证据分片，负责证据条、截图 reveal 和本地回放。
class _RunEvidenceFilmstripPanel extends StatefulWidget {
  const _RunEvidenceFilmstripPanel({
    required this.runId,
    required this.evidenceRefs,
    required this.controller,
    required this.revealByDefault,
  });

  final String runId;
  final List<RunScreenshotEvidenceRef> evidenceRefs;
  final StudioRuntimeController controller;
  final bool revealByDefault;

  // 创建截图证据回放状态，只在用户 reveal 后读取截图。
  @override
  State<_RunEvidenceFilmstripPanel> createState() =>
      _RunEvidenceFilmstripPanelState();
}

class _RunEvidenceFilmstripPanelState
    extends State<_RunEvidenceFilmstripPanel> {
  int? _revealedIndex;
  Future<List<int>?>? _evidenceFuture;

  // 初始化截图回放状态，默认显示时才主动读取首张截图。
  @override
  void initState() {
    super.initState();
    if (widget.revealByDefault && widget.evidenceRefs.isNotEmpty) {
      _showEvidence(0);
    }
  }

  // 数据源变化时校正当前索引，避免回放指向已不存在的截图。
  @override
  void didUpdateWidget(covariant _RunEvidenceFilmstripPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final revealedIndex = _revealedIndex;
    if (revealedIndex == null) return;
    if (revealedIndex >= widget.evidenceRefs.length) {
      if (widget.evidenceRefs.isEmpty) {
        _revealedIndex = null;
        _evidenceFuture = null;
        return;
      }
      _showEvidence(widget.evidenceRefs.length - 1);
      return;
    }
    final previousPath = oldWidget.evidenceRefs.length > revealedIndex
        ? oldWidget.evidenceRefs[revealedIndex].relativePath
        : null;
    final nextPath = widget.evidenceRefs[revealedIndex].relativePath;
    if (previousPath != nextPath || oldWidget.runId != widget.runId) {
      _showEvidence(revealedIndex);
    }
  }

  // 打开指定截图并按需读取本地证据。
  void _showEvidence(int index) {
    _revealedIndex = index;
    _evidenceFuture = widget.controller.readRunScreenshotEvidence(
      widget.runId,
      widget.evidenceRefs[index].relativePath,
    );
  }

  // 切换截图可见性，隐藏时不保留图片 Future。
  void _toggleEvidence(int index) {
    setState(() {
      if (_revealedIndex == index) {
        _revealedIndex = null;
        _evidenceFuture = null;
        return;
      }
      _showEvidence(index);
    });
  }

  // 在已显示的截图之间移动，边界处保持不动。
  void _moveEvidence(int delta) {
    final revealedIndex = _revealedIndex;
    if (revealedIndex == null) return;
    final nextIndex = (revealedIndex + delta).clamp(
      0,
      widget.evidenceRefs.length - 1,
    );
    if (nextIndex == revealedIndex) return;
    setState(() {
      _showEvidence(nextIndex);
    });
  }

  // 构建截图索引、胶片和回放区。
  @override
  Widget build(BuildContext context) {
    if (widget.evidenceRefs.isEmpty) {
      return const _InsetSurface(
        key: ValueKey('run-evidence-filmstrip-empty'),
        width: double.infinity,
        child: Row(
          children: [
            Icon(Icons.photo_library_outlined, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '证据条',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
            StatusPill(label: '暂无截图', tone: StudioStatusTone.offline),
          ],
        ),
      );
    }

    final revealedIndex = _revealedIndex;
    final revealedRef = revealedIndex == null
        ? null
        : widget.evidenceRefs[revealedIndex];
    return _InsetSurface(
      key: const ValueKey('run-evidence-filmstrip'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_outlined, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '证据条',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: '${widget.evidenceRefs.length} 张截图',
                tone: StudioStatusTone.running,
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 156,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.evidenceRefs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final ref = widget.evidenceRefs[index];
                final isRevealed = revealedIndex == index;
                return _RunEvidenceFilmstripCard(
                  key: ValueKey(
                    'evidence-filmstrip-card-${ref.nodeId}-${ref.loopIndex ?? index}',
                  ),
                  evidenceRef: ref,
                  index: index,
                  revealed: isRevealed,
                  onToggle: () => _toggleEvidence(index),
                );
              },
            ),
          ),
          if (revealedIndex != null &&
              revealedRef != null &&
              _evidenceFuture != null) ...[
            const SizedBox(height: 12),
            _RunEvidenceReplayPanel(
              ref: revealedRef,
              index: revealedIndex,
              total: widget.evidenceRefs.length,
              evidenceFuture: _evidenceFuture!,
              onPrevious: revealedIndex == 0 ? null : () => _moveEvidence(-1),
              onNext: revealedIndex == widget.evidenceRefs.length - 1
                  ? null
                  : () => _moveEvidence(1),
            ),
          ],
        ],
      ),
    );
  }
}
