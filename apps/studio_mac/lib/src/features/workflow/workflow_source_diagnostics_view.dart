part of '../../studio_mac_workspace.dart';

// Source 诊断列表，负责展示 JSON 位置和可点击定位入口。
class _WorkflowSourceDiagnostics extends StatelessWidget {
  const _WorkflowSourceDiagnostics({
    required this.diagnostics,
    required this.onSelect,
  });

  final List<_WorkflowSourceDiagnostic> diagnostics;
  final ValueChanged<_WorkflowSourceDiagnostic> onSelect;

  // 渲染源码级诊断，保留底层位置以便精确定位 JSON。
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('workflow-source-diagnostics'),
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 156),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.42),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: diagnostics.length,
        separatorBuilder: (_, _) =>
            const Divider(color: StudioColors.border, height: 12),
        itemBuilder: (context, index) {
          final diagnostic = diagnostics[index];
          return _WorkflowDiagnosticRow(
            rowKey: ValueKey('workflow-source-diagnostic-$index'),
            icon: Icons.manage_search_outlined,
            label: diagnostic.locationLabel,
            message: diagnostic.displayMessage,
            onTap: () => onSelect(diagnostic),
            messageStyle: const TextStyle(fontSize: 12, height: 1.35),
          );
        },
      ),
    );
  }
}
