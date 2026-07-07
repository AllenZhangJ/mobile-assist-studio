part of '../../studio_mac_workspace.dart';

// 录制证据绑定，当前只在内存中保存预览截图和时间。
final class _RecordedEvidenceBinding {
  // 创建证据绑定；截图内容不会写入 Project DSL。
  const _RecordedEvidenceBinding({
    required this.imageBase64,
    required this.capturedAt,
  });

  final String? imageBase64;
  final DateTime? capturedAt;

  // 判断当前动作是否绑定了可展示的截图。
  bool get hasImage => imageBase64 != null && capturedAt != null;
}
