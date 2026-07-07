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
    this.gitBranch,
    this.gitDirty,
    this.gitRemoteSynced,
    this.gitAhead,
    this.gitBehind,
    required this.iosStatus,
    required this.iosDetail,
    required this.androidStatus,
    required this.androidDetail,
    required this.screenshots,
    required this.iosRuns,
    required this.androidRuns,
    required this.fullSmokeReports,
    required this.latestFullSmokeLabel,
    required this.failures,
    required this.nextSteps,
    required this.batches,
    this.gateGaps = const <V4AcceptanceGateGap>[],
    this.fieldChecklist = const <V4AcceptanceChecklistItem>[],
  });

  final bool hasReport;
  final bool auditOk;
  final bool complete;
  final String statusLabel;
  final DateTime? checkedAt;
  final String? gitRevision;
  final String? gitBranch;
  final bool? gitDirty;
  final bool? gitRemoteSynced;
  final int? gitAhead;
  final int? gitBehind;
  final String iosStatus;
  final String iosDetail;
  final String androidStatus;
  final String androidDetail;
  final int screenshots;
  final int iosRuns;
  final int androidRuns;
  final int fullSmokeReports;
  final String latestFullSmokeLabel;
  final List<String> failures;
  final List<String> nextSteps;
  final List<V4AcceptanceBatchSummary> batches;
  final List<V4AcceptanceGateGap> gateGaps;
  final List<V4AcceptanceChecklistItem> fieldChecklist;

  // 无报告时的安全初始状态。
  static const empty = V4AcceptanceSummary(
    hasReport: false,
    auditOk: false,
    complete: false,
    statusLabel: '未审计',
    checkedAt: null,
    gitRevision: null,
    iosStatus: '未知',
    iosDetail: '尚未读取终验报告。',
    androidStatus: '未知',
    androidDetail: '尚未读取终验报告。',
    screenshots: 0,
    iosRuns: 0,
    androidRuns: 0,
    fullSmokeReports: 0,
    latestFullSmokeLabel: '暂无',
    failures: <String>[],
    nextSteps: <String>[],
    batches: <V4AcceptanceBatchSummary>[],
    gateGaps: <V4AcceptanceGateGap>[],
    fieldChecklist: <V4AcceptanceChecklistItem>[],
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

  // 已完成批次数，供 UI 只展示摘要，不铺开完整表。
  int get completedBatchCount =>
      batches.where((batch) => batch.isComplete).length;

  // 批次总数，缺失报告或旧报告时为 0。
  int get totalBatchCount => batches.length;

  // 批次进度短标签，避免主界面展示大段审计表。
  String get batchProgressLabel {
    if (batches.isEmpty) return '未读';
    return '$completedBatchCount/${batches.length}';
  }

  // 首个未完成批次，用于给用户一个短下一步焦点。
  V4AcceptanceBatchSummary? get firstPendingBatch {
    for (final batch in batches) {
      if (!batch.isComplete) return batch;
    }
    return null;
  }

  // 工作区干净度短文案，供 Monitor 展示版本证据链。
  String get gitWorktreeLabel {
    return switch (gitDirty) {
      true => '有改动',
      false => '干净',
      null => '未知',
    };
  }

  // 远端同步短文案，证明当前提交是否已推到上游。
  String get gitRemoteLabel {
    return switch (gitRemoteSynced) {
      true => '已同步',
      false => _gitRemoteGapLabel,
      null => '未知',
    };
  }

  // 将 ahead / behind 组合压成短中文，避免主界面展示 Git 术语。
  String get _gitRemoteGapLabel {
    final ahead = gitAhead ?? 0;
    final behind = gitBehind ?? 0;
    if (ahead > 0 && behind > 0) return '分叉';
    if (ahead > 0) return '未推';
    if (behind > 0) return '落后';
    return '未同步';
  }
}

// V4AcceptanceGateGap 是终验门禁的一条结构化缺口。
// UI 只展示脱敏摘要，不读取子报告或本机路径。
final class V4AcceptanceGateGap {
  // 创建终验门禁缺口摘要。
  const V4AcceptanceGateGap({
    required this.title,
    required this.current,
    required this.requiredText,
    this.command,
  });

  final String title;
  final String current;
  final String requiredText;
  final String? command;
}

// V4AcceptanceChecklistItem 是现场补验清单的一条安全步骤。
// command 只保留白名单命令，坏报告不能注入任意 shell 文本。
final class V4AcceptanceChecklistItem {
  // 创建现场补验清单项。
  const V4AcceptanceChecklistItem({
    required this.order,
    required this.title,
    required this.proof,
    this.command,
  });

  final int order;
  final String title;
  final String proof;
  final String? command;
}

// V4AcceptanceBatchSummary 是 Batch 0-8 的单行脱敏验收摘要。
// 它来自 final acceptance JSON，不读取 Markdown，不保存本机路径。
final class V4AcceptanceBatchSummary {
  // 创建单个批次摘要。
  const V4AcceptanceBatchSummary({
    required this.name,
    required this.status,
    required this.evidence,
  });

  final String name;
  final String status;
  final String evidence;

  // 判断当前批次是否已闭环，未知或现场未就绪都不算完成。
  bool get isComplete {
    return status == '已落地' || status == '已完成完整 smoke 留档' || status == '完整通过';
  }
}
