part of '../appium_client.dart';

// AppiumServerConfig 描述本机 Appium 服务入口。
// Runtime 通过它统一解析 /status、/session 等 HTTP 路径。
final class AppiumServerConfig {
  // 创建 Appium 服务配置，默认指向本机 4723。
  const AppiumServerConfig({
    this.host = '127.0.0.1',
    this.port = 4723,
    this.basePath = '/',
    this.timeout = const Duration(seconds: 2),
  });

  final String host;
  final int port;
  final String basePath;
  final Duration timeout;

  // 根据 basePath 和相对路径生成 HTTP URI。
  Uri resolve(String path) {
    final normalizedBase = basePath.endsWith('/') ? basePath : '$basePath/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: '$normalizedBase$normalizedPath'.replaceAll(RegExp('/+'), '/'),
    );
  }
}
