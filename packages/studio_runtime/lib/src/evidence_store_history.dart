part of '../studio_runtime.dart';

// 本地运行历史分片，负责 Monitor 摘要、趋势和聚合指标。
extension LocalRunEvidenceStoreHistory on LocalRunEvidenceStore {
  // 读取运行摘要并生成 KPI、趋势、问题分类和耗时节点。
  Future<RunHistorySummary> _readSummary({int limit = 10}) async {
    if (!await _rootDirectory.exists()) {
      return RunHistorySummary.empty;
    }
    await _cleanup();
    final directories = await _rootDirectory
        .list()
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();
    final entries = <RunHistoryEntry>[];
    for (final directory in directories) {
      final entry = await _readRunDirectory(directory);
      if (entry != null) entries.add(entry);
    }
    entries.sort((a, b) {
      final left = a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });

    var completedRuns = 0;
    var failedRuns = 0;
    var pausedRuns = 0;
    var stoppedRuns = 0;
    for (final entry in entries) {
      switch (entry.status) {
        case 'completed':
          completedRuns += 1;
        case 'failed':
          failedRuns += 1;
        case 'paused':
          pausedRuns += 1;
        case 'stopped':
          stoppedRuns += 1;
      }
    }

    return RunHistorySummary(
      totalRuns: entries.length,
      completedRuns: completedRuns,
      failedRuns: failedRuns,
      pausedRuns: pausedRuns,
      stoppedRuns: stoppedRuns,
      dailyRuns: _dailyRuns(entries, windowDays: 7),
      averageDuration: _averageRunDuration(entries),
      dailyRuns30: _dailyRuns(entries, windowDays: 30),
      dailyRuns90: _dailyRuns(entries, windowDays: 90),
      recentRuns: List<RunHistoryEntry>.unmodifiable(entries.take(limit)),
      issueCategories: await _issueCategories(entries.take(limit)),
      nodeDurationStats: await _nodeDurationStats(entries.take(limit)),
      nodeDurationTrends: await _nodeDurationTrends(
        entries.take(limit),
        windowDays: 7,
      ),
      failureClusters: await _failureClusters(entries.take(limit)),
    );
  }

  // 从最近运行详情中聚合问题分类。
  Future<List<RunIssueCategoryCount>> _issueCategories(
    Iterable<RunHistoryEntry> entries,
  ) async {
    final aggregations = <String, _IssueCategoryAggregation>{};
    for (final entry in entries) {
      final detail = await readDetail(entry.runId);
      final category = detail?.failureAnalysis.category ?? 'None';
      if (category == 'None') continue;
      final aggregation = aggregations.putIfAbsent(
        category,
        () => _IssueCategoryAggregation(category: category),
      );
      aggregation.add(entry);
    }
    final categories =
        aggregations.values.map((aggregation) => aggregation.toCount()).toList()
          ..sort((a, b) {
            final byCount = b.count.compareTo(a.count);
            if (byCount != 0) return byCount;
            return a.category.compareTo(b.category);
          });
    return List<RunIssueCategoryCount>.unmodifiable(categories);
  }

  // 从最近运行详情中聚合节点耗时，供 Monitor 展示慢节点。
  Future<List<RunNodeDurationStat>> _nodeDurationStats(
    Iterable<RunHistoryEntry> entries,
  ) async {
    final aggregations = <String, _NodeDurationAggregation>{};
    for (final entry in entries) {
      final detail = await readDetail(entry.runId);
      if (detail == null) continue;
      for (final trace in detail.nodeTraces) {
        final duration = trace.duration;
        if (duration == null || duration.isNegative) continue;
        final aggregation = aggregations.putIfAbsent(
          trace.nodeId,
          () => _NodeDurationAggregation(
            nodeId: trace.nodeId,
            nodeType: trace.nodeType,
            label: trace.label,
          ),
        );
        aggregation.add(
          duration,
          entry: entry,
          trace: trace,
          hasIssue: _traceHasIssue(trace),
        );
      }
    }
    final stats = aggregations.values
        .where((aggregation) => aggregation.sampleCount > 0)
        .map((aggregation) => aggregation.toStat())
        .toList();
    stats.sort((a, b) {
      final byAverage = b.averageDuration.compareTo(a.averageDuration);
      if (byAverage != 0) return byAverage;
      final byMax = b.maxDuration.compareTo(a.maxDuration);
      if (byMax != 0) return byMax;
      return a.nodeId.compareTo(b.nodeId);
    });
    return List<RunNodeDurationStat>.unmodifiable(stats.take(6));
  }

