part of '../../studio_mac_workspace.dart';

// 耗时趋势摘要模型，集中承载 UI 需要的跨日期派生字段。
final class _MonitorDurationTrendSummary {
  // 创建趋势深挖摘要，调用方传入已脱敏的统计值。
  const _MonitorDurationTrendSummary({
    required this.peakDayLabel,
    required this.peakDurationLabel,
    required this.latestSampleDayLabel,
    required this.issueDayCount,
    required this.sampleCount,
    required this.tone,
  });

  final String peakDayLabel;
  final String peakDurationLabel;
  final String latestSampleDayLabel;
  final int issueDayCount;
  final int sampleCount;
  final StudioStatusTone tone;

  // 从 Runtime 节点耗时趋势聚合值派生显示摘要。
  factory _MonitorDurationTrendSummary.fromTrend(RunNodeDurationTrend trend) {
    final sampledPoints = trend.points
        .where(
          (point) => point.sampleCount > 0 && point.averageDuration != null,
        )
        .toList(growable: false);
    final peakPoint = _findPeakPoint(sampledPoints);
    final latestPoint = _findLatestPoint(sampledPoints);
    final issueDayCount = trend.points
        .where((point) => point.issueCount > 0)
        .length;
    final sampleCount = trend.points.fold<int>(
      0,
      (value, point) => value + point.sampleCount,
    );
    return _MonitorDurationTrendSummary(
      peakDayLabel: peakPoint == null ? '-' : _trendDayLabel(peakPoint.day),
      peakDurationLabel: _formatDuration(peakPoint?.averageDuration),
      latestSampleDayLabel: latestPoint == null
          ? '-'
          : _trendDayLabel(latestPoint.day),
      issueDayCount: issueDayCount,
      sampleCount: sampleCount,
      tone: issueDayCount == 0
          ? StudioStatusTone.ready
          : StudioStatusTone.warning,
    );
  }

  // 找出平均耗时最高的趋势点，缺失耗时按零处理。
  static RunNodeDurationTrendPoint? _findPeakPoint(
    List<RunNodeDurationTrendPoint> points,
  ) {
    return points.fold<RunNodeDurationTrendPoint?>(null, (peak, point) {
      if (peak == null) return point;
      final peakDuration = peak.averageDuration ?? Duration.zero;
      final pointDuration = point.averageDuration ?? Duration.zero;
      return pointDuration > peakDuration ? point : peak;
    });
  }

  // 找出最近一个有样本的趋势点，用于说明最新可用数据。
  static RunNodeDurationTrendPoint? _findLatestPoint(
    List<RunNodeDurationTrendPoint> points,
  ) {
    return points.fold<RunNodeDurationTrendPoint?>(null, (latest, point) {
      if (latest == null || point.day.isAfter(latest.day)) return point;
      return latest;
    });
  }
}
