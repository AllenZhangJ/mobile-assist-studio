part of '../appium_client.dart';

// AppiumHttpTransport 封装最小 JSON HTTP 通信。
// 它只处理请求、超时、状态码和 JSON 解析，不理解业务动作。
final class AppiumHttpTransport {
  // 创建 HTTP 传输层，可注入 HttpClient 方便测试。
  AppiumHttpTransport({
    required AppiumServerConfig config,
    HttpClient? httpClient,
  }) : _config = config,
       _httpClient = httpClient ?? HttpClient();

  final AppiumServerConfig _config;
  final HttpClient _httpClient;

  // 发送 GET 请求并解析 JSON 对象。
  Future<Map<String, Object?>> getJson(String path) async {
    return sendJson(method: 'GET', path: path);
  }

  // 发送 JSON 请求并返回 JSON 对象响应。
  Future<Map<String, Object?>> sendJson({
    required String method,
    required String path,
    Map<String, Object?>? payload,
  }) async {
    final uri = _config.resolve(path);
    try {
      final request = await _httpClient
          .openUrl(method, uri)
          .timeout(_config.timeout);
      if (payload != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(payload));
      }
      final response = await request.close().timeout(_config.timeout);
      final body = await utf8.decodeStream(response).timeout(_config.timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppiumClientException(
          _httpFailureMessage(response.statusCode, uri.path, body),
        );
      }
      if (body.trim().isEmpty) return const <String, Object?>{};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) return decoded;
      throw const AppiumClientException('Appium response was not an object.');
    } on TimeoutException {
      throw AppiumClientException('Timed out while requesting ${uri.path}.');
    } on SocketException catch (error) {
      throw AppiumClientException('Unable to reach Appium: ${error.message}.');
    } on FormatException catch (error) {
      throw AppiumClientException('Invalid Appium JSON: ${error.message}.');
    }
  }

  // 关闭底层 HttpClient，测试和 App 退出时调用。
  void close({bool force = false}) {
    _httpClient.close(force: force);
  }
}

// 生成 HTTP 失败文案，优先保留 WebDriver value.message。
// 上层 Runtime 会再做中文分类和隐私脱敏。
String _httpFailureMessage(int statusCode, String path, String body) {
  final detail = _webdriverErrorDetail(body);
  final base = 'Appium returned HTTP $statusCode for $path.';
  if (detail == null || detail.isEmpty) return base;
  return '$base $detail';
}

// 从 Appium / WebDriver 错误响应中提取可读 message。
String? _webdriverErrorDetail(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, Object?>) {
      final value = decoded['value'];
      if (value is Map<String, Object?>) {
        final message = value['message'];
        if (message is String) return _clampWebDriverDetail(message);
      }
      final message = decoded['message'];
      if (message is String) return _clampWebDriverDetail(message);
      if (value is String) return _clampWebDriverDetail(value);
    }
  } on FormatException {
    return _clampWebDriverDetail(trimmed);
  }
  return null;
}

// 裁剪 Appium 错误详情，避免异常对象无限膨胀。
String _clampWebDriverDetail(String detail) {
  final oneLine = detail.replaceAll(RegExp(r'\s+'), ' ').trim();
  const maxLength = 600;
  if (oneLine.length <= maxLength) return oneLine;
  return '${oneLine.substring(0, maxLength - 1)}...';
}
