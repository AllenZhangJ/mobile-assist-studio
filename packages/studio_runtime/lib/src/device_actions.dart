part of '../studio_runtime.dart';

// 设备动作执行器，负责把 Tap、Swipe、输入和截图转交给 Appium 客户端。
final class RuntimeTap {
  const RuntimeTap({
    required this.point,
    required this.label,
    required this.durationMs,
  });

  final ViewportPoint point;
  final String label;
  final int durationMs;
}

final class RuntimeSwipe {
  const RuntimeSwipe({
    required this.from,
    required this.to,
    required this.label,
    required this.durationMs,
  });

  final ViewportPoint from;
  final ViewportPoint to;
  final String label;
  final int durationMs;
}

final class RuntimePinch {
  const RuntimePinch({
    required this.firstFrom,
    required this.firstTo,
    required this.secondFrom,
    required this.secondTo,
    required this.label,
    required this.durationMs,
  });

  final ViewportPoint firstFrom;
  final ViewportPoint firstTo;
  final ViewportPoint secondFrom;
  final ViewportPoint secondTo;
  final String label;
  final int durationMs;
}

final class RuntimeInput {
  const RuntimeInput({required this.text, required this.label});

  final String text;
  final String label;
}

enum RuntimeDeviceButton {
  home('回主页');

  const RuntimeDeviceButton(this.label);

  final String label;
}

abstract interface class DeviceActionExecutor {
  Future<String> screenshot(String sessionId);

  Future<ViewportSize> viewportSize(String sessionId);

  // 读取当前页面结构，供 Runtime 做脱敏后的弹窗识别。
  Future<String> pageSource(String sessionId);

  Future<void> tap(String sessionId, RuntimeTap tap);

  Future<void> swipe(String sessionId, RuntimeSwipe swipe);

  Future<void> pinch(String sessionId, RuntimePinch pinch);

  Future<void> inputText(String sessionId, RuntimeInput input);

  Future<void> pressButton(String sessionId, RuntimeDeviceButton button);

  Future<void> releaseActions(String sessionId);
}

final class AppiumDeviceActionExecutor implements DeviceActionExecutor {
  AppiumDeviceActionExecutor([AppiumClient? client])
    : _client = client ?? AppiumClient();

  final AppiumClient _client;

  @override
  Future<String> screenshot(String sessionId) {
    return _client.screenshot(sessionId);
  }

  @override
  Future<ViewportSize> viewportSize(String sessionId) {
    return _client.viewportSize(sessionId);
  }

  // 转交 Appium source 请求；原始 XML 不在本层持久化。
  @override
  Future<String> pageSource(String sessionId) {
    return _client.pageSource(sessionId);
  }

  @override
  Future<void> tap(String sessionId, RuntimeTap tap) {
    return _client.tap(sessionId, point: tap.point, durationMs: tap.durationMs);
  }

  @override
  Future<void> swipe(String sessionId, RuntimeSwipe swipe) {
    return _client.swipe(
      sessionId,
      from: swipe.from,
      to: swipe.to,
      durationMs: swipe.durationMs,
    );
  }

  @override
  Future<void> pinch(String sessionId, RuntimePinch pinch) {
    return _client.pinch(
      sessionId,
      firstFrom: pinch.firstFrom,
      firstTo: pinch.firstTo,
      secondFrom: pinch.secondFrom,
      secondTo: pinch.secondTo,
      durationMs: pinch.durationMs,
    );
  }

  @override
  Future<void> inputText(String sessionId, RuntimeInput input) {
    return _client.inputText(sessionId, text: input.text);
  }

  // 只转发 Runtime 允许的硬件键，不暴露任意 mobile script。
  @override
  Future<void> pressButton(String sessionId, RuntimeDeviceButton button) {
    return _client.pressButton(
      sessionId,
      button: switch (button) {
        RuntimeDeviceButton.home => AppiumMobileButton.home,
      },
    );
  }

  @override
  Future<void> releaseActions(String sessionId) {
    return _client.releaseActions(sessionId);
  }
}
