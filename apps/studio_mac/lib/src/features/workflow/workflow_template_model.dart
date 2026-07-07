part of '../../studio_mac_workspace.dart';

// Workflow 模板数据模型，描述模板卡片和对应 Project DSL。
final class _WorkflowTemplate {
  const _WorkflowTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.icon,
    required this.workflow,
  });

  final String id;
  final String name;
  final String category;
  final String description;
  final IconData icon;
  final WorkflowDefinition workflow;
}
