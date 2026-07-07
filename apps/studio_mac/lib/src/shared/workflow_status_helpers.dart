part of '../studio_mac_workspace.dart';

// Workflow 状态 helper，统一 UI 对 Project DSL 和本地子流程引用的判断。
WorkflowValidateResult _workflowProjectValidation(
  WorkflowDefinition workflow,
  List<SubWorkflowSummary> subWorkflows,
) {
  final dslValidation = const WorkflowValidator().validate(workflow);
  final availableSubWorkflowIds = subWorkflows
      .map((summary) => summary.workflowId)
      .toSet();
  final referencesByWorkflowId = <String, Set<String>>{
    for (final summary in subWorkflows)
      summary.workflowId: summary.referencedWorkflowIds.toSet(),
  };
  final referenceIssues = WorkflowReferenceValidator.validate(
    workflow,
    availableSubWorkflowIds: availableSubWorkflowIds,
    referencesByWorkflowId: referencesByWorkflowId,
  );
  return WorkflowValidateResult.fromErrors([
    ...dslValidation.errors,
    for (final issue in referenceIssues) issue.message,
  ]);
}

// 从 Runtime 快照生成项目级 workflow 校验，供所有页面复用同一结论。
WorkflowValidateResult _snapshotWorkflowValidation(
  StudioRuntimeSnapshot snapshot,
) {
  return _workflowProjectValidation(snapshot.workflow, snapshot.subWorkflows);
}

// 返回 workflow 是否可作为运行入口，包含 DSL 和子流程引用校验。
bool _snapshotWorkflowIsRunnable(StudioRuntimeSnapshot snapshot) {
  return _snapshotWorkflowValidation(snapshot).isValid;
}

// 将校验结果转换为顶部状态和详情抽屉的短标签。
String _workflowStatusLabel(WorkflowValidateResult validation) {
  return validation.isValid ? '流程就绪' : '流程提醒';
}

// 将校验结果转换为统一状态色，避免各页面自行判断。
StudioStatusTone _workflowStatusTone(WorkflowValidateResult validation) {
  return validation.isValid ? StudioStatusTone.ready : StudioStatusTone.warning;
}

// 返回第一条用户可读的 workflow 问题，适合摘要区和调试区展示。
String _workflowIssueSummary(WorkflowValidateResult validation) {
  if (validation.isValid) return '当前流程校验通过。';
  if (validation.errors.isEmpty) return '流程需先校验。';
  final first = validation.errors.first;
  return _workflowDiagnosticMessage(first);
}
