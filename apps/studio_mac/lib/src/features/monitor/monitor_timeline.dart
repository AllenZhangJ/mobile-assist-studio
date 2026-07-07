part of '../../studio_mac_workspace.dart';

// 节点时间轴组件，负责节点轨迹、截图预览和空状态展示。
class _RunNodeTraceTimeline extends StatefulWidget {
  const _RunNodeTraceTimeline({
    required this.runId,
    required this.traces,
    required this.controller,
    required this.revealEvidenceByDefault,
    required this.focusNodeId,
  });

  final String runId;
  final List<RunNodeTrace> traces;
  final StudioRuntimeController controller;
  final bool revealEvidenceByDefault;
  final String? focusNodeId;

  // 创建节点时间轴内部筛选状态。
  @override
  State<_RunNodeTraceTimeline> createState() => _RunNodeTraceTimelineState();
}

class _RunNodeTraceTimelineState extends State<_RunNodeTraceTimeline> {
  _RunTraceFilter _filter = _RunTraceFilter.all;

  // 渲染节点轨迹列表，筛选只影响当前详情抽屉。
  @override
  Widget build(BuildContext context) {
    if (widget.traces.isEmpty) return const _RunDetailEmptyState();
    final visibleTraces = _filterRunNodeTraces(widget.traces, _filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RunTraceFilterBar(
          selected: _filter,
          traces: widget.traces,
          onSelected: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: 10),
        if (visibleTraces.isEmpty)
          const _RunDetailEmptyState(message: '无匹配节点')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visibleTraces.length,
            separatorBuilder: (_, _) =>
                const Divider(color: StudioColors.border),
            itemBuilder: (context, index) {
              final trace = visibleTraces[index];
              return _RunNodeTraceRow(
                runId: widget.runId,
                trace: trace,
                controller: widget.controller,
                revealEvidenceByDefault: widget.revealEvidenceByDefault,
                focused: widget.focusNodeId == trace.nodeId,
              );
            },
          ),
      ],
    );
  }
}
