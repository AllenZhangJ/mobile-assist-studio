part of '../../studio_mac_workspace.dart';

// Execute 运行确认分片，负责二次确认和确认后提交 Runtime 运行。
// 命令面板只发起确认请求，真正的弹窗内容集中在这里维护。

// 弹出确认框后再提交运行，避免误触直接启动自动化。
Future<void> _confirmAndRunWorkflow(
  BuildContext context, {
  required StudioRuntimeSnapshot snapshot,
  required WorkflowValidateResult workflowValidation,
  required StudioRuntimeController controller,
  required _ExecuteRunMode runMode,
  required int loops,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      return _ExecuteRunConfirmationDialog(
        snapshot: snapshot,
        workflowValidation: workflowValidation,
        runMode: runMode,
        loops: loops,
      );
    },
  );
  if (confirmed != true || !context.mounted) return;
  await controller.runCurrentWorkflow(loops: loops);
}

// 主按钮文案跟随运行模式，持续模式不直接暴露大数字。
String _executeRunButtonLabel(_ExecuteRunMode runMode, int loops) {
  if (runMode == _ExecuteRunMode.continuous) return '开始持续';
  return loops == 1 ? '开始 1 轮' : '开始 $loops 轮';
}

// 运行确认弹窗，用摘要语言呈现本次运行范围和安全边界。
class _ExecuteRunConfirmationDialog extends StatelessWidget {
  const _ExecuteRunConfirmationDialog({
    required this.snapshot,
    required this.workflowValidation,
    required this.runMode,
    required this.loops,
  });

  final StudioRuntimeSnapshot snapshot;
  final WorkflowValidateResult workflowValidation;
  final _ExecuteRunMode runMode;
  final int loops;

  // 渲染运行确认内容，保持危险操作需要二次确认。
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('execute-run-confirmation'),
      backgroundColor: StudioColors.panel,
      title: const Text('确认运行'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '开始前请确认运行范围。',
              style: TextStyle(color: StudioColors.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            _ExecutionConfirmationFact(
              label: '流程',
              value: snapshot.workflow.name,
            ),
            _ExecutionConfirmationFact(label: '模式', value: runMode.label),
            _ExecutionConfirmationFact(
              label: '轮',
              value: runMode == _ExecuteRunMode.continuous
                  ? '最多 $loops'
                  : '$loops',
            ),
            _ExecutionConfirmationFact(
              label: '节点',
              value: '${snapshot.workflow.nodes.length}',
            ),
            _ExecutionConfirmationFact(label: '执行', value: '串行运行'),
            _ExecutionConfirmationFact(label: '停止', value: '当前动作结束后停止'),
            if (runMode == _ExecuteRunMode.continuous)
              const _ExecutionConfirmationFact(label: '安全', value: '达到上限会自动收口'),
            const SizedBox(height: 12),
            const Divider(color: StudioColors.border),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusPill(
                  label: snapshot.connectionStatus == ConnectionStatus.connected
                      ? '设备就绪'
                      : '设备提醒',
                  tone: snapshot.connectionStatus == ConnectionStatus.connected
                      ? StudioStatusTone.ready
                      : StudioStatusTone.warning,
                ),
                StatusPill(
                  label: workflowValidation.isValid ? '流程就绪' : '流程提醒',
                  tone: workflowValidation.isValid
                      ? StudioStatusTone.ready
                      : StudioStatusTone.warning,
                ),
                StatusPill(
                  label: _runStatusLabel(snapshot.runStatus),
                  tone: _toneForLiveRunStatus(snapshot.runStatus),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('execute-run-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          key: const ValueKey('execute-run-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          icon: const Icon(Icons.play_circle_outline, size: 18),
          label: Text(_executeRunButtonLabel(runMode, loops)),
        ),
      ],
    );
  }
}

// 确认弹窗中的单行事实，统一 label 宽度防止中文撑开。
class _ExecutionConfirmationFact extends StatelessWidget {
  const _ExecutionConfirmationFact({required this.label, required this.value});

  final String label;
  final String value;

  // 渲染确认弹窗中的键值内容。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: StudioColors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
