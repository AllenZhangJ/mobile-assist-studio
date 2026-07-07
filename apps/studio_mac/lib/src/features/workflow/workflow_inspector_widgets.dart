part of '../../studio_mac_workspace.dart';

// Workflow Inspector 小组件，负责边标签和属性行等轻量展示。
class _EdgePill extends StatelessWidget {
  const _EdgePill({
    super.key,
    required this.label,
    required this.removeButtonKey,
    required this.onRemove,
  });

  final String label;
  final Key removeButtonKey;
  final VoidCallback? onRemove;

  // 渲染连接标签和删除入口，显示文案与稳定操作 key 分离。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.cyan.withValues(alpha: 0.10),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call_split_outlined, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 2),
            SizedBox.square(
              dimension: 24,
              child: IconButton(
                key: removeButtonKey,
                tooltip: '删除连接 $label',
                padding: EdgeInsets.zero,
                iconSize: 14,
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _NodeInspectorDraft {
  const _NodeInspectorDraft({required this.node, required this.error});

  final WorkflowNode node;
  final String? error;
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(color: StudioColors.muted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

// 生成 Inspector 输入框的统一样式。
// 该样式保持暗色工作站视觉，并复用同一聚焦边框。
InputDecoration _inspectorInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: StudioColors.muted),
    filled: true,
    fillColor: const Color(0xFF030609),
    enabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: StudioColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: StudioColors.cyan),
      borderRadius: BorderRadius.circular(8),
    ),
    disabledBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: StudioColors.border),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}
