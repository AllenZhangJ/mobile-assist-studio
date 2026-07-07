part of '../../studio_mac_workspace.dart';

// 执行摘要组件，负责拼装当前进度、运行事实、最近证据和事件线。
class _ExecuteSummaryPanel extends StatelessWidget {
  const _ExecuteSummaryPanel({
    required this.snapshot,
    required this.loadingRunId,
    required this.onOpenExecuteDetail,
  });

  final StudioRuntimeSnapshot snapshot;
  final String? loadingRunId;
  final ValueChanged<RunHistoryEntry> onOpenExecuteDetail;

  // 渲染执行页右侧摘要，窄高时自动切换滚动布局。
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final header = const Text(
            '运行摘要',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          );
          final focus = _ExecutionFocusPanel(
            workflow: snapshot.workflow,
            focus: snapshot.executionFocus,
            runStatus: snapshot.runStatus,
            events: snapshot.events,
          );
          final facts = _ExecuteRuntimeFacts(snapshot: snapshot);
          final latestRun = snapshot.runHistory.recentRuns.isEmpty
              ? null
              : snapshot.runHistory.recentRuns.first;
          final latestRunPanel = _ExecuteLatestRunPanel(
            entry: latestRun,
            loading: latestRun != null && latestRun.runId == loadingRunId,
            onOpen: latestRun == null
                ? null
                : () => onOpenExecuteDetail(latestRun),
          );
          final timeline = _ExecuteTimelinePanel(events: snapshot.events);
          List<Widget> summaryChildren({required Widget timelineChild}) {
            return [
              header,
              const SizedBox(height: 12),
              focus,
              const SizedBox(height: 14),
              facts,
              const SizedBox(height: 14),
              latestRunPanel,
              const SizedBox(height: 14),
              timelineChild,
            ];
          }

          if (constraints.hasBoundedHeight) {
            if (constraints.maxHeight < 720) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: summaryChildren(
                    timelineChild: SizedBox(height: 196, child: timeline),
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: summaryChildren(
                timelineChild: Expanded(child: timeline),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: summaryChildren(
              timelineChild: SizedBox(height: 196, child: timeline),
            ),
          );
        },
      ),
    );
  }
}
