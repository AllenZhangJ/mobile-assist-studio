part of '../studio_runtime.dart';

// MobilePlatform 表示当前移动设备平台。
// 平台只表达设备类别，不绑定具体驱动实现。
enum MobilePlatform { unknown, ios, android }

// MobileConnectionKind 表示本机和手机的连接方式。
// UI 只能展示脱敏连接摘要，不展示完整设备标识。
enum MobileConnectionKind { unknown, usb, localNetwork, simulator, emulator }

// MobileResourceState 描述当前设备资源被谁占用。
// 它是跨 Device、Recorder、Execute 和 Inspector 的互斥基础。
enum MobileResourceState {
  idle,
  remoteControl,
  recording,
  running,
  paused,
  stopping,
  diagnosing,
  error,
}

// MobileDriverCapabilityReport 描述当前平台 driver 能力。
// UI 和运行前检查用它提前判断功能是否可用。
final class MobileDriverCapabilityReport {
  // 创建平台 driver 能力报告。
  const MobileDriverCapabilityReport({
    required this.platform,
    required this.screenshot,
    required this.tap,
    required this.swipe,
    required this.input,
    required this.pageSource,
    required this.selectorTarget,
    required this.imageTarget,
    required this.ocrTarget,
    required this.appLifecycle,
    required this.logs,
    required this.performance,
    required this.remotePreview,
  });

  final MobilePlatform platform;
  final bool screenshot;
  final bool tap;
  final bool swipe;
  final bool input;
  final bool pageSource;
  final bool selectorTarget;
  final bool imageTarget;
  final bool ocrTarget;
  final bool appLifecycle;
  final bool logs;
  final bool performance;
  final bool remotePreview;

  // 判断最小动作闭环是否可运行。
  bool get supportsCoreActions => screenshot && tap && swipe && input;

  // 复制能力报告，用于 adapter 渐进补齐平台能力。
  MobileDriverCapabilityReport copyWith({
    MobilePlatform? platform,
    bool? screenshot,
    bool? tap,
    bool? swipe,
    bool? input,
    bool? pageSource,
    bool? selectorTarget,
    bool? imageTarget,
    bool? ocrTarget,
    bool? appLifecycle,
    bool? logs,
    bool? performance,
    bool? remotePreview,
  }) {
    return MobileDriverCapabilityReport(
      platform: platform ?? this.platform,
      screenshot: screenshot ?? this.screenshot,
      tap: tap ?? this.tap,
      swipe: swipe ?? this.swipe,
      input: input ?? this.input,
      pageSource: pageSource ?? this.pageSource,
      selectorTarget: selectorTarget ?? this.selectorTarget,
      imageTarget: imageTarget ?? this.imageTarget,
      ocrTarget: ocrTarget ?? this.ocrTarget,
      appLifecycle: appLifecycle ?? this.appLifecycle,
      logs: logs ?? this.logs,
      performance: performance ?? this.performance,
      remotePreview: remotePreview ?? this.remotePreview,
    );
  }

  static const none = MobileDriverCapabilityReport(
    platform: MobilePlatform.unknown,
    screenshot: false,
    tap: false,
    swipe: false,
    input: false,
    pageSource: false,
    selectorTarget: false,
    imageTarget: false,
    ocrTarget: false,
    appLifecycle: false,
    logs: false,
    performance: false,
    remotePreview: false,
  );
}

// MobileDeviceSummary 是当前设备的脱敏摘要。
// 它不保存完整 UDID、ADB serial、session 或 endpoint。
final class MobileDeviceSummary {
  // 创建移动设备摘要。
  const MobileDeviceSummary({
    required this.platform,
    required this.displayName,
    required this.maskedIdentifier,
    required this.osVersion,
    required this.connectionKind,
    this.batteryLevel,
    this.currentApp,
    this.screenSize,
  });

  final MobilePlatform platform;
  final String displayName;
  final String maskedIdentifier;
  final String? osVersion;
  final MobileConnectionKind connectionKind;
  final int? batteryLevel;
  final String? currentApp;
  final ViewportSize? screenSize;
}

// MobileRuntimeSummary 汇总当前移动运行时状态。
// Flutter UI 通过它读取平台、资源锁和能力，不直接理解 adapter。
final class MobileRuntimeSummary {
  // 创建移动运行时摘要。
  const MobileRuntimeSummary({
    required this.platform,
    required this.resourceState,
    required this.capabilities,
    this.device,
  });

  final MobilePlatform platform;
  final MobileResourceState resourceState;
  final MobileDriverCapabilityReport capabilities;
  final MobileDeviceSummary? device;

  // 复制移动运行时摘要，支持设备字段显式置空。
  MobileRuntimeSummary copyWith({
    MobilePlatform? platform,
    MobileResourceState? resourceState,
    MobileDriverCapabilityReport? capabilities,
    Object? device = _unset,
  }) {
    return MobileRuntimeSummary(
      platform: platform ?? this.platform,
      resourceState: resourceState ?? this.resourceState,
      capabilities: capabilities ?? this.capabilities,
      device: identical(device, _unset)
          ? this.device
          : device as MobileDeviceSummary?,
    );
  }

  static const initial = MobileRuntimeSummary(
    platform: MobilePlatform.unknown,
    resourceState: MobileResourceState.idle,
    capabilities: MobileDriverCapabilityReport.none,
    device: null,
  );
}
