part of '../../studio_mac_workspace.dart';

// 录制动作摘要派生，集中处理短中文文案和隐私展示边界。
extension _RecordedActionSummary on _RecordedActions {
  // 证据摘要只展示状态和时间，不直接展示截图内容。
  String get evidenceSummary {
    final capturedAt = evidence.capturedAt;
    if (evidence.imageBase64 == null || capturedAt == null) return '无预览';
    return '预览 ${_timeOnly(capturedAt)}';
  }

  // 时间线摘要默认隐藏坐标，保持录制页简单可读。
  String get timelineSummary {
    return switch (type) {
      _RecordedActionsType.tap => '$target，等 ${waitAfterMs}ms',
      _RecordedActionsType.wait => '延迟 ${waitAfterMs}ms',
      _RecordedActionsType.swipe =>
        '$target，$swipeDirectionLabel ${durationMs}ms',
      _RecordedActionsType.input => '$target，等 ${waitAfterMs}ms',
    };
  }

  // 详情摘要使用动作类型和时间线文案，不暴露内部动作 ID。
  String get detailSummary => '${type.label} · $timelineSummary';

  // 判断滑动动作是否带有真实起点和终点。
  bool get hasSwipePath => x != null && y != null && toX != null && toY != null;

  // 根据起终点生成短方向文案，避免主时间线展示裸坐标。
  String get swipeDirectionLabel {
    if (!hasSwipePath) return '上滑';
    final dx = toX! - x!;
    final dy = toY! - y!;
    if (dx.abs() > dy.abs()) return dx > 0 ? '右滑' : '左滑';
    return dy > 0 ? '下滑' : '上滑';
  }
}
