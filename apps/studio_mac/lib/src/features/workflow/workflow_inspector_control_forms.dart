part of '../../studio_mac_workspace.dart';

// Inspector 控制与视觉节点表单，负责 Loop、Snapshot、Condition、Visual Branch 和 Catch。

// Loop 参数字段，只支持有限轮数。
class _LoopParameterField extends StatelessWidget {
  const _LoopParameterField({required this.enabled, required this.controller});

  final bool enabled;
  final TextEditingController controller;

  // 渲染有限循环参数，并保留分支语义提示。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('node-inspector-loop-count'),
          controller: controller,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: _inspectorInputDecoration('数量'),
        ),
        const SizedBox(height: 8),
        const Text(
          '第一条为主体，第二条为后续。',
          style: TextStyle(color: StudioColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

// Snapshot 参数字段，只控制是否保存本地证据。
class _SnapshotParameterField extends StatelessWidget {
  const _SnapshotParameterField({
    required this.enabled,
    required this.saveEvidence,
    required this.onChanged,
  });

  final bool enabled;
  final bool saveEvidence;
  final ValueChanged<bool> onChanged;

  // 渲染证据开关，截图生命周期仍由本地 retention 规则控制。
  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      key: const ValueKey('node-inspector-save-evidence'),
      value: saveEvidence,
      onChanged: enabled ? (value) => onChanged(value ?? true) : null,
      title: const Text('保存证据'),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
    );
  }
}

// Condition 参数字段，表达式只允许读取安全上下文。
class _ConditionParameterField extends StatelessWidget {
  const _ConditionParameterField({
    required this.enabled,
    required this.controller,
  });

  final bool enabled;
  final TextEditingController controller;

  // 渲染条件表达式输入，草稿解析会再次校验白名单。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        key: const ValueKey('node-inspector-expression'),
        controller: controller,
        enabled: enabled,
        decoration: _inspectorInputDecoration('条件'),
      ),
    );
  }
}

// Visual Branch 参数字段，控制保守视觉判断阈值。
class _VisualBranchParameterField extends StatelessWidget {
  const _VisualBranchParameterField({
    required this.enabled,
    required this.controller,
  });

  final bool enabled;
  final TextEditingController controller;

  // 渲染置信阈值输入，低置信默认仍进入挂起态。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        key: const ValueKey('node-inspector-confidence'),
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _inspectorInputDecoration('置信阈值'),
      ),
    );
  }
}

// Wait For Target 参数字段，复用短中文文案隐藏底层 targetRef。
class _WaitForTargetParameterFields extends StatelessWidget {
  const _WaitForTargetParameterFields({
    required this.enabled,
    required this.targetController,
    required this.timeoutController,
    required this.intervalController,
    required this.confidenceController,
  });

  final bool enabled;
  final TextEditingController targetController;
  final TextEditingController timeoutController;
  final TextEditingController intervalController;
  final TextEditingController confidenceController;

  // 渲染目标、超时、间隔和置信阈值字段。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('node-inspector-wait-target-ref'),
            controller: targetController,
            enabled: enabled,
            decoration: _inspectorInputDecoration('目标'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('node-inspector-wait-target-timeout'),
                  controller: timeoutController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: _inspectorInputDecoration('超时'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('node-inspector-wait-target-interval'),
                  controller: intervalController,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: _inspectorInputDecoration('间隔'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('node-inspector-wait-target-confidence'),
            controller: confidenceController,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _inspectorInputDecoration('置信'),
          ),
        ],
      ),
    );
  }
}
