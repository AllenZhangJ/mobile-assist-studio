part of '../../studio_mac_workspace.dart';

// Workflow Inspector 编辑器入口声明，具体内容拆到 editor、diagnostics 和 context panel 分片。
class _NodeInspectorEditor extends StatefulWidget {
  const _NodeInspectorEditor({
    required this.workflow,
    required this.node,
    required this.subWorkflows,
    required this.diagnostics,
    required this.locked,
    required this.saving,
    required this.savingGraphEdit,
    required this.onSave,
    required this.onAddEdge,
    required this.onRemoveEdge,
    required this.onInsertNodes,
    required this.onDuplicateNodes,
    required this.onDeleteNodes,
    required this.onAddStarterSubWorkflow,
    required this.onAddCurrentAsSubWorkflow,
    required this.onDeleteSubWorkflow,
  });

  final WorkflowDefinition workflow;
  final WorkflowNode node;
  final List<SubWorkflowSummary> subWorkflows;
  final List<_WorkflowSourceDiagnostic> diagnostics;
  final bool locked;
  final bool saving;
  final bool savingGraphEdit;
  final ValueChanged<WorkflowNode> onSave;
  final ValueChanged<String>? onAddEdge;
  final ValueChanged<String>? onRemoveEdge;
  final ValueChanged<WorkflowNodeType>? onInsertNodes;
  final VoidCallback? onDuplicateNodes;
  final VoidCallback? onDeleteNodes;
  final VoidCallback? onAddStarterSubWorkflow;
  final VoidCallback? onAddCurrentAsSubWorkflow;
  final ValueChanged<SubWorkflowSummary>? onDeleteSubWorkflow;

  // 创建节点编辑器状态，具体控制器生命周期由 State 分片维护。
  @override
  State<_NodeInspectorEditor> createState() => _NodeInspectorEditorState();
}
