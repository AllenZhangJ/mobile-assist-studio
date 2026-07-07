part of '../appium_client.dart';

// AppiumActionPayloads 构建 W3C Actions payload。
// 手势统一使用 viewport origin 和 touch pointer，保持 iOS WDA 兼容。
final class AppiumActionPayloads {
  const AppiumActionPayloads._();

  // 构建 Tap payload。
  static Map<String, Object?> tap({
    required ViewportPoint point,
    required int durationMs,
  }) {
    return _pointerPayload(<Object?>[
      _pointerMove(point: point, durationMs: 0),
      _pointerDown(),
      <String, Object?>{'type': 'pause', 'duration': durationMs},
      _pointerUp(),
    ]);
  }

  // 构建 Swipe payload。
  static Map<String, Object?> swipe({
    required ViewportPoint from,
    required ViewportPoint to,
    required int durationMs,
  }) {
    return _pointerPayload(<Object?>[
      _pointerMove(point: from, durationMs: 0),
      _pointerDown(),
      _pointerMove(point: to, durationMs: durationMs),
      _pointerUp(),
    ]);
  }

  // 构建双指 pinch payload。
  static Map<String, Object?> pinch({
    required ViewportPoint firstFrom,
    required ViewportPoint firstTo,
    required ViewportPoint secondFrom,
    required ViewportPoint secondTo,
    required int durationMs,
  }) {
    return _multiPointerPayload(<Map<String, Object?>>[
      _pointerSource('finger1', <Object?>[
        _pointerMove(point: firstFrom, durationMs: 0),
        _pointerDown(),
        _pointerMove(point: firstTo, durationMs: durationMs),
        _pointerUp(),
      ]),
      _pointerSource('finger2', <Object?>[
        _pointerMove(point: secondFrom, durationMs: 0),
        _pointerDown(),
        _pointerMove(point: secondTo, durationMs: durationMs),
        _pointerUp(),
      ]),
    ]);
  }

  // 构建 W3C pointer action 外层结构。
  static Map<String, Object?> _pointerPayload(List<Object?> actions) {
    return _multiPointerPayload(<Map<String, Object?>>[
      _pointerSource('finger1', actions),
    ]);
  }

  // 构建多指 W3C action 外层结构。
  static Map<String, Object?> _multiPointerPayload(
    List<Map<String, Object?>> sources,
  ) {
    return <String, Object?>{'actions': sources};
  }

  // 构建单个 pointer source。
  static Map<String, Object?> _pointerSource(String id, List<Object?> actions) {
    return <String, Object?>{
      'type': 'pointer',
      'id': id,
      'parameters': <String, Object?>{'pointerType': 'touch'},
      'actions': actions,
    };
  }

  // 构建 pointerMove 动作。
  static Map<String, Object?> _pointerMove({
    required ViewportPoint point,
    required int durationMs,
  }) {
    return <String, Object?>{
      'type': 'pointerMove',
      'duration': durationMs,
      'origin': 'viewport',
      'x': point.x,
      'y': point.y,
    };
  }

  // 构建 pointerDown 动作。
  static Map<String, Object?> _pointerDown() {
    return <String, Object?>{'type': 'pointerDown', 'button': 0};
  }

  // 构建 pointerUp 动作。
  static Map<String, Object?> _pointerUp() {
    return <String, Object?>{'type': 'pointerUp', 'button': 0};
  }
}
