part of '../studio_runtime.dart';

// InspectorElementSummary 是元素树中的脱敏元素摘要。
// 它避免把完整 source XML 或底层 payload 直接铺到主界面。
final class InspectorElementSummary {
  // 创建元素摘要。
  const InspectorElementSummary({
    required this.id,
    required this.type,
    this.label,
    this.value,
    this.bounds,
    this.attributes = const <String, String>{},
    this.children = const <InspectorElementSummary>[],
  });

  final String id;
  final String type;
  final String? label;
  final String? value;
  final RuntimeRegion? bounds;
  final Map<String, String> attributes;
  final List<InspectorElementSummary> children;

  // 返回当前元素及子元素总数。
  int get totalCount =>
      1 + children.fold<int>(0, (total, child) => total + child.totalCount);
}

// InspectorSnapshot 是当前界面检查快照。
// 它把截图、元素树和平台能力放在同一个只读模型中。
final class InspectorSnapshot {
  // 创建检查快照。
  const InspectorSnapshot({
    required this.platform,
    required this.capturedAt,
    required this.capabilities,
    required this.elementCount,
    this.screenshotBase64,
    this.rootElement,
    this.sourceSummary,
    this.sourcePreview,
    this.selectedElementId,
  });

  final MobilePlatform platform;
  final DateTime capturedAt;
  final MobileDriverCapabilityReport capabilities;
  final int elementCount;
  final String? screenshotBase64;
  final InspectorElementSummary? rootElement;
  final String? sourceSummary;
  final String? sourcePreview;
  final String? selectedElementId;

  // 判断当前快照是否具备可检查元素树。
  bool get hasElementTree => rootElement != null;

  // 返回当前快照是否具备截图。
  bool get hasScreenshot => screenshotBase64 != null;
}
