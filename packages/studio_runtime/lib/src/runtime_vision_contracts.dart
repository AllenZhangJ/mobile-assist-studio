part of '../studio_runtime.dart';

// RuntimeTargetKind 表示 V4 Target Library 的目标类型。
// 目标类型表达用户意图，不绑定 iOS 或 Android 细节。
enum RuntimeTargetKind { coordinate, selector, image, region, text }

// TargetResolutionStatus 表示目标解析结果状态。
// 低置信和找不到目标必须被区分，避免盲目点击。
enum TargetResolutionStatus {
  matched,
  notMatched,
  lowConfidence,
  unsupported,
  infrastructureError,
}

// RuntimeTargetDefinition 是 Runtime 层的最小目标定义。
// 具体字段后续由 Target Library 扩展，不写入设备私密信息。
final class RuntimeTargetDefinition {
  // 创建目标定义。
  const RuntimeTargetDefinition({
    required this.id,
    required this.kind,
    required this.label,
    this.payload = const <String, Object?>{},
  });

  final String id;
  final RuntimeTargetKind kind;
  final String label;
  final Map<String, Object?> payload;

  // 创建坐标目标，用于 Recorder 和旧坐标流程逐步迁移到 targetRef。
  factory RuntimeTargetDefinition.coordinate({
    required String id,
    required String label,
    required int x,
    required int y,
    int? viewportWidth,
    int? viewportHeight,
  }) {
    return RuntimeTargetDefinition(
      id: id,
      kind: RuntimeTargetKind.coordinate,
      label: label,
      payload: <String, Object?>{
        'x': x,
        'y': y,
        'viewportWidth': ?viewportWidth,
        'viewportHeight': ?viewportHeight,
      },
    );
  }

  // 序列化为项目目标库 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'kind': kind.name,
      'label': label,
      if (payload.isNotEmpty) 'payload': payload,
    };
  }

  // 从项目目标库 JSON 恢复目标定义。
  static RuntimeTargetDefinition fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final kind = json['kind'];
    final label = json['label'];
    final payload = json['payload'];
    if (id is! String || kind is! String || label is! String) {
      throw const FormatException('Target id, kind and label are required.');
    }
    return RuntimeTargetDefinition(
      id: id,
      kind: _runtimeTargetKindFromName(kind),
      label: label,
      payload: payload is Map<String, Object?>
          ? Map<String, Object?>.unmodifiable(payload)
          : const <String, Object?>{},
    );
  }
}

// 将 JSON 中的目标类型恢复为 Runtime enum。
RuntimeTargetKind _runtimeTargetKindFromName(String name) {
  for (final kind in RuntimeTargetKind.values) {
    if (kind.name == name) return kind;
  }
  throw FormatException('Unknown target kind: $name.');
}

// TargetResolutionRequest 描述一次目标解析请求。
// Provider 只能读取截图和目标定义，不能直接操作设备。
final class TargetResolutionRequest {
  // 创建目标解析请求。
  const TargetResolutionRequest({
    required this.target,
    required this.platform,
    required this.capabilities,
    required this.screenshotBase64,
    required this.confidenceThreshold,
    this.sourceXml,
  });

  final RuntimeTargetDefinition target;
  final MobilePlatform platform;
  final MobileDriverCapabilityReport capabilities;
  final String screenshotBase64;
  final double confidenceThreshold;
  final String? sourceXml;
}

// TargetResolutionResult 描述目标解析结果和证据。
// Runtime 只有在 matched 且置信度达标时才可继续动作节点。
final class TargetResolutionResult {
  // 创建目标解析结果。
  const TargetResolutionResult({
    required this.status,
    required this.message,
    this.point,
    this.region,
    this.confidence,
    this.evidenceRef,
  });

  final TargetResolutionStatus status;
  final String message;
  final ViewportPoint? point;
  final RuntimeRegion? region;
  final double? confidence;
  final String? evidenceRef;

  // 判断解析结果是否允许后续执行点击。
  bool get canContinue => status == TargetResolutionStatus.matched;

  // 创建匹配成功结果。
  factory TargetResolutionResult.matched({
    required ViewportPoint point,
    RuntimeRegion? region,
    required double confidence,
    String? evidenceRef,
  }) {
    return TargetResolutionResult(
      status: TargetResolutionStatus.matched,
      message: '已找到目标。',
      point: point,
      region: region,
      confidence: confidence,
      evidenceRef: evidenceRef,
    );
  }

  // 创建低置信结果，Runtime 默认进入暂停或阻断。
  factory TargetResolutionResult.lowConfidence({
    required double confidence,
    String? evidenceRef,
  }) {
    return TargetResolutionResult(
      status: TargetResolutionStatus.lowConfidence,
      message: '目标置信度不足。',
      confidence: confidence,
      evidenceRef: evidenceRef,
    );
  }

  // 创建未找到结果。
  factory TargetResolutionResult.notMatched({String? evidenceRef}) {
    return TargetResolutionResult(
      status: TargetResolutionStatus.notMatched,
      message: '未找到目标。',
      evidenceRef: evidenceRef,
    );
  }

  // 创建能力不支持结果。
  factory TargetResolutionResult.unsupported(String message) {
    return TargetResolutionResult(
      status: TargetResolutionStatus.unsupported,
      message: message,
    );
  }

  // 创建基础设施错误结果。
  factory TargetResolutionResult.infrastructureError(String message) {
    return TargetResolutionResult(
      status: TargetResolutionStatus.infrastructureError,
      message: message,
    );
  }
}

// RuntimeRegion 表示截图中的矩形区域。
// 区域只使用 viewport 坐标，不包含截图文件路径。
final class RuntimeRegion {
  // 创建矩形区域。
  const RuntimeRegion({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

// TargetResolver 是目标解析入口。
// 它只返回解析结果，不允许执行设备动作。
abstract interface class TargetResolver {
  // 解析一个目标并返回可诊断结果。
  Future<TargetResolutionResult> resolve(TargetResolutionRequest request);
}

// VisionProvider 是图像、OCR 或模板识别后端。
// Provider 必须通过 TargetResolver 被 Runtime 统一调度。
abstract interface class VisionProvider {
  // Provider 的稳定标识。
  String get id;

  // 判断当前 provider 是否支持某类目标。
  bool supports(RuntimeTargetKind kind);

  // 执行目标解析。
  Future<TargetResolutionResult> resolve(TargetResolutionRequest request);
}
