part of '../appium_client.dart';

// AppiumClientException 是 Appium Client 的统一错误类型。
// 上层 Runtime 只需要捕获这一类错误并映射为用户可懂状态。
final class AppiumClientException implements Exception {
  // 创建 Appium Client 错误。
  const AppiumClientException(this.message);

  final String message;

  // 输出简短错误描述，便于测试和日志阅读。
  @override
  String toString() => 'AppiumClientException: $message';
}
