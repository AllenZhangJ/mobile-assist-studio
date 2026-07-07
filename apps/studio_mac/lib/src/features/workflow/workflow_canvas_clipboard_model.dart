part of '../../studio_mac_workspace.dart';

// 画布节点剪贴板模型，统一描述页面内和系统剪贴板的节点快照。
// 该模型只保存工作流节点数据，不保存设备、会话、路径或运行证据。
final class _WorkflowCanvasClipboard {
  _WorkflowCanvasClipboard(List<WorkflowNode> nodes)
    : nodes = List<WorkflowNode>.unmodifiable(nodes),
      sourceNodeIds = List<String>.unmodifiable(nodes.map((node) => node.id));

  // 从当前 workflow 中按选中 id 提取可粘贴节点快照。
  factory _WorkflowCanvasClipboard.fromWorkflow(
    WorkflowDefinition workflow,
    Set<String> nodeIds,
  ) {
    return _WorkflowCanvasClipboard(
      workflow.nodes
          .where((node) => nodeIds.contains(node.id))
          .toList(growable: false),
    );
  }

  final List<WorkflowNode> nodes;
  final List<String> sourceNodeIds;

  // 判断当前剪贴板是否没有可粘贴节点。
  bool get isEmpty => nodes.isEmpty;

  // 序列化为系统剪贴板文本，使用项目私有格式避免误读普通文本。
  String toClipboardText() {
    return jsonEncode(<String, Object?>{
      'kind': _workflowCanvasClipboardKind,
      'version': 1,
      'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
    });
  }

  // 从系统剪贴板文本恢复节点快照；非本项目格式会被静默忽略。
  static _WorkflowCanvasClipboard? tryParse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) return null;
      if (decoded['kind'] != _workflowCanvasClipboardKind) return null;
      if (decoded['version'] != 1) return null;
      final rawNodes = decoded['nodes'];
      if (rawNodes is! List<Object?>) return null;
      final nodes = rawNodes
          .map((rawNode) {
            if (rawNode is! Map<String, Object?>) {
              throw const FormatException('Clipboard node must be an object.');
            }
            return WorkflowNode.fromJson(rawNode);
          })
          .where((node) => node.type != WorkflowNodeType.start)
          .where((node) => node.type != WorkflowNodeType.end)
          .toList(growable: false);
      if (nodes.isEmpty) return null;
      return _WorkflowCanvasClipboard(nodes);
    } on FormatException {
      return null;
    } on Object {
      return null;
    }
  }
}

const _workflowCanvasClipboardKind =
    'ios-assist-studio.workflow-canvas-clipboard';
