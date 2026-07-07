part of '../workflow_dsl.dart';

// _requiredInt 从旧 sequence 步骤里读取整数。
// 旧配置允许 num，这里统一取整后进入 Project DSL。
int _requiredInt(Map<String, Object?> step, String key, int index) {
  final value = step[key];
  if (value is int) return value;
  if (value is num && value.isFinite) return value.round();
  throw ArgumentError('Legacy sequence step $index requires integer $key.');
}

// _requiredString 从 Project DSL JSON 中读取必填字符串。
// 空字符串视为无效，避免坏 ID 或坏 label 进入模型。
String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Workflow field $key must be a non-empty string.');
}

// _nodeTypeFromName 将 JSON 字符串映射为节点类型。
// 未登记的节点类型会被拒绝，确保 DSL 是强类型。
WorkflowNodeType _nodeTypeFromName(String name) {
  for (final type in WorkflowNodeType.values) {
    if (type.name == name) return type;
  }
  throw FormatException('Unsupported workflow node type: $name.');
}

// _optionalStringList 读取可选字符串列表。
// next 边列表必须只包含字符串节点 ID。
List<String> _optionalStringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const <String>[];
  if (value is! List<Object?>) {
    throw FormatException('Workflow field $key must be a list.');
  }
  return value
      .map((entry) {
        if (entry is String) return entry;
        throw FormatException('Workflow field $key must contain strings.');
      })
      .toList(growable: false);
}

// _optionalObjectMap 读取可选对象参数。
// parameters 必须是普通对象，避免 Source View 写入非结构化值。
Map<String, Object?> _optionalObjectMap(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return const <String, Object?>{};
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.unmodifiable(value);
  }
  throw FormatException('Workflow field $key must be an object.');
}

// _optionalVisual 读取可选画布位置。
// 画布位置是编辑元数据，结构错误时仍要阻止保存。
WorkflowNodeVisual? _optionalVisual(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is Map<String, Object?>) return WorkflowNodeVisual.fromJson(value);
  throw FormatException('Workflow field $key must be an object.');
}

// _optionalDouble 读取有限数字坐标。
// 非有限值会破坏画布布局，必须在解析阶段拒绝。
double? _optionalDouble(Object? value) {
  if (value == null) return null;
  if (value is num && value.isFinite) return value.toDouble();
  throw const FormatException('Workflow visual coordinates must be finite.');
}
