part of '../../studio_mac_workspace.dart';

// 运行详情抽屉组件，负责摘要、耗时、失败原因和视觉证据链展示。
class _RunDetailDrawer extends StatelessWidget {
  const _RunDetailDrawer({
    required this.entry,
    required this.detail,
    required this.report,
    required this.controller,
  });

  final RunHistoryEntry entry;
  final RunDetail? detail;
  final RunLocalReport? report;
  final StudioRuntimeController controller;

  // 渲染运行详情抽屉壳，并组合摘要、报告、分析、证据和节点路径分片。
  @override
  Widget build(BuildContext context) {
    final resolvedEntry = detail?.entry ?? entry;
    final revealScreenshotsByDefault =
        controller.snapshot.settings.revealScreenshotsByDefault;
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          key: const ValueKey('run-detail-drawer'),
          width: 720,
          height: double.infinity,
          margin: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
          decoration: BoxDecoration(
            color: StudioColors.panel,
            border: Border.all(color: StudioColors.border),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.36),
                blurRadius: 24,
                offset: const Offset(-12, 0),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: resolvedEntry.status,
                      tone: _toneForRunStatus(resolvedEntry.status),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        resolvedEntry.workflowName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _RunDetailCopyButton(entry: resolvedEntry, detail: detail),
                    _RunReportCopyButton(report: report),
                    _RunReportExportButton(
                      runId: resolvedEntry.runId,
                      report: report,
                      controller: controller,
                    ),
                    IconButton(
                      tooltip: '关闭详情',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: detail == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RunDetailSummary(
                              entry: resolvedEntry,
                              detail: detail,
                            ),
                            if (report != null) ...[
                              const SizedBox(height: 14),
                              _RunLocalReportPanel(report: report!),
                            ],
                            const SizedBox(height: 14),
                            const Expanded(child: _RunDetailEmptyState()),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RunDetailSummary(
                                entry: resolvedEntry,
                                detail: detail,
                              ),
                              if (report != null) ...[
                                const SizedBox(height: 14),
                                _RunLocalReportPanel(report: report!),
                              ],
                              const SizedBox(height: 14),
                              _RunFailureAnalysisPanel(
                                analysis: detail!.failureAnalysis,
                              ),
                              const SizedBox(height: 14),
                              _RunIssueRecommendationPanel(
                                analysis: detail!.failureAnalysis,
                                metrics: detail!.metrics,
                                visualEvidenceEvents:
                                    detail!.visualEvidenceEvents,
                              ),
                              const SizedBox(height: 14),
                              _RunAiExplanationPanel(
                                runId: resolvedEntry.runId,
                                report: report,
                                controller: controller,
                              ),
                              if (detail!.visualEvidenceEvents.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                _RunVisualEvidenceChainPanel(
                                  events: detail!.visualEvidenceEvents,
                                ),
                              ],
                              const SizedBox(height: 14),
                              _RunExecutionMetricsPanel(
                                metrics: detail!.metrics,
                              ),
                              const SizedBox(height: 14),
                              _RunEvidenceFilmstripPanel(
                                runId: resolvedEntry.runId,
                                evidenceRefs: detail!.screenshotEvidenceRefs,
                                controller: controller,
                                revealByDefault: revealScreenshotsByDefault,
                              ),
                              const SizedBox(height: 14),
                              _RunRelatedEventsPanel(events: detail!.events),
                              const SizedBox(height: 14),
                              _RunNodeTraceTimeline(
                                runId: resolvedEntry.runId,
                                traces: detail!.nodeTraces,
                                controller: controller,
                                revealEvidenceByDefault:
                                    revealScreenshotsByDefault,
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
