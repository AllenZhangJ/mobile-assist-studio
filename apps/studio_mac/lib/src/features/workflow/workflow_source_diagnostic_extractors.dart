part of '../../studio_mac_workspace.dart';

// 把一条 validator 错误转换为 Source 诊断。
_WorkflowSourceDiagnostic _workflowSourceDiagnosticFromError(String error) {
  return _WorkflowSourceDiagnostic(
    message: error,
    nodeId: _nodeIdFromValidateError(error),
    field: _fieldFromValidateError(error),
    fallbackText: _fallbackTextFromValidateError(error),
  );
}

// 按节点 ID 聚合诊断，供画布和 Inspector 标记节点。
Map<String, List<_WorkflowSourceDiagnostic>> _workflowDiagnosticsByNodesId(
  WorkflowValidateResult validation,
) {
  final grouped = <String, List<_WorkflowSourceDiagnostic>>{};
  for (final error in validation.errors) {
    final diagnostic = _workflowSourceDiagnosticFromError(error);
    final nodeId = diagnostic.nodeId;
    if (nodeId == null) continue;
    grouped
        .putIfAbsent(nodeId, () => <_WorkflowSourceDiagnostic>[])
        .add(diagnostic);
  }
  return <String, List<_WorkflowSourceDiagnostic>>{
    for (final entry in grouped.entries)
      entry.key: List<_WorkflowSourceDiagnostic>.unmodifiable(entry.value),
  };
}

// 从 validator 文案中提取节点 ID。
String? _nodeIdFromValidateError(String error) {
  final duplicate = RegExp(r'节点 ID 重复：([^ .]+)').firstMatch(error);
  if (duplicate != null) return duplicate.group(1);
  final explicit = RegExp(
    r'(?:^| )(?:Nodes|Start node|End node|Tap node|Wait node|Condition node|Visual Branch node|Swipe node|Input node|Loop node|Catch node|Sub Workflow node) ([A-Za-z0-9_-]+)',
  ).firstMatch(error);
  if (explicit != null) return explicit.group(1);
  final unsafeExpression = RegExp(
    r'节点表达式不安全：([A-Za-z0-9_-]+)',
  ).firstMatch(error);
  if (unsafeExpression != null) return unsafeExpression.group(1);
  final missingWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) references missing workflow',
  ).firstMatch(error);
  if (missingWorkflow != null) return missingWorkflow.group(1);
  final selfWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) cannot reference itself\.$',
  ).firstMatch(error);
  if (selfWorkflow != null) return selfWorkflow.group(1);
  final recursiveWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) creates recursive workflow reference',
  ).firstMatch(error);
  if (recursiveWorkflow != null) return recursiveWorkflow.group(1);
  final missingNestedWorkflow = RegExp(
    r'^Sub Workflow node ([A-Za-z0-9_-]+) references workflow',
  ).firstMatch(error);
  return missingNestedWorkflow?.group(1);
}

// 从 validator 文案中提取字段名。
String? _fieldFromValidateError(String error) {
  if (error.startsWith('流程 ID')) return 'id';
  if (error.startsWith('流程名称')) return 'name';
  if (error.startsWith('入口节点')) return 'entryNodesId';
  if (error.startsWith('Entry node')) return 'entryNodesId';
  if (error.contains('visual position')) return 'visual';
  if (error.contains('condition expression')) return 'expression';
  if (error.contains('confidenceThreshold')) return 'confidenceThreshold';
  for (final field in ['fromX', 'fromY', 'toX', 'toY', 'durationMs']) {
    if (error.contains(field)) return field;
  }
  for (final field in [' x ', ' y ', ' ms ']) {
    if (error.contains(field)) return field.trim();
  }
  if (error.contains(' text ')) return 'text';
  if (error.contains(' count ')) return 'count';
  if (error.contains('maxRetries')) return 'maxRetries';
  if (error.contains('workflowId')) return 'workflowId';
  if (error.contains('inputMap')) return 'inputMap';
  if (error.contains('missing workflow')) return 'workflowId';
  if (error.contains('missing nested workflow')) return 'workflowId';
  if (error.contains('recursive workflow reference')) return 'workflowId';
  if (error.contains('onError')) return 'onError';
  if (error.contains('cannot reference itself')) return 'next';
  if (error.contains('only one main branch')) return 'next';
  if (error.contains('outgoing branches')) return 'next';
  if (error.contains('branch')) return 'next';
  if (error.contains('references missing node')) return 'next';
  return null;
}

// 提取诊断定位备用文本。
String? _fallbackTextFromValidateError(String error) {
  final missingEntry = RegExp(r'入口节点不存在：([^ .]+)').firstMatch(error);
  if (missingEntry != null) return missingEntry.group(1);
  final missingEntryEn = RegExp(
    r'Entry node does not exist: ([^ .]+)',
  ).firstMatch(error);
  if (missingEntryEn != null) return missingEntryEn.group(1);
  final missingNext = RegExp(
    r'references missing node ([^ .]+)',
  ).firstMatch(error);
  if (missingNext != null) return missingNext.group(1);
  final missingWorkflow = RegExp(
    r'references missing workflow ([^ .]+)',
  ).firstMatch(error);
  if (missingWorkflow != null) return missingWorkflow.group(1);
  final selfNext = RegExp(
    r'^Nodes ([A-Za-z0-9_-]+) cannot reference itself\.$',
  ).firstMatch(error);
  if (selfNext != null) return selfNext.group(1);
  return null;
}
