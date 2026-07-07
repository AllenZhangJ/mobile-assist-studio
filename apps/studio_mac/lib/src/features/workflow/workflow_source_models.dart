part of '../../studio_mac_workspace.dart';

// Source 草稿解析结果，保留 workflow、校验结果和解析错误。
final class _WorkflowSourceDraft {
  const _WorkflowSourceDraft({
    required this.workflow,
    required this.validation,
    required this.error,
  });

  final WorkflowDefinition? workflow;
  final WorkflowValidateResult? validation;
  final String? error;

  // 判断草稿是否能成为新的 Runtime 真源。
  bool get isValid => workflow != null && validation?.isValid == true;

  // 返回草稿状态短标签。
  String get statusLabel {
    if (error != null) return '源码错误';
    if (validation?.isValid == false) return '草稿提醒';
    return '草稿有效';
  }

  // 返回用户可读的错误或校验说明。
  String? get message {
    if (error != null) return error;
    final errors = validation?.errors;
    if (errors != null && errors.isNotEmpty) {
      return errors.map(_workflowDiagnosticMessage).join(' ');
    }
    return null;
  }

  // 将解析和校验信息转换成可点击诊断。
  List<_WorkflowSourceDiagnostic> get diagnostics {
    if (error != null) {
      return [
        _WorkflowSourceDiagnostic(
          message: error!,
          nodeId: null,
          field: null,
          fallbackText: null,
        ),
      ];
    }
    final errors = validation?.errors ?? const <String>[];
    return errors
        .map(_workflowSourceDiagnosticFromError)
        .toList(growable: false);
  }
}

// Source 诊断项，用于把 validator 错误映射回编辑器位置。
final class _WorkflowSourceDiagnostic {
  const _WorkflowSourceDiagnostic({
    required this.message,
    required this.nodeId,
    required this.field,
    required this.fallbackText,
  });

  final String message;
  final String? nodeId;
  final String? field;
  final String? fallbackText;

  // 返回诊断所在位置的短标签。
  String get locationLabel {
    final nodeId = this.nodeId;
    final field = this.field;
    if (nodeId != null && field != null) return '$nodeId / $field';
    if (nodeId != null) return '节点 $nodeId';
    if (field != null) return field;
    return '源码';
  }

  // 返回面向用户的诊断文案。
  String get displayMessage => _workflowDiagnosticMessage(message);

  // 返回面向普通用户的诊断位置，隐藏底层节点 ID 和字段名。
  String locationLabelForWorkflow(WorkflowDefinition workflow) {
    final nodeId = this.nodeId;
    final field = this.field;
    if (nodeId != null && field != null) {
      return '${_workflowDiagnosticNodeLabel(workflow, nodeId)} / ${_workflowDiagnosticFieldLabel(field)}';
    }
    if (nodeId != null) return _workflowDiagnosticNodeLabel(workflow, nodeId);
    if (field != null) return _workflowDiagnosticFieldLabel(field);
    return '源码';
  }

  // 返回带 workflow 上下文的短中文文案，供 Validate 和 Inspector 使用。
  String displayMessageForWorkflow(WorkflowDefinition workflow) {
    return _workflowDiagnosticMessageForWorkflow(message, workflow);
  }
}
