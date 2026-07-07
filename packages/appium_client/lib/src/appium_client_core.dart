part of '../appium_client.dart';

// AppiumClient 是 Runtime 使用的最小 WebDriver / Appium HTTP client。
// 它不是通用 Appium SDK，只暴露 V2.0 当前需要的能力。
final class AppiumClient {
  // 创建 Appium Client，可注入 HttpClient 以便本地测试。
  AppiumClient({
    AppiumServerConfig config = const AppiumServerConfig(),
    HttpClient? httpClient,
  }) : _transport = AppiumHttpTransport(config: config, httpClient: httpClient);

  final AppiumHttpTransport _transport;

  // 读取 Appium /status，用于判断驱动服务是否 ready。
  Future<AppiumStatus> status() async {
    final payload = await _transport.getJson('/status');
    return AppiumStatus.fromJson(payload);
  }

  // 创建 WebDriver session。
  Future<WebDriverSession> createSession(
    AppiumSessionRequest sessionRequest,
  ) async {
    final payload = await _transport.sendJson(
      method: 'POST',
      path: '/session',
      payload: sessionRequest.toJson(),
    );
    return WebDriverSession.fromJson(payload);
  }

  // 删除 WebDriver session。
  Future<void> deleteSession(String sessionId) async {
    await _transport.sendJson(method: 'DELETE', path: '/session/$sessionId');
  }

  // 读取当前屏幕截图的 base64 字符串。
  Future<String> screenshot(String sessionId) async {
    final payload = await _transport.getJson('/session/$sessionId/screenshot');
    final value = payload['value'];
    if (value is String) return value;
    throw const AppiumClientException(
      'Screenshot response did not include a base64 value.',
    );
  }

  // 读取当前 viewport 尺寸，用于坐标换算。
  Future<ViewportSize> viewportSize(String sessionId) async {
    final payload = await _transport.getJson('/session/$sessionId/window/rect');
    return ViewportSize.fromJson(payload);
  }

  // 读取当前会话的页面结构，用于上层做脱敏后的状态判断。
  Future<String> pageSource(String sessionId) async {
    final payload = await _transport.getJson('/session/$sessionId/source');
    final value = payload['value'];
    if (value is String) return value;
    throw const AppiumClientException(
      'Source response did not include a string value.',
    );
  }

  // 发送 viewport tap 动作。
  Future<void> tap(
    String sessionId, {
    required ViewportPoint point,
    int durationMs = 80,
  }) async {
    if (durationMs < 0) {
      throw const AppiumClientException(
        'Tap duration must be zero or greater.',
      );
    }
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/actions',
      payload: AppiumActionPayloads.tap(point: point, durationMs: durationMs),
    );
  }

  // 发送 viewport swipe 动作。
  Future<void> swipe(
    String sessionId, {
    required ViewportPoint from,
    required ViewportPoint to,
    int durationMs = 450,
  }) async {
    if (durationMs < 0) {
      throw const AppiumClientException(
        'Swipe duration must be zero or greater.',
      );
    }
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/actions',
      payload: AppiumActionPayloads.swipe(
        from: from,
        to: to,
        durationMs: durationMs,
      ),
    );
  }

  // 发送 viewport 双指缩放动作。
  Future<void> pinch(
    String sessionId, {
    required ViewportPoint firstFrom,
    required ViewportPoint firstTo,
    required ViewportPoint secondFrom,
    required ViewportPoint secondTo,
    int durationMs = 420,
  }) async {
    if (durationMs < 0) {
      throw const AppiumClientException(
        'Pinch duration must be zero or greater.',
      );
    }
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/actions',
      payload: AppiumActionPayloads.pinch(
        firstFrom: firstFrom,
        firstTo: firstTo,
        secondFrom: secondFrom,
        secondTo: secondTo,
        durationMs: durationMs,
      ),
    );
  }

  // 向当前焦点输入文本。
  Future<void> inputText(String sessionId, {required String text}) async {
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/keys',
      payload: <String, Object?>{'text': text, 'value': text.split('')},
    );
  }

  // 启动指定 App；iOS 传 bundle id，Android 传 package name。
  Future<void> activateApp(String sessionId, {required String appId}) async {
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/appium/device/activate_app',
      payload: <String, Object?>{'appId': appId},
    );
  }

  // 停止指定 App；iOS 传 bundle id，Android 传 package name。
  Future<void> terminateApp(String sessionId, {required String appId}) async {
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/appium/device/terminate_app',
      payload: <String, Object?>{'appId': appId},
    );
  }

  // 执行受控 iOS 移动端硬件键命令。
  // 当前只开放白名单按钮，不接受调用方传入任意脚本。
  Future<void> pressButton(
    String sessionId, {
    required AppiumMobileButton button,
  }) async {
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/execute/sync',
      payload: <String, Object?>{
        'script': 'mobile: pressButton',
        'args': <Object?>[
          <String, Object?>{'name': button.wireName},
        ],
      },
    );
  }

  // 执行受控 Android 硬件键命令。
  // 仅接受白名单枚举，不让 Runtime 传入任意 keycode。
  Future<void> pressAndroidKey(
    String sessionId, {
    required AppiumAndroidKey key,
  }) async {
    await _transport.sendJson(
      method: 'POST',
      path: '/session/$sessionId/appium/device/press_keycode',
      payload: <String, Object?>{'keycode': key.keyCode},
    );
  }

  // 释放 W3C actions，Tap 失败时 Runtime 也应尽力调用。
  Future<void> releaseActions(String sessionId) async {
    await _transport.sendJson(
      method: 'DELETE',
      path: '/session/$sessionId/actions',
    );
  }

  // 关闭 HTTP client。
  void close({bool force = false}) {
    _transport.close(force: force);
  }
}
