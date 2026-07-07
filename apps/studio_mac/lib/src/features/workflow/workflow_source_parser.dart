part of '../../studio_mac_workspace.dart';

// 将 workflow 序列化成可编辑的 Project DSL JSON。
String _workflowSourceText(WorkflowDefinition workflow) {
  const encoder = JsonEncoder.withIndent('  ');
  return encoder.convert(workflow.toJson());
}

// 解析 Source JSON，并同步运行 workflow validator。
_WorkflowSourceDraft _parseWorkflowSource(
  String source,
  List<SubWorkflowSummary> subWorkflows,
) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('源码必须是 JSON 对象。');
    }
    final workflow = WorkflowDefinition.fromJson(decoded);
    final validation = _workflowProjectValidation(workflow, subWorkflows);
    return _WorkflowSourceDraft(
      workflow: workflow,
      validation: validation,
      error: null,
    );
  } on FormatException catch (error) {
    return _WorkflowSourceDraft(
      workflow: null,
      validation: null,
      error: error.message,
    );
  } on Object catch (error) {
    return _WorkflowSourceDraft(
      workflow: null,
      validation: null,
      error: '源码无法解析：$error',
    );
  }
}
