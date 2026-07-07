part of '../../studio_mac_workspace.dart';

// Workflow Inspector 空态，只表达当前选择状态。
// 不展示开发期路线或使用说明，保持主界面产品化。
class _WorkflowInspectorEmptyState extends StatelessWidget {
  const _WorkflowInspectorEmptyState();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('workflow-inspector-empty'),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.66),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.near_me_disabled_outlined,
              size: 18,
              color: StudioColors.muted,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '未选中',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: StudioColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
