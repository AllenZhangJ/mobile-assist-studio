part of '../studio_runtime.dart';

// V4AcceptanceSummary 是最新 V4 终验报告的脱敏摘要。
// 它只保留 UI 和审计需要的短状态，不暴露报告路径或底层命令输出。
final class V4AcceptanceSummary {
  // 创建 V4 终验摘要。
  const V4AcceptanceSummary({
    required this.hasReport,
    required this.auditOk,
    required this.complete,
    required this.statusLabel,
    required this.checkedAt,
    required this.gitRevision,
    required this.androidStatus,
    required this.androidDetail,
    required this.screenshots,
    required this.iosRuns,
    required this.androidRuns,
    required this.fullSmokeReports,
    required this.latestFullSmokeLabel,
    required this.failures,
    required this.nextSteps,
  });

  final bool hasReport;
  final bool auditOk;
  final bool complete;
  final String statusLabel;
  final DateTime? checkedAt;
  final String? gitRevision;
  final String androidStatus;
  final String androidDetail;
  final int screenshots;
  final int iosRuns;
  final int androidRuns;
  final int fullSmokeReports;
  final String latestFullSmokeLabel;
  final List<String> failures;
  final List<String> nextSteps;

  // 无报告时的安全初始状态。
  static const empty = V4AcceptanceSummary(
    hasReport: false,
    auditOk: false,
    complete: false,
    statusLabel: '未审计',
    checkedAt: null,
    gitRevision: null,
    androidStatus: '未知',
    androidDetail: '尚未读取终验报告。',
    screenshots: 0,
    iosRuns: 0,
    androidRuns: 0,
    fullSmokeReports: 0,
    latestFullSmokeLabel: '暂无',
    failures: <String>[],
    nextSteps: <String>[],
  );

  // 终验最短下一步，缺失报告时给出可操作入口。
  String get primaryNextStep {
    if (nextSteps.isNotEmpty) return nextSteps.first;
    if (!hasReport) return '先跑审计';
    if (complete) return '已完成';
    return '补齐留档';
  }

  // 判断是否已存在 Android 真机 smoke 留档。
  bool get hasAndroidRun => androidRuns > 0;
}
