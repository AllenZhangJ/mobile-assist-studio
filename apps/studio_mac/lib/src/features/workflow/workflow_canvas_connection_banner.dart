part of '../../studio_mac_workspace.dart';

// 画布连接提示条，负责展示当前从哪个节点开始连线。
class _WorkflowConnectionBanner extends StatelessWidget {
  const _WorkflowConnectionBanner({
    required this.workflow,
    required this.sourceNodesId,
    required this.onCancel,
  });

  final WorkflowDefinition workflow;
  final String sourceNodesId;
  final VoidCallback onCancel;

  // 渲染连线中的轻提示，并提供取消连接入口。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.92),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.36)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_link_outlined, size: 16),
            const SizedBox(width: 8),
            Text(
              '从 ${_workflowNodeDisplayLabel(workflow, sourceNodesId)} 连接',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 6),
            SizedBox.square(
              dimension: 24,
              child: IconButton(
                tooltip: '取消连接',
                padding: EdgeInsets.zero,
                iconSize: 14,
                onPressed: onCancel,
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
