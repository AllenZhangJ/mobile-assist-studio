part of '../../studio_mac_workspace.dart';

// Source 编辑器选区 helper，负责把诊断项定位到 JSON 文本片段。
// 该文件只移动编辑器光标，不保存 workflow、不触发 Runtime 命令。

// 在 Source 编辑器中选中诊断对应片段。
void _selectWorkflowSourceDiagnostic(
  TextEditingController controller,
  _WorkflowSourceDiagnostic diagnostic,
) {
  final text = controller.text;
  final nodeFieldIndex = _fieldIndexInNodeSource(
    text: text,
    nodeId: diagnostic.nodeId,
    field: diagnostic.field,
  );
  if (nodeFieldIndex != null) {
    final field = diagnostic.field!;
    final candidate = '"$field"';
    controller.selection = TextSelection(
      baseOffset: nodeFieldIndex,
      extentOffset: nodeFieldIndex + candidate.length,
    );
    return;
  }
  final candidates = <String>[
    if (diagnostic.nodeId case final nodeId?) '"id": "$nodeId"',
    if (diagnostic.field case final field?) '"$field"',
    if (diagnostic.fallbackText case final fallback?) fallback,
  ];
  for (final candidate in candidates) {
    final index = text.indexOf(candidate);
    if (index < 0) continue;
    controller.selection = TextSelection(
      baseOffset: index,
      extentOffset: index + candidate.length,
    );
    return;
  }
  controller.selection = TextSelection.collapsed(offset: text.length);
}

// 在节点对象范围内寻找字段，避免 Source 诊断跳到其它节点的同名字段。
int? _fieldIndexInNodeSource({
  required String text,
  required String? nodeId,
  required String? field,
}) {
  if (nodeId == null || field == null) return null;
  final idNeedle = '"id": "$nodeId"';
  final idIndex = text.indexOf(idNeedle);
  if (idIndex < 0) return null;
  final nodeStart = text.lastIndexOf('{', idIndex);
  if (nodeStart < 0) return null;
  final nodeEnd = _matchingJsonObjectEnd(text, nodeStart);
  if (nodeEnd == null) return null;
  final fieldNeedle = '"$field"';
  final fieldIndex = text.indexOf(fieldNeedle, nodeStart);
  if (fieldIndex < 0 || fieldIndex > nodeEnd) return null;
  return fieldIndex;
}

// 找到 JSON 对象闭合位置，字符串里的括号不会参与计数。
int? _matchingJsonObjectEnd(String text, int start) {
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var index = start; index < text.length; index += 1) {
    final char = text[index];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (char == '\\') {
      escaped = inString;
      continue;
    }
    if (char == '"') {
      inString = !inString;
      continue;
    }
    if (inString) continue;
    if (char == '{') depth += 1;
    if (char == '}') {
      depth -= 1;
      if (depth == 0) return index;
    }
  }
  return null;
}
