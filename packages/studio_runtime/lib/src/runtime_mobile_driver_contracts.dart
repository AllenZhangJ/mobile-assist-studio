part of '../studio_runtime.dart';

// MobileDriverSession 是跨平台 driver 会话摘要。
// 它只保存脱敏会话信息，供 Runtime 状态机继续编排。
final class MobileDriverSession {
  // 创建移动 driver 会话摘要。
  const MobileDriverSession({
    required this.sessionId,
    required this.platform,
    required this.capabilities,
    this.device,
  });

  final String sessionId;
  final MobilePlatform platform;
  final MobileDriverCapabilityReport capabilities;
  final MobileDeviceSummary? device;
}

// MobileDriverHeartbeat 是 driver 心跳结果。
// Runtime 用它区分驱动在线、设备离线和能力退化。
final class MobileDriverHeartbeat {
  // 创建 driver 心跳结果。
  const MobileDriverHeartbeat({
    required this.ready,
    required this.message,
    this.capabilities,
  });

  final bool ready;
  final String message;
  final MobileDriverCapabilityReport? capabilities;
}

// MobileScreenshot 是跨平台截图结果。
// 截图内容只在内存或 Evidence 中受控流转。
final class MobileScreenshot {
  // 创建移动截图结果。
  const MobileScreenshot({
    required this.base64Png,
    required this.capturedAt,
    this.viewport,
  });

  final String base64Png;
  final DateTime capturedAt;
  final ViewportSize? viewport;
}

// MobileDeviceDriver 是 V4 Runtime 的平台中立驱动接口。
// 所有设备动作都必须先经过 Runtime 资源锁和前置校验。
abstract interface class MobileDeviceDriver {
  // 当前 adapter 支持的平台。
  MobilePlatform get platform;

  // 返回当前 adapter 的能力报告。
  Future<MobileDriverCapabilityReport> capabilityReport();

  // 发现当前唯一设备，返回脱敏摘要。
  Future<MobileDeviceSummary?> discoverCurrentDevice();

  // 建立 driver 会话，失败时抛出结构化异常的上层包装。
  Future<MobileDriverSession> connect();

  // 断开当前 driver 会话。
  Future<void> disconnect();

  // 检查 driver 和设备是否仍可用。
  Future<MobileDriverHeartbeat> heartbeat();

  // 捕获当前屏幕截图。
  Future<MobileScreenshot> captureScreenshot();

  // 获取当前页面源码；不支持的平台返回 null。
  Future<String?> getPageSource();

  // 在 viewport 坐标执行点按。
  Future<void> tap(ViewportPoint point, {Duration? duration});

  // 在 viewport 坐标执行滑动。
  Future<void> swipe(
    ViewportPoint from,
    ViewportPoint to, {
    Duration? duration,
  });

  // 向当前焦点输入文本。
  Future<void> inputText(String text);

  // 启动指定 App；参数语义由平台 adapter 解释。
  Future<void> launchApp(String appId);

  // 停止指定 App；参数语义由平台 adapter 解释。
  Future<void> stopApp(String appId);

  // 触发平台主页动作。
  Future<void> pressHome();

  // 收集短日志摘要。
  Future<List<String>> collectLogs();

  // 尽力释放平台动作状态，避免失败后指针悬挂。
  Future<void> releaseActions();
}
