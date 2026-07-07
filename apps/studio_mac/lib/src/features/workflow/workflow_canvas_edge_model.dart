part of '../../studio_mac_workspace.dart';

// 画布连线类型，区分普通后续边和 Catch 错误边。
enum _WorkflowSelectedEdgeKind { next, onError }

// 画布选中连线模型，记录连线类型、两端节点和浮层锚点。
final class _WorkflowSelectedEdge {
  const _WorkflowSelectedEdge({
    required this.fromNodeId,
    required this.toNodeId,
    required this.anchor,
    this.kind = _WorkflowSelectedEdgeKind.next,
  });

  final String fromNodeId;
  final String toNodeId;
  final Offset anchor;
  final _WorkflowSelectedEdgeKind kind;
}
