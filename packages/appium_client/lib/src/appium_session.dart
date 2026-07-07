part of '../appium_client.dart';

// WebDriverSession 表示已建立的 WebDriver 会话。
// Runtime 只保存 session id 和脱敏 capabilities 摘要。
final class WebDriverSession {
  // 创建 WebDriver 会话模型。
  const WebDriverSession({required this.id, required this.capabilities});

  final String id;
  final Map<String, Object?> capabilities;

  // 从 W3C 或旧式 session 响应解析会话。
  factory WebDriverSession.fromJson(Map<String, Object?> json) {
    final value = json['value'];
    if (value is Map<String, Object?>) {
      final sessionId = value['sessionId'] ?? json['sessionId'];
      final capabilities = value['capabilities'];
      if (sessionId is String) {
        return WebDriverSession(
          id: sessionId,
          capabilities: capabilities is Map<String, Object?>
              ? capabilities
              : const <String, Object?>{},
        );
      }
    }

    final sessionId = json['sessionId'];
    final capabilities = json['capabilities'];
    if (sessionId is String) {
      return WebDriverSession(
        id: sessionId,
        capabilities: capabilities is Map<String, Object?>
            ? capabilities
            : const <String, Object?>{},
      );
    }

    throw const AppiumClientException(
      'Session response did not include a session id.',
    );
  }
}

// AppiumSessionRequest 表示创建会话的 capabilities 请求。
// 它只封装 alwaysMatch，避免 Runtime 拼错 W3C 结构。
final class AppiumSessionRequest {
  // 创建会话请求。
  const AppiumSessionRequest({required this.capabilities});

  final Map<String, Object?> capabilities;

  // 转成 WebDriver W3C create session payload。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'capabilities': <String, Object?>{'alwaysMatch': capabilities},
    };
  }
}