  // 从最近运行详情中聚合节点耗时趋势，供 Monitor 观察跨日期变化。
  Future<List<RunNodeDurationTrend>> _nodeDurationTrends(
    Iterable<RunHistoryEntry> entries, {
    required int windowDays,
  }) async {
    if (windowDays < 1) return const <RunNodeDurationTrend>[];
    final entryList = entries.toList(growable: false);
    DateTime? latestDay;
    final aggregations = <String, _NodeDurationTrendAggregation>{};
    for (final entry in entryList) {
      final timestamp = entry.startedAt ?? entry.finishedAt;
      if (timestamp == null) continue;
      final day = _utcDay(timestamp);
      if (latestDay == null || day.isAfter(latestDay)) latestDay = day;
      final detail = await readDetail(entry.runId);
      if (detail == null) continue;
      for (final trace in detail.nodeTraces) {
        final duration = trace.duration;
        if (duration == null || duration.isNegative) continue;
        final aggregation = aggregations.putIfAbsent(
          trace.nodeId,
          () => _NodeDurationTrendAggregation(
            nodeId: trace.nodeId,
            nodeType: trace.nodeType,
            label: trace.label,
          ),
        );
        aggregation.add(
          day,
          duration,
          entry: entry,
          trace: trace,
          hasIssue: _traceHasIssue(trace),
        );
      }
    }
    final anchor = latestDay;
    if (anchor == null) return const <RunNodeDurationTrend>[];
    final trends = aggregations.values
        .where((aggregation) => aggregation.sampleCount > 0)
        .map(
          (aggregation) =>
              aggregation.toTrend(anchor: anchor, windowDays: windowDays),
        )
        .toList();
    trends.sort((a, b) {
      final byAverage = b.averageDuration.compareTo(a.averageDuration);
      if (byAverage != 0) return byAverage;
      final byMax = b.maxDuration.compareTo(a.maxDuration);
      if (byMax != 0) return byMax;
      return a.nodeId.compareTo(b.nodeId);
    });
    return List<RunNodeDurationTrend>.unmodifiable(trends.take(4));
  }

  // 从最近运行详情中聚合跨运行问题，供 Monitor 展示常见原因。
  Future<List<RunFailureCluster>> _failureClusters(
    Iterable<RunHistoryEntry> entries,
  ) async {
    final aggregations = <String, _FailureClusterAggregation>{};
    for (final entry in entries) {
      final detail = await readDetail(entry.runId);
      if (detail == null) continue;
      final analysis = detail.failureAnalysis;
      if (analysis.category == 'None') continue;
      final key = _failureClusterKey(analysis);
      final aggregation = aggregations.putIfAbsent(
        key,
        () => _FailureClusterAggregation(
          category: analysis.category,
          nodeId: analysis.failedNodeId,
          nodeType: analysis.failedNodeType,
          label: analysis.failedNodeLabel,
        ),
      );
      aggregation.add(entry, analysis);
    }
    final clusters = aggregations.values
        .map((aggregation) => aggregation.toCluster())
        .toList();
    clusters.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      final byWorkflow = b.workflowCount.compareTo(a.workflowCount);
      if (byWorkflow != 0) return byWorkflow;
      final leftRecent = a.recentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightRecent = b.recentAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final byRecent = rightRecent.compareTo(leftRecent);
      if (byRecent != 0) return byRecent;
      return _failureClusterSortLabel(a).compareTo(_failureClusterSortLabel(b));
    });
    return List<RunFailureCluster>.unmodifiable(clusters.take(6));
  }
}
