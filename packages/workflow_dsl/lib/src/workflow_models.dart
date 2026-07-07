part of '../workflow_dsl.dart';

// WorkflowNodeType 定义 Project DSL 支持的节点类型。
// 新节点进入 DSL 前必须先在这里登记，再补 validator 与 Runtime 语义。
enum WorkflowNodeType {
  start,
  tap,
  wait,
  swipe,
  input,
  snapshot,
  condition,
  visualBranch,
  waitForTarget,
  loop,
  catchNodes,
  subWorkflow,
  end,
}

// WorkflowNodeVisual 保存节点在画布上的可选位置。
// 位置只影响编辑器展示，不影响 Runtime 执行语义。
final class WorkflowNodeVisual {
  // 创建节点画布位置。
  const WorkflowNodeVisual({this.x, this.y});

  final double? x;
  final double? y;

  // 判断位置是否完整，避免只有 x 或 y 的半状态进入画布。
  bool get hasPosition => x != null && y != null;

  // 序列化画布位置，空值不写入 Project DSL。
  Map<String, Object?> toJson() {
    return <String, Object?>{if (x != null) 'x': x, if (y != null) 'y': y};
  }

  // 从 Project DSL JSON 恢复画布位置。
  static WorkflowNodeVisual fromJson(Map<String, Object?> json) {
    return WorkflowNodeVisual(
      x: _optionalDouble(json['x']),
      y: _optionalDouble(json['y']),
    );
  }
}

// WorkflowNode 是 Project DSL 的节点模型。
// 它只描述结构和参数，不直接包含运行时状态。
final class WorkflowNode {
  // 创建工作流节点。
  const WorkflowNode({
    required this.id,
    required this.type,
    required this.label,
    this.next = const <String>[],
    this.parameters = const <String, Object?>{},
    this.visual,
  });

  final String id;
  final WorkflowNodeType type;
  final String label;
  final List<String> next;
  final Map<String, Object?> parameters;
  final WorkflowNodeVisual? visual;

  // 序列化节点，省略空连接、空参数和空画布位置。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'label': label,
      if (next.isNotEmpty) 'next': next,
      if (parameters.isNotEmpty) 'parameters': parameters,
      if (visual case final visual? when visual.toJson().isNotEmpty)
        'visual': visual.toJson(),
    };
  }

  // 从 Project DSL JSON 恢复节点。
  static WorkflowNode fromJson(Map<String, Object?> json) {
    return WorkflowNode(
      id: _requiredString(json, 'id'),
      type: _nodeTypeFromName(_requiredString(json, 'type')),
      label: _requiredString(json, 'label'),
      next: _optionalStringList(json, 'next'),
      parameters: _optionalObjectMap(json, 'parameters'),
      visual: _optionalVisual(json, 'visual'),
    );
  }

  // 复制节点，支持显式清空 visual。
  WorkflowNode copyWith({
    String? id,
    WorkflowNodeType? type,
    String? label,
    List<String>? next,
    Map<String, Object?>? parameters,
    Object? visual = _unsetVisual,
  }) {
    return WorkflowNode(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      next: next ?? this.next,
      parameters: parameters ?? this.parameters,
      visual: identical(visual, _unsetVisual)
          ? this.visual
          : visual as WorkflowNodeVisual?,
    );
  }
}

const Object _unsetVisual = Object();

// WorkflowDefinition 是 Project DSL 的工作流真源。
// Visual View、Source View 和 Runtime 都必须映射到这个模型。
final class WorkflowDefinition {
  // 创建工作流定义。
  const WorkflowDefinition({
    required this.id,
    required this.name,
    required this.entryNodesId,
    required this.nodes,
  });

  final String id;
  final String name;
  final String entryNodesId;
  final List<WorkflowNode> nodes;

  // 序列化为 Project DSL JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'entryNodesId': entryNodesId,
      'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    };
  }

  // 从 Project DSL JSON 恢复工作流定义。
  static WorkflowDefinition fromJson(Map<String, Object?> json) {
    final rawNodes = json['nodes'];
    if (rawNodes is! List<Object?>) {
      throw const FormatException('Workflow nodes must be a list.');
    }
    return WorkflowDefinition(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
      entryNodesId: _requiredString(json, 'entryNodesId'),
      nodes: rawNodes
          .map((rawNodes) {
            if (rawNodes is! Map<String, Object?>) {
              throw const FormatException('Workflow node must be an object.');
            }
            return WorkflowNode.fromJson(rawNodes);
          })
          .toList(growable: false),
    );
  }

  // 创建工作流定义副本，用于受控改名、换 ID 或替换节点。
  // 不改变 DSL 结构语义，调用方仍需通过 validator 校验。
  WorkflowDefinition copyWith({
    String? id,
    String? name,
    String? entryNodesId,
    List<WorkflowNode>? nodes,
  }) {
    return WorkflowDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      entryNodesId: entryNodesId ?? this.entryNodesId,
      nodes: nodes ?? this.nodes,
    );
  }

  // 创建内置 A-F 基础模板。
  static WorkflowDefinition afTemplate() => _afTemplate();

  // 从旧 sequence 配置导入线性 Project DSL。
  static WorkflowDefinition fromLegacySequence({
    required String id,
    required String name,
    required List<Object?> sequence,
  }) {
    return _fromLegacySequence(id: id, name: name, sequence: sequence);
  }
}
