part of '../../studio_mac_workspace.dart';

// 持续模式使用受控安全上限，避免真正无限运行失控。
const int _controlledContinuousRunLoops = 999;

// Execute 运行模式表达用户意图，最终仍转换为有限安全轮次。
enum _ExecuteRunMode {
  single('单次'),
  loop('循环'),
  continuous('持续');

  const _ExecuteRunMode(this.label);

  final String label;

  // 将模式转换为 Runtime 可执行的有限轮数。
  int effectiveLoops(int configuredLoops) {
    return switch (this) {
      _ExecuteRunMode.single => 1,
      _ExecuteRunMode.loop => configuredLoops,
      _ExecuteRunMode.continuous => _controlledContinuousRunLoops,
    };
  }

  // 生成面向用户的短摘要，避免各组件重复拼文案。
  String summary(int configuredLoops) {
    return switch (this) {
      _ExecuteRunMode.single => '单次 · 1 轮',
      _ExecuteRunMode.loop => '循环 · $configuredLoops 轮',
      _ExecuteRunMode.continuous => '持续 · 最多 $_controlledContinuousRunLoops 轮',
    };
  }
}

// 执行配置组件，负责准备状态、启动确认、停止和循环次数设置。
class _ExecuteConfigurationPanel extends StatelessWidget {
  const _ExecuteConfigurationPanel({
    required this.snapshot,
    required this.workflowValidation,
    required this.runMode,
    required this.loops,
    required this.effectiveLoops,
    required this.onRunModeChanged,
    required this.onLoopsChanged,
  });

  final StudioRuntimeSnapshot snapshot;
  final WorkflowValidateResult workflowValidation;
  final _ExecuteRunMode runMode;
  final int loops;
  final int effectiveLoops;
  final ValueChanged<_ExecuteRunMode> onRunModeChanged;
  final ValueChanged<int> onLoopsChanged;

  // 根据当前模式生成短摘要，供配置区和确认弹窗保持一致。
  String get _modeSummary => runMode.summary(loops);

  // 渲染运行设置，保持“摘要优先、细节后置”的执行页原则。
  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '运行设置',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              '串行执行，安全停止。',
              style: TextStyle(color: StudioColors.muted, height: 1.35),
            ),
            const SizedBox(height: 16),
            const Text('模式', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _ExecuteRunModePicker(mode: runMode, onChanged: onRunModeChanged),
            const SizedBox(height: 12),
            _DeviceFactRow(label: '计划', value: _modeSummary),
            const SizedBox(height: 10),
            _DeviceFactRow(label: '流程', value: snapshot.workflow.name),
            const SizedBox(height: 10),
            _DeviceFactRow(
              label: '节点',
              value: '${snapshot.workflow.nodes.length}',
            ),
            const SizedBox(height: 18),
            const Text('轮数', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _LoopStepper(
                loops: effectiveLoops,
                enabled: runMode == _ExecuteRunMode.loop,
                onChanged: onLoopsChanged,
              ),
            ),
            if (runMode != _ExecuteRunMode.loop) ...[
              const SizedBox(height: 8),
              Text(
                runMode == _ExecuteRunMode.single
                    ? '单次模式固定 1 轮。'
                    : '持续模式最多 $_controlledContinuousRunLoops 轮，可随时停止。',
                style: TextStyle(
                  color: StudioColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _ExecuteReadinessPanel(
              snapshot: snapshot,
              workflowValidation: workflowValidation,
            ),
          ],
        ),
      ),
    );
  }
}

// 单次/循环切换控件，只修改本地页面配置，不直接启动运行。
class _ExecuteRunModePicker extends StatelessWidget {
  const _ExecuteRunModePicker({required this.mode, required this.onChanged});

  final _ExecuteRunMode mode;
  final ValueChanged<_ExecuteRunMode> onChanged;

  // 渲染模式选择，保持选项短文案和固定尺寸。
  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ExecuteRunMode>(
      key: const ValueKey('execute-run-mode-picker'),
      segments: const [
        ButtonSegment(
          value: _ExecuteRunMode.single,
          icon: Icon(Icons.looks_one, size: 16),
          label: Text('单次', overflow: TextOverflow.ellipsis),
        ),
        ButtonSegment(
          value: _ExecuteRunMode.loop,
          icon: Icon(Icons.repeat, size: 16),
          label: Text('循环', overflow: TextOverflow.ellipsis),
        ),
        ButtonSegment(
          value: _ExecuteRunMode.continuous,
          icon: Icon(Icons.all_inclusive, size: 16),
          label: Text('持续', overflow: TextOverflow.ellipsis),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => onChanged(selection.single),
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
