part of '../../studio_mac_workspace.dart';

// Workflow 校验视图，负责把 DSL 校验结果展示成用户可读列表。
class _WorkflowValidateView extends StatelessWidget {
  const _WorkflowValidateView({
    required this.workflow,
    required this.validation,
    required this.onSelectDiagnostic,
  });

  final WorkflowDefinition workflow;
  final WorkflowValidateResult validation;
  final ValueChanged<_WorkflowSourceDiagnostic> onSelectDiagnostic;

  // 渲染离线校验结果，并把诊断转换为用户可读文案。
  @override
  Widget build(BuildContext context) {
    if (validation.isValid) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, color: StudioColors.green, size: 44),
            SizedBox(height: 12),
            Text('流程检查通过', style: TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      );
    }
    final diagnostics = validation.errors
        .map(_workflowSourceDiagnosticFromError)
        .toList(growable: false);
    return ListView.separated(
      itemCount: diagnostics.length,
      separatorBuilder: (_, _) =>
          const Divider(color: StudioColors.border, height: 12),
      itemBuilder: (context, index) {
        final diagnostic = diagnostics[index];
        return _WorkflowDiagnosticRow(
          rowKey: ValueKey('workflow-validation-diagnostic-$index'),
          icon: Icons.warning_amber_outlined,
          label: diagnostic.locationLabelForWorkflow(workflow),
          message: diagnostic.displayMessageForWorkflow(workflow),
          onTap: () => onSelectDiagnostic(diagnostic),
        );
      },
    );
  }
}
