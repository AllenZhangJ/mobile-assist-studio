part of '../../studio_mac_workspace.dart';

// 单条录制动作，保留生成 workflow 需要的最小参数。
// 展示摘要、证据摘要和状态色已拆到相邻分片。
final class _RecordedActions {
  const _RecordedActions({
    required this.id,
    required this.type,
    required this.label,
    required this.target,
    required this.waitAfterMs,
    required this.durationMs,
    required this.x,
    required this.y,
    required this.toX,
    required this.toY,
    required this.text,
    required this.targetRef,
    required this.elementSummary,
    required this.retryPolicy,
    required this.evidence,
  });

  // 创建点击动作，坐标只进入详情和 DSL 参数。
  factory _RecordedActions.tap({
    required String id,
    required String label,
    required String target,
    required int x,
    required int y,
    required int waitAfterMs,
    required _RecordedEvidenceBinding evidence,
  }) {
    return _RecordedActions(
      id: id,
      type: _RecordedActionsType.tap,
      label: label,
      target: target,
      waitAfterMs: waitAfterMs,
      durationMs: 80,
      x: x,
      y: y,
      toX: null,
      toY: null,
      text: null,
      targetRef: null,
      elementSummary: '可见元素',
      retryPolicy: '录制版暂无重试',
      evidence: evidence,
    );
  }

  // 创建等待动作，作为录制中的显式延迟节点。
  factory _RecordedActions.wait({
    required String id,
    required String label,
    required int waitMs,
    required _RecordedEvidenceBinding evidence,
  }) {
    return _RecordedActions(
      id: id,
      type: _RecordedActionsType.wait,
      label: label,
      target: '时间等待',
      waitAfterMs: waitMs,
      durationMs: waitMs,
      x: null,
      y: null,
      toX: null,
      toY: null,
      text: null,
      targetRef: null,
      elementSummary: '不适用',
      retryPolicy: '不适用',
      evidence: evidence,
    );
  }

  // 创建滑动动作，优先保存真实拖动轨迹，缺省时回退安全上滑。
  factory _RecordedActions.swipe({
    required String id,
    required String label,
    required String target,
    required int durationMs,
    int? fromX,
    int? fromY,
    int? toX,
    int? toY,
    required _RecordedEvidenceBinding evidence,
  }) {
    return _RecordedActions(
      id: id,
      type: _RecordedActionsType.swipe,
      label: label,
      target: target,
      waitAfterMs: 50,
      durationMs: durationMs,
      x: fromX,
      y: fromY,
      toX: toX,
      toY: toY,
      text: null,
      targetRef: null,
      elementSummary: '在屏幕上操作',
      retryPolicy: '录制版暂无重试',
      evidence: evidence,
    );
  }

  // 创建输入动作，文本只进入详情和 DSL 参数，不在时间线明文展示。
  factory _RecordedActions.input({
    required String id,
    required String label,
    required String target,
    required String text,
    required int waitAfterMs,
    required _RecordedEvidenceBinding evidence,
  }) {
    return _RecordedActions(
      id: id,
      type: _RecordedActionsType.input,
      label: label,
      target: target,
      waitAfterMs: waitAfterMs,
      durationMs: 0,
      x: null,
      y: null,
      toX: null,
      toY: null,
      text: text,
      targetRef: null,
      elementSummary: '当前焦点',
      retryPolicy: '录制版暂无重试',
      evidence: evidence,
    );
  }

  final String id;
  final _RecordedActionsType type;
  final String label;
  final String target;
  final int waitAfterMs;
  final int durationMs;
  final int? x;
  final int? y;
  final int? toX;
  final int? toY;
  final String? text;
  final String? targetRef;
  final String elementSummary;
  final String retryPolicy;
  final _RecordedEvidenceBinding evidence;

  // 生成局部更新后的动作，保留未编辑字段和证据绑定。
  _RecordedActions copyWith({
    String? id,
    String? label,
    String? target,
    int? waitAfterMs,
    int? durationMs,
    int? x,
    int? y,
    int? toX,
    int? toY,
    String? text,
    String? targetRef,
  }) {
    return _RecordedActions(
      id: id ?? this.id,
      type: type,
      label: label ?? this.label,
      target: target ?? this.target,
      waitAfterMs: waitAfterMs ?? this.waitAfterMs,
      durationMs: durationMs ?? this.durationMs,
      x: x ?? this.x,
      y: y ?? this.y,
      toX: toX ?? this.toX,
      toY: toY ?? this.toY,
      text: text ?? this.text,
      targetRef: targetRef ?? this.targetRef,
      elementSummary: elementSummary,
      retryPolicy: retryPolicy,
      evidence: evidence,
    );
  }
}
