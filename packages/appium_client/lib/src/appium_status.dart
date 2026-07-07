part of '../appium_client.dart';

// AppiumStatus 表示 /status 接口的摘要。
// 原始响应只作为调试数据保留，不由 UI 直接展示。
final class AppiumStatus {
  // 创建 Appium 状态摘要。
  const AppiumStatus({
    required this.ready,
    required this.message,
    required this.raw,
  });

  final bool ready;
  final String message;
  final Map<String, Object?> raw;

  // 从 Appium 2 或兼容响应格式解析状态。
  factory AppiumStatus.fromJson(Map<String, Object?> json) {
    final value = json['value'];
    if (value is Map<String, Object?>) {
      return AppiumStatus(
        ready: value['ready'] == true,
        message: value['message']?.toString() ?? 'Appium status received.',
        raw: json,
      );
    }
    return AppiumStatus(
      ready: json['ready'] == true,
      message: json['message']?.toString() ?? 'Appium status received.',
      raw: json,
    );
  }
}
