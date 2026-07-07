part of '../../studio_mac_workspace.dart';

// Workflow 页面级枚举，负责切换画布、源码和检查视图。
enum _WorkflowTab {
  visual('画布', Icons.account_tree_outlined),
  source('源码', Icons.data_object_outlined),
  validate('检查', Icons.verified_outlined);

  const _WorkflowTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
