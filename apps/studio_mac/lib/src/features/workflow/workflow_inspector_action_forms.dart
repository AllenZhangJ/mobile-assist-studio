part of '../../studio_mac_workspace.dart';

// Inspector 动作节点表单，负责 Tap、Wait、Swipe 和 Input 参数字段。

// Tap 参数字段，保持坐标输入并排展示。
class _TapParameterFields extends StatelessWidget {
  const _TapParameterFields({
    required this.enabled,
    required this.xController,
    required this.yController,
  });

  final bool enabled;
  final TextEditingController xController;
  final TextEditingController yController;

  // 渲染点击坐标输入，坐标仍作为高级编辑信息放在 Inspector 内。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('node-inspector-x'),
              controller: xController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: _inspectorInputDecoration('横'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const ValueKey('node-inspector-y'),
              controller: yController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              decoration: _inspectorInputDecoration('纵'),
            ),
          ),
        ],
      ),
    );
  }
}

// Wait 参数字段，只编辑等待时长。
class _WaitParameterField extends StatelessWidget {
  const _WaitParameterField({required this.enabled, required this.controller});

  final bool enabled;
  final TextEditingController controller;

  // 渲染等待时长输入，运行时仍由 DSL validator 做最终兜底。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        key: const ValueKey('node-inspector-ms'),
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: _inspectorInputDecoration('等待'),
      ),
    );
  }
}

// Swipe 参数字段，集中管理起点、终点和时长。
class _SwipeParameterFields extends StatelessWidget {
  const _SwipeParameterFields({
    required this.enabled,
    required this.fromXController,
    required this.fromYController,
    required this.toXController,
    required this.toYController,
    required this.durationController,
  });

  final bool enabled;
  final TextEditingController fromXController;
  final TextEditingController fromYController;
  final TextEditingController toXController;
  final TextEditingController toYController;
  final TextEditingController durationController;

  // 渲染滑动参数表单，避免主 Inspector 直接堆叠手势字段。
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('node-inspector-from-x'),
                controller: fromXController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: _inspectorInputDecoration('起横'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('node-inspector-from-y'),
                controller: fromYController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: _inspectorInputDecoration('起纵'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('node-inspector-to-x'),
                controller: toXController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: _inspectorInputDecoration('终横'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const ValueKey('node-inspector-to-y'),
                controller: toYController,
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: _inspectorInputDecoration('终纵'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('node-inspector-duration-ms'),
          controller: durationController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: _inspectorInputDecoration('时长'),
        ),
      ],
    );
  }
}

// Input 参数字段，只保存用户输入内容草稿。
class _InputParameterField extends StatelessWidget {
  const _InputParameterField({required this.enabled, required this.controller});

  final bool enabled;
  final TextEditingController controller;

  // 渲染输入文本字段，日志和证据仍由 Runtime 做脱敏。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: TextField(
        key: const ValueKey('node-inspector-input-text'),
        controller: controller,
        enabled: enabled,
        decoration: _inspectorInputDecoration('文本'),
      ),
    );
  }
}
