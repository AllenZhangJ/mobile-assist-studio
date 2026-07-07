part of '../studio_runtime.dart';

// 运行详情模型分片，负责从事件流聚合完整本地运行详情。

// RunDetail 是一次运行的完整本地详情。
// 它从事件流派生节点路径、截图证据和失败分析。
final class RunDetail {
  // 创建运行详情。
  const RunDetail({required this.entry, required this.events});

  final RunHistoryEntry entry;
  final List<RunEvidenceEvent> events;

  // 筛选节点相关事件，过滤运行开始结束等非节点事件。
  List<RunEvidenceEvent> get nodeEvents {
    return events
        .where((event) => event.nodeId != null && event.type.startsWith('step'))
        .toList(growable: false);
  }

  // 合成节点执行路径，未结束的节点会保留 running 状态。
  List<RunNodeTrace> get nodeTraces {
    final starts = <String, RunEvidenceEvent>{};
    final traces = <RunNodeTrace>[];
    for (final event in nodeEvents) {
      final nodeId = event.nodeId;
      if (nodeId == null) continue;
      final key = _nodeTraceKey(nodeId, event.loopIndex);
      if (event.type == 'stepStart') {
        starts[key] = event;
        continue;
      }
      if (event.type == 'stepEnd') {
        final start = starts.remove(key);
        traces.add(
          RunNodeTrace(
            nodeId: nodeId,
            nodeType: event.nodeType ?? start?.nodeType,
            label: event.label ?? start?.label,
            loopIndex: event.loopIndex ?? start?.loopIndex,
            status: event.status ?? 'completed',
            startedAt: start?.at,
            finishedAt: event.at,
            error: event.error,
            screenshotPath: event.screenshotPath,
          ),
        );
      }
    }
    for (final start in starts.values) {
      final nodeId = start.nodeId;
      if (nodeId == null) continue;
      traces.add(
        RunNodeTrace(
          nodeId: nodeId,
          nodeType: start.nodeType,
          label: start.label,
          loopIndex: start.loopIndex,
          status: 'running',
          startedAt: start.at,
          finishedAt: null,
          error: start.error,
          screenshotPath: start.screenshotPath,
        ),
      );
    }
    return List<RunNodeTrace>.unmodifiable(traces);
  }

  // 返回最后一个失败节点 ID，用于定位详情焦点。
  String? get failedNodeId {
    for (final event in events.reversed) {
      if (event.status == 'failed' && event.nodeId != null) {
        return event.nodeId;
      }
    }
    return null;
  }

  // 返回最后一个暂停节点 ID，用于人工介入态展示。
  String? get pausedNodeId {
    for (final event in events.reversed) {
      if (event.status == 'paused' && event.nodeId != null) {
        return event.nodeId;
      }
    }
    return null;
  }

  // 提取最接近结果的失败原因，缺失时给出运行状态默认说明。
  String? get failureReason {
    for (final event in events.reversed) {
      if (event.error != null && event.error!.trim().isNotEmpty) {
        return event.error;
      }
    }
    if (entry.status == 'paused') {
      return 'Execution paused for manual intervention.';
    }
    if (entry.status == 'failed') return 'Execution failed before completion.';
    return null;
  }

  // 汇总失败分析，优先使用失败节点，其次使用暂停节点。
  RunFailureAnalysis get failureAnalysis {
    final traces = nodeTraces;
    RunNodeTrace? failedTrace;
    RunNodeTrace? pausedTrace;
    for (final trace in traces.reversed) {
      if (trace.status == 'failed') {
        failedTrace = trace;
        break;
      }
      if (pausedTrace == null && trace.status == 'paused') {
        pausedTrace = trace;
      }
    }
    final reason = failureReason;
    final issueTrace = failedTrace ?? pausedTrace;
    return RunFailureAnalysis(
      category: _failureCategory(entry.status, reason),
      failedNodeId: issueTrace?.nodeId ?? failedNodeId ?? pausedNodeId,
      failedNodeLabel: issueTrace?.label,
      failedNodeType: issueTrace?.nodeType,
      failedLoopIndex: issueTrace?.loopIndex,
      failedDuration: issueTrace?.duration,
      reason: reason,
      screenshotEvidenceCount: traces
          .where((trace) => trace.screenshotPath != null)
          .length,
    );
  }

  // 汇总执行路径指标，包括完成、失败、暂停、截图和最慢节点。
  RunDetailMetrics get metrics {
    final traces = nodeTraces;
    RunNodeTrace? slowestTrace;
    for (final trace in traces) {
      final duration = trace.duration;
      if (duration == null) continue;
      final slowestDuration = slowestTrace?.duration;
      if (slowestDuration == null || duration > slowestDuration) {
        slowestTrace = trace;
      }
    }
    return RunDetailMetrics(
      totalSteps: traces.length,
      completedSteps: traces
          .where(
            (trace) =>
                trace.status == 'ok' ||
                trace.status == 'completed' ||
                trace.status == 'handled',
          )
          .length,
      failedSteps: traces.where((trace) => trace.status == 'failed').length,
      pausedSteps: traces.where((trace) => trace.status == 'paused').length,
      runningSteps: traces.where((trace) => trace.status == 'running').length,
      screenshotEvidenceCount: traces
          .where((trace) => trace.screenshotPath != null)
          .length,
      slowestNodeId: slowestTrace?.nodeId,
      slowestNodeLabel: slowestTrace?.label,
      slowestNodeType: slowestTrace?.nodeType,
      slowestDuration: slowestTrace?.duration,
    );
  }

  // 生成截图证据引用列表，只保留本地相对路径。
  List<RunScreenshotEvidenceRef> get screenshotEvidenceRefs {
    final refs = <RunScreenshotEvidenceRef>[];
    for (final trace in nodeTraces) {
      final screenshotPath = trace.screenshotPath;
      if (screenshotPath == null || screenshotPath.trim().isEmpty) continue;
      refs.add(
        RunScreenshotEvidenceRef(
          nodeId: trace.nodeId,
          nodeType: trace.nodeType,
          label: trace.label,
          loopIndex: trace.loopIndex,
          status: trace.status,
          duration: trace.duration,
          relativePath: screenshotPath,
        ),
      );
    }
    return List<RunScreenshotEvidenceRef>.unmodifiable(refs);
  }

  // 筛选带视觉证据的事件，供视觉证据链展示。
  List<RunEvidenceEvent> get visualEvidenceEvents {
    return events
        .where((event) => event.visualEvidence != null)
        .toList(growable: false);
  }

  // 计算整次运行耗时，缺少开始或结束时间时返回空。
  Duration? get duration {
    final startedAt = entry.startedAt;
    final finishedAt = entry.finishedAt;
    if (startedAt == null || finishedAt == null) return null;
    return finishedAt.difference(startedAt);
  }
}

// 生成节点路径聚合 key，区分同一节点在不同轮次的执行。
String _nodeTraceKey(String nodeId, int? loopIndex) {
  return '$nodeId:${loopIndex ?? -1}';
}
