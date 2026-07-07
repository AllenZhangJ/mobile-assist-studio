part of '../../studio_mac_workspace.dart';

// 节点参数表单入口，只负责按节点类型分发到具体字段分片。
class _NodeInspectorParameterFields extends StatelessWidget {
  const _NodeInspectorParameterFields({
    required this.workflow,
    required this.node,
    required this.locked,
    required this.saving,
    required this.xController,
    required this.yController,
    required this.msController,
    required this.fromXController,
    required this.fromYController,
    required this.toXController,
    required this.toYController,
    required this.durationController,
    required this.textController,
    required this.loopCountController,
    required this.expressionController,
    required this.confidenceController,
    required this.maxRetriesController,
    required this.onErrorController,
    required this.workflowIdController,
    required this.inputMapController,
    required this.saveEvidence,
    required this.onSaveEvidenceChanged,
    required this.subWorkflows,
    required this.onAddStarterSubWorkflow,
    required this.onAddCurrentAsSubWorkflow,
    required this.onDeleteSubWorkflow,
  });

  final WorkflowDefinition workflow;
  final WorkflowNode node;
  final bool locked;
  final bool saving;
  final TextEditingController xController;
  final TextEditingController yController;
  final TextEditingController msController;
  final TextEditingController fromXController;
  final TextEditingController fromYController;
  final TextEditingController toXController;
  final TextEditingController toYController;
  final TextEditingController durationController;
  final TextEditingController textController;
  final TextEditingController loopCountController;
  final TextEditingController expressionController;
  final TextEditingController confidenceController;
  final TextEditingController maxRetriesController;
  final TextEditingController onErrorController;
  final TextEditingController workflowIdController;
  final TextEditingController inputMapController;
  final bool saveEvidence;
  final ValueChanged<bool> onSaveEvidenceChanged;
  final List<SubWorkflowSummary> subWorkflows;
  final VoidCallback? onAddStarterSubWorkflow;
  final VoidCallback? onAddCurrentAsSubWorkflow;
  final ValueChanged<SubWorkflowSummary>? onDeleteSubWorkflow;

  // 渲染当前节点类型对应的参数表单，避免主 Inspector 混入所有字段细节。
  @override
  Widget build(BuildContext context) {
    final enabled = !locked && !saving;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (node.type == WorkflowNodeType.tap)
          _TapParameterFields(
            enabled: enabled,
            xController: xController,
            yController: yController,
          ),
        if (node.type == WorkflowNodeType.wait)
          _WaitParameterField(enabled: enabled, controller: msController),
        if (node.type == WorkflowNodeType.swipe)
          _SwipeParameterFields(
            enabled: enabled,
            fromXController: fromXController,
            fromYController: fromYController,
            toXController: toXController,
            toYController: toYController,
            durationController: durationController,
          ),
        if (node.type == WorkflowNodeType.input)
          _InputParameterField(enabled: enabled, controller: textController),
        if (node.type == WorkflowNodeType.loop)
          _LoopParameterField(
            enabled: enabled,
            controller: loopCountController,
          ),
        if (node.type == WorkflowNodeType.snapshot)
          _SnapshotParameterField(
            enabled: enabled,
            saveEvidence: saveEvidence,
            onChanged: onSaveEvidenceChanged,
          ),
        if (node.type == WorkflowNodeType.condition)
          _ConditionParameterField(
            enabled: enabled,
            controller: expressionController,
          ),
        if (node.type == WorkflowNodeType.visualBranch)
          _VisualBranchParameterField(
            enabled: enabled,
            controller: confidenceController,
          ),
        if (node.type == WorkflowNodeType.waitForTarget)
          _WaitForTargetParameterFields(
            enabled: enabled,
            targetController: textController,
            timeoutController: msController,
            intervalController: durationController,
            confidenceController: confidenceController,
          ),
        if (node.type == WorkflowNodeType.catchNodes)
          _CatchParameterFields(
            enabled: enabled,
            workflow: workflow,
            node: node,
            maxRetriesController: maxRetriesController,
            onErrorController: onErrorController,
          ),
        if (node.type == WorkflowNodeType.subWorkflow)
          _SubWorkflowParameterFields(
            enabled: enabled,
            workflowIdController: workflowIdController,
            inputMapController: inputMapController,
            subWorkflows: subWorkflows,
            onAddStarterSubWorkflow: onAddStarterSubWorkflow,
            onAddCurrentAsSubWorkflow: onAddCurrentAsSubWorkflow,
            onDeleteSubWorkflow: onDeleteSubWorkflow,
          ),
      ],
    );
  }
}
