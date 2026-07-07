part of '../../studio_mac_workspace.dart';

// Workflow 诊断行，统一 Source 与 Validate 的可点击问题展示。
class _WorkflowDiagnosticRow extends StatelessWidget {
  const _WorkflowDiagnosticRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.message,
    required this.onTap,
    this.messageStyle,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final String message;
  final VoidCallback onTap;
  final TextStyle? messageStyle;

  // 渲染一条可定位诊断，避免多个视图重复维护同类布局。
  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: rowKey,
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: StudioColors.amber),
            const SizedBox(width: 8),
            StatusPill(label: label, tone: StudioStatusTone.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: messageStyle ?? const TextStyle(height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
