part of '../../studio_mac_workspace.dart';

// 录制控制组件，负责开始、停止、追加动作和生成流程入口。
class _RecorderControls extends StatelessWidget {
  const _RecorderControls({
    required this.recording,
    required this.actionCount,
    required this.onStart,
    required this.onStop,
    required this.onAddTap,
    required this.onAddWait,
    required this.onAddSwipe,
    required this.onAddInput,
    required this.onClear,
    required this.onPromote,
    required this.workflowGenerated,
    required this.onOpenWorkflow,
    required this.onOpenExecute,
  });

  final bool recording;
  final int actionCount;
  final bool workflowGenerated;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback? onAddTap;
  final VoidCallback? onAddWait;
  final VoidCallback? onAddSwipe;
  final VoidCallback? onAddInput;
  final VoidCallback? onClear;
  final Future<void> Function()? onPromote;
  final VoidCallback onOpenWorkflow;
  final VoidCallback onOpenExecute;

  // 渲染录制按钮组，并根据状态禁用不可用操作。
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(
                  label: recording ? '录制中' : '录制空闲',
                  tone: recording
                      ? StudioStatusTone.error
                      : StudioStatusTone.offline,
                ),
                Text(
                  '$actionCount 个动作',
                  style: const TextStyle(
                    color: StudioColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              '录制',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              '先录制易懂动作，坐标默认隐藏。',
              style: TextStyle(color: StudioColors.muted, height: 1.45),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: recording ? null : onStart,
                  icon: const Icon(Icons.radio_button_checked, size: 18),
                  label: const Text('开始录制'),
                ),
                FilledButton.icon(
                  onPressed: recording ? onStop : null,
                  icon: const Icon(Icons.stop_circle_outlined, size: 18),
                  label: const Text('停止'),
                ),
                OutlinedButton.icon(
                  onPressed: onAddTap,
                  icon: const Icon(Icons.touch_app_outlined, size: 18),
                  label: const Text('加点击'),
                ),
                OutlinedButton.icon(
                  onPressed: onAddWait,
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('加等待'),
                ),
                OutlinedButton.icon(
                  onPressed: onAddSwipe,
                  icon: const Icon(Icons.swipe_outlined, size: 18),
                  label: const Text('加滑动'),
                ),
                OutlinedButton.icon(
                  onPressed: onAddInput,
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                  label: const Text('加输入'),
                ),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('清空'),
                ),
                FilledButton.icon(
                  key: const ValueKey('promote-recorder-workflow'),
                  onPressed: onPromote == null
                      ? null
                      : () => unawaited(onPromote!()),
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: const Text('生成流程'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('recorder-open-workflow'),
                  onPressed: workflowGenerated ? onOpenWorkflow : null,
                  icon: const Icon(Icons.account_tree_outlined, size: 18),
                  label: const Text('看流程'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('recorder-open-execute'),
                  onPressed: workflowGenerated ? onOpenExecute : null,
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: const Text('去运行'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
