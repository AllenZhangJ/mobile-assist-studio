part of '../studio_runtime.dart';

// Appium 可用性探测分片，负责读取 /status 并转换成 Runtime 摘要。
final class AppiumAvailabilityProbe implements AppiumAvailabilityChecker {
  // 创建 Appium 可用性探测器。
  AppiumAvailabilityProbe(
    this._client, {
    this.statusTimeout = const Duration(seconds: 3),
  });

  final AppiumClient _client;
  final Duration statusTimeout;

  @override
  // 检查 Appium status，失败时只返回脱敏错误消息。
  Future<AppiumAvailability> check() async {
    try {
      final status = await _client.status().timeout(statusTimeout);
      return AppiumAvailability(
        available: status.ready,
        message: status.message,
      );
    } on TimeoutException {
      return const AppiumAvailability(
        available: false,
        message: 'Timed out while checking driver status.',
      );
    } on AppiumClientException catch (error) {
      return AppiumAvailability(available: false, message: error.message);
    }
  }
}
