part of '../appium_client.dart';

// ViewportPoint 表示 WDA viewport 坐标。
// 上层 Runtime 会先把归一化意图换算成这个坐标。
final class ViewportPoint {
  // 创建 viewport 坐标点。
  const ViewportPoint({required this.x, required this.y});

  final int x;
  final int y;
}

// ViewportSize 表示当前 WebDriver window rect 尺寸。
// 它用于把预览坐标映射到真实设备 viewport。
final class ViewportSize {
  // 创建 viewport 尺寸。
  const ViewportSize({required this.width, required this.height});

  final int width;
  final int height;

  // 从 Appium window rect 响应解析尺寸。
  factory ViewportSize.fromJson(Map<String, Object?> json) {
    final value = json['value'];
    final source = value is Map<String, Object?> ? value : json;
    final width = _requiredPositiveInt(source, 'width');
    final height = _requiredPositiveInt(source, 'height');
    return ViewportSize(width: width, height: height);
  }
}

// _requiredPositiveInt 从响应里读取正整数。
// window rect 的宽高必须有效，否则后续坐标映射不安全。
int _requiredPositiveInt(Map<String, Object?> json, String key) {
  final value = json[key];
  final number = switch (value) {
    int() => value,
    double() when value.isFinite => value.round(),
    _ => null,
  };
  if (number == null || number <= 0) {
    throw AppiumClientException('Viewport $key must be a positive number.');
  }
  return number;
}
