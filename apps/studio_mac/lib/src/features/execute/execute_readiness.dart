part of '../../studio_mac_workspace.dart';

// 运行前检查面板，只展示用户能理解的准备状态。
class _ExecuteReadinessPanel extends StatelessWidget {
  const _ExecuteReadinessPanel({
    required this.snapshot,
    required this.workflowValidation,
  });

  final StudioRuntimeSnapshot snapshot;
  final WorkflowValidateResult workflowValidation;

  // 渲染运行前的设备、驱动、流程和空闲状态。
  @override
  Widget build(BuildContext context) {
    final runIdle = snapshot.runStatus == RunStatus.idle;
    return _InsetSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('运行前', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _ReadinessRow(
            label: '设备就绪',
            ready: snapshot.connectionStatus == ConnectionStatus.connected,
            waiting: _deviceBusy(snapshot.connectionStatus),
          ),
          const SizedBox(height: 10),
          _ReadinessRow(
            label: '驱动就绪',
            ready: snapshot.appiumStatus == AppiumProcessStatus.running,
            waiting: _appiumBusy(snapshot.appiumStatus),
          ),
          const SizedBox(height: 10),
          _ReadinessRow(
            label: '流程有效',
            ready: workflowValidation.isValid,
            waiting: false,
          ),
          if (!workflowValidation.isValid) ...[
            const SizedBox(height: 8),
            Text(
              _executeWorkflowIssueLabel(workflowValidation),
              key: const ValueKey('execute-workflow-issue'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.amber,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (workflowValidation.errors.length > 1) ...[
              const SizedBox(height: 6),
              _ExecuteWorkflowIssueDetailsButton(
                validation: workflowValidation,
              ),
            ],
          ],
          const SizedBox(height: 10),
          _ReadinessRow(
            label: '空闲',
            ready: runIdle,
            waiting: snapshot.runStatus == RunStatus.running,
          ),
        ],
      ),
    );
  }
}

// 运行前流程问题详情入口，主界面只保留摘要，完整清单放到弹窗。
class _ExecuteWorkflowIssueDetailsButton extends StatelessWidget {
  const _ExecuteWorkflowIssueDetailsButton({required this.validation});

  final WorkflowValidateResult validation;

  // 渲染紧凑入口，避免多条错误直接撑高运行前面板。
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('execute-workflow-issue-details'),
      onPressed: () => _showExecuteWorkflowIssueDetails(context, validation),
      icon: const Icon(Icons.rule_folder_outlined, size: 16),
      label: Text('查看 ${validation.errors.length} 项'),
      style: TextButton.styleFrom(
        foregroundColor: StudioColors.amber,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// 展示运行前所有流程问题，使用同一诊断翻译，不重复实现校验。
Future<void> _showExecuteWorkflowIssueDetails(
  BuildContext context,
  WorkflowValidateResult validation,
) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const ValueKey('execute-workflow-issue-dialog'),
        backgroundColor: StudioColors.panel,
        title: const Text('流程问题'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '共 ${validation.errors.length} 项，修正后再运行。',
                style: const TextStyle(color: StudioColors.muted),
              ),
              const SizedBox(height: 12),
              for (final (index, error) in validation.errors.indexed)
                Padding(
                  key: ValueKey('execute-workflow-issue-item-$index'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '${index + 1}. ${_workflowDiagnosticMessage(error)}',
                    style: const TextStyle(height: 1.35),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: const ValueKey('execute-workflow-issue-close'),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

// 将流程校验结果压缩成执行页可读的短提示。
String _executeWorkflowIssueLabel(WorkflowValidateResult validation) {
  if (validation.isValid) return '流程就绪。';
  final first = validation.errors.firstOrNull;
  if (first == null) return '流程需检查。';
  return _workflowDiagnosticMessage(first);
}
