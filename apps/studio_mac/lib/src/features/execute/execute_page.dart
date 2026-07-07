part of '../../studio_mac_workspace.dart';

// 执行页入口，负责保存循环次数并组合配置区与执行摘要。
class _ExecutePage extends StatefulWidget {
  const _ExecutePage({required this.snapshot, required this.controller});

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;

  @override
  State<_ExecutePage> createState() => _ExecutePageState();
}

class _ExecutePageState extends State<_ExecutePage> {
  _ExecuteRunMode _runMode = _ExecuteRunMode.loop;
  int _loops = 3;
  String? _loadingRunId;

  // 当前有效轮数由运行模式统一派生，避免按钮和步进器各算一套。
  int get _effectiveLoops => _runMode.effectiveLoops(_loops);

  // 切换运行模式时只改变页面配置，不触发 Runtime 或设备动作。
  void _setRunMode(_ExecuteRunMode mode) {
    setState(() => _runMode = mode);
  }

  // 打开最近运行详情，详情数据仍从 Runtime 本地证据读取。
  Future<void> _openLatestRunDetail(RunHistoryEntry entry) async {
    if (_loadingRunId != null) return;
    setState(() => _loadingRunId = entry.runId);
    final detailFuture = widget.controller.readRunDetail(entry.runId);
    final reportFuture = widget.controller.readRunReport(entry.runId);
    final detail = await detailFuture;
    final report = await reportFuture;
    if (!mounted) return;
    setState(() => _loadingRunId = null);
    await _showRunDetailDrawer(
      context,
      entry: entry,
      detail: detail,
      report: report,
      controller: widget.controller,
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final controller = widget.controller;
    final workflowValidation = _workflowProjectValidation(
      snapshot.workflow,
      snapshot.subWorkflows,
    );
    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final config = _ExecuteConfigurationPanel(
            snapshot: snapshot,
            workflowValidation: workflowValidation,
            runMode: _runMode,
            loops: _loops,
            effectiveLoops: _effectiveLoops,
            onRunModeChanged: _setRunMode,
            onLoopsChanged: (value) => setState(() => _loops = value),
          );
          final command = _ExecuteCommandPanel(
            snapshot: snapshot,
            workflowValidation: workflowValidation,
            controller: controller,
            runMode: _runMode,
            loops: _effectiveLoops,
          );
          final summary = _ExecuteSummaryPanel(
            snapshot: snapshot,
            loadingRunId: _loadingRunId,
            onOpenExecuteDetail: _openLatestRunDetail,
          );

          if (constraints.maxWidth < 980) {
            return ListView(
              children: [
                config,
                const SizedBox(height: 14),
                command,
                const SizedBox(height: 14),
                summary,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 318, child: config),
              const SizedBox(width: 14),
              Expanded(child: command),
              const SizedBox(width: 14),
              SizedBox(width: 338, child: summary),
            ],
          );
        },
      ),
    );
  }
}
