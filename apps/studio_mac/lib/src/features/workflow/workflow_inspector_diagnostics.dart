part of '../../studio_mac_workspace.dart';

// Workflow Inspector 节点诊断面板，只负责展示 validator 映射后的用户问题。
class _NodeInspectorDiagnostics extends StatelessWidget {
  const _NodeInspectorDiagnostics({
    required this.workflow,
    required this.diagnostics,
  });

  final WorkflowDefinition workflow;
  final List<_WorkflowSourceDiagnostic> diagnostics;

  // 渲染节点级问题摘要，展示层隐藏底层 ID。
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('node-inspector-diagnostics'),
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.amber.withValues(alpha: 0.08),
        border: Border.all(color: StudioColors.amber.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill(
            label: '${diagnostics.length} 个问题',
            tone: StudioStatusTone.warning,
          ),
          const SizedBox(height: 8),
          for (final diagnostic in diagnostics)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                diagnostic.displayMessageForWorkflow(workflow),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudioColors.text,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
