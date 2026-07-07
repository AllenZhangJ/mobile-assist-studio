part of '../../studio_mac_workspace.dart';

// 执行命令面板，集中处理启动、停止、暂停解除和连接快捷动作。
class _ExecuteCommandPanel extends StatelessWidget {
  const _ExecuteCommandPanel({
    required this.snapshot,
    required this.workflowValidation,
    required this.controller,
    required this.runMode,
    required this.loops,
  });

  final StudioRuntimeSnapshot snapshot;
  final WorkflowValidateResult workflowValidation;
  final StudioRuntimeController controller;
  final _ExecuteRunMode runMode;
  final int loops;

  // 渲染主执行区，所有按钮仍通过 Runtime Controller 串行提交。
  @override
  Widget build(BuildContext context) {
    final canRun =
        snapshot.connectionStatus == ConnectionStatus.connected &&
        snapshot.runStatus == RunStatus.idle &&
        workflowValidation.isValid;
    final canStop =
        snapshot.runStatus == RunStatus.running ||
        snapshot.runStatus == RunStatus.stopping ||
        snapshot.runStatus == RunStatus.paused;
    final paused = snapshot.runStatus == RunStatus.paused;
    final headline = paused
        ? '等待处理'
        : snapshot.runStatus == RunStatus.running
        ? '流程运行中'
        : '可运行';
    final body = paused
        ? '自动化已暂停，请确认节点和设备后继续。'
        : snapshot.runStatus == RunStatus.running
        ? '流程正在串行运行，停止会在当前动作后生效。'
        : _executeReadyMessage(
            snapshot,
            workflowIsValid: workflowValidation.isValid,
          );

    return _Surface(
      child: Column(
        key: const ValueKey('execute-command-center'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  headline,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusPill(
                label: _runStatusLabel(snapshot.runStatus),
                tone: _toneForLiveRunStatus(snapshot.runStatus),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(color: StudioColors.muted, height: 1.45),
          ),
          if (snapshot.lastConnectionDiagnostic != null &&
              snapshot.connectionStatus != ConnectionStatus.connected) ...[
            const SizedBox(height: 14),
            _ConnectionDiagnosticCard(
              diagnostic: snapshot.lastConnectionDiagnostic!,
              title: '先处理连接',
            ),
          ],
          const SizedBox(height: 22),
          _ExecutionProgressBar(snapshot: snapshot),
          const SizedBox(height: 22),
          _ConnectPrimaryAction(
            snapshot: snapshot,
            controller: controller,
            controlKey: const ValueKey('execute-connect-one-button'),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ExecutePrimaryButton(
                controlKey: const ValueKey('execute-run-selected'),
                label: _executeRunButtonLabel(runMode, loops),
                icon: Icons.play_circle_outline,
                onPressed: canRun
                    ? () => _confirmAndRunWorkflow(
                        context,
                        snapshot: snapshot,
                        workflowValidation: workflowValidation,
                        controller: controller,
                        runMode: runMode,
                        loops: loops,
                      )
                    : null,
              ),
              _CommandButton(
                controlKey: const ValueKey('execute-stop-or-resolve'),
                label: paused ? '解除暂停' : '停止',
                icon: paused
                    ? Icons.pause_circle_filled_outlined
                    : Icons.stop_circle_outlined,
                onPressed: canStop
                    ? paused
                          ? () => controller.resolvePause()
                          : () => controller.stopRun()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
