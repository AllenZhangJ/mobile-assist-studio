part of '../../studio_mac_workspace.dart';

// 录制动作详情的字段控件和输入解析 helper。
// 该文件只处理表单展示与安全归一，不持有录制动作状态。

// 抽屉字段行，统一详情里的只读文本样式。
class _DrawerField extends StatelessWidget {
  const _DrawerField({required this.label, required this.value});

  final String label;
  final String value;

  // 渲染一组只读字段，便于复制但不暴露额外底层信息。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: StudioColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 5),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
          ),
        ],
      ),
    );
  }
}

// 抽屉编辑字段，统一录制动作可编辑参数样式。
class _DrawerEditField extends StatelessWidget {
  const _DrawerEditField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  // 渲染单个编辑字段，保持中文短标签和紧凑宽度。
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }
}

// 解析整数输入并限制范围，避免坏输入进入 Project DSL。
int _boundedInt(String text, int fallback, int min, int max) {
  final parsed = int.tryParse(text.trim()) ?? fallback;
  return parsed.clamp(min, max).toInt();
}

// 读取非空短文本，空输入会回退到原值。
String _nonEmpty(String text, String fallback) {
  final value = text.trim();
  return value.isEmpty ? fallback : value;
}
