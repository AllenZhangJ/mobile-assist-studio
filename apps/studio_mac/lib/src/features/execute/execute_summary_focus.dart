part of '../../studio_mac_workspace.dart';

// 执行进度条，集中表达当前工作流完成度。
class _ExecutionProgressBar extends StatelessWidget {
  const _ExecutionProgressBar({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染运行进度条，运行中且未开始时显示不确定进度。
  @override
  Widget build(BuildContext context) {
    final progress = _executionProgress(
      snapshot.workflow,
      snapshot.executionFocus,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '运行进度',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: StudioColors.muted,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: snapshot.runStatus == RunStatus.running && progress == 0
                ? null
                : progress,
            backgroundColor: StudioColors.border,
            color: _colorForTone(_toneForLiveRunStatus(snapshot.runStatus)),
          ),
        ),
      ],
    );
  }
}

// 当前节点焦点面板，承载运行中、暂停和失败节点摘要。
class _ExecutionFocusPanel extends StatelessWidget {
  const _ExecutionFocusPanel({
    required this.workflow,
    required this.focus,
    required this.runStatus,
    required this.events,
  });

  final WorkflowDefinition workflow;
  final RuntimeExecutionFocus focus;
  final RunStatus runStatus;
  final List<RuntimeEvent> events;

  // 渲染当前节点焦点和轮次摘要，暂停态给出人工处理提示。
  @override
  Widget build(BuildContext context) {
    final activeLabel = _nodeLabelById(workflow, focus.activeNodeId);
    final failedLabel = _nodeLabelById(workflow, focus.failedNodeId);
    final signal = _executionFocusSignal(
      events: events,
      runStatus: runStatus,
      focus: focus,
    );
    final paused = runStatus == RunStatus.paused;
    final loopLabel = focus.totalLoops == null || focus.activeLoopIndex == null
        ? '暂无轮次'
        : '第 ${focus.activeLoopIndex! + 1}/${focus.totalLoops} 轮';
    return _InsetSurface(
      key: const ValueKey('execute-focus-panel'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  label: runStatus == RunStatus.running
                      ? '运行中'
                      : paused
                      ? '人工处理'
                      : '运行轨迹',
                  tone: runStatus == RunStatus.running
                      ? StudioStatusTone.running
                      : paused
                      ? StudioStatusTone.warning
                      : focus.failedNodeId != null
                      ? StudioStatusTone.error
                      : StudioStatusTone.offline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loopLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _FocusMetric(
              label: '当前',
              value: activeLabel ?? '空闲',
              tone: activeLabel == null
                  ? StudioStatusTone.offline
                  : StudioStatusTone.running,
            ),
            const SizedBox(height: 6),
            _FocusMetric(
              label: '完成',
              value: _executionStepLabel(focus),
              tone: focus.completedSteps == 0 && focus.completedNodeIds.isEmpty
                  ? StudioStatusTone.offline
                  : StudioStatusTone.ready,
            ),
            const SizedBox(height: 6),
            _FocusMetric(
              label: '剩余',
              value: _estimatedRemainingLabel(focus, runStatus),
              tone: runStatus == RunStatus.running
                  ? StudioStatusTone.running
                  : StudioStatusTone.offline,
            ),
            const SizedBox(height: 6),
            _FocusMetric(
              label: paused ? '暂停节点' : '失败',
              value: failedLabel ?? '无',
              tone: failedLabel == null
                  ? StudioStatusTone.offline
                  : paused
                  ? StudioStatusTone.warning
                  : StudioStatusTone.error,
            ),
            if (signal != null) ...[
              const SizedBox(height: 6),
              _FocusMetric(
                label: signal.label,
                value: signal.value,
                tone: signal.tone,
              ),
            ],
            if (paused) ...[
              const SizedBox(height: 10),
              const Text(
                '为避免误点已暂停，确认设备后继续。',
                style: TextStyle(color: StudioColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 执行焦点的补充信号，用于把失败原因和停止状态提前到摘要区。
final class _ExecutionFocusSignal {
  const _ExecutionFocusSignal({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;
}

// 从 Runtime 事件和运行状态派生短信号，不读取底层日志或设备细节。
_ExecutionFocusSignal? _executionFocusSignal({
  required List<RuntimeEvent> events,
  required RunStatus runStatus,
  required RuntimeExecutionFocus focus,
}) {
  if (runStatus == RunStatus.stopping) {
    return const _ExecutionFocusSignal(
      label: '停止',
      value: '当前动作后停止',
      tone: StudioStatusTone.warning,
    );
  }
  if (runStatus == RunStatus.paused) {
    return _ExecutionFocusSignal(
      label: '原因',
      value:
          _latestRuntimeEventMessage(
            events,
            levels: const {'warning', '提醒', 'error', '错误'},
          ) ??
          '等待人工处理',
      tone: StudioStatusTone.warning,
    );
  }
  if (focus.failedNodeId == null) return null;
  return _ExecutionFocusSignal(
    label: '原因',
    value:
        _latestRuntimeEventMessage(events, levels: const {'error', '错误'}) ??
        '运行失败',
    tone: StudioStatusTone.error,
  );
}

// 读取最近一条指定级别事件并统一脱敏。
String? _latestRuntimeEventMessage(
  List<RuntimeEvent> events, {
  required Set<String> levels,
}) {
  for (final event in events.reversed) {
    if (levels.contains(event.level)) {
      return _safeRuntimeEventMessage(event.message);
    }
  }
  return null;
}

// 焦点面板中的紧凑指标行，统一色彩和宽度。
class _FocusMetric extends StatelessWidget {
  const _FocusMetric({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final StudioStatusTone tone;

  // 渲染焦点面板中的一行紧凑指标。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(
              color: StudioColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}
