part of '../studio_mac_workspace.dart';

// 设置抽屉基础控件，承载分区、开关和步进器的稳定布局。

// 设置分区卡片，统一抽屉内的标题和内边距。
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  /// 构建一个紧凑分区。
  /// 固定内边距和圆角，适配右侧抽屉宽度。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: StudioColors.background.withValues(alpha: 0.42),
          border: Border.all(color: StudioColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

// 设置开关行，负责展示只读或可写的二元偏好。
class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.label,
    required this.value,
    this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// 构建固定高度开关行。
  /// 标签省略显示，避免短中文在窄抽屉内撑开布局。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            key: ValueKey('settings-toggle-$label'),
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// 设置步进行，负责小范围数值偏好的本地调整。
class _SettingsStepperRow extends StatelessWidget {
  const _SettingsStepperRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  /// 渲染减少、数值和增加按钮。
  /// 到达边界时禁用按钮，避免调用方重复处理范围保护。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          IconButton.outlined(
            key: ValueKey('settings-stepper-decrease-$label'),
            tooltip: '减少 $label',
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove, size: 16),
          ),
          SizedBox(
            width: 88,
            child: Text(
              '$value $suffix',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.outlined(
            key: ValueKey('settings-stepper-increase-$label'),
            tooltip: '增加 $label',
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add, size: 16),
          ),
        ],
      ),
    );
  }
}
