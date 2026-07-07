import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appium_client/appium_client.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:test/test.dart';

// 启动一个最小 Appium session fake server，覆盖创建和删除会话。
// 用例通过它验证 Runtime 会话状态，不连接真实 Appium 或 iPhone。
Future<HttpServer> sessionServer(String sessionId) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    if (request.method == 'POST' && request.uri.path == '/session') {
      await utf8.decodeStream(request);
      request.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'value': {
              'sessionId': sessionId,
              'capabilities': {'platformName': 'iOS'},
            },
          }),
        )
        ..close();
      return;
    }
    if (request.method == 'DELETE' &&
        request.uri.path == '/session/$sessionId') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'value': null}))
        ..close();
      return;
    }
    request.response
      ..statusCode = 404
      ..close();
  });
  return server;
}

// 创建指向 fake Appium server 的 Runtime session manager。
// 测试仍显式控制 connect、dispose 和 server close，避免隐藏生命周期边界。
DeviceSessionManager fakeSessionManager(
  HttpServer server, {
  DeviceSessionConfig config = const DeviceSessionConfig(
    capabilities: {
      'platformName': 'iOS',
      'appium:automationName': 'XCUITest',
      'appium:udid': 'TEST_DEVICE',
    },
  ),
}) {
  return DeviceSessionManager(
    client: AppiumClient(config: AppiumServerConfig(port: server.port)),
    config: config,
  );
}

// Appium 可用性 fake，按给定响应序列返回 ready / not ready。
// 它保留检查次数，便于验证 readiness 等待和超时路径。
final class FakeAvailabilityChecker implements AppiumAvailabilityChecker {
  FakeAvailabilityChecker(List<AppiumAvailability> responses)
    : _responses = List<AppiumAvailability>.of(responses);

  final List<AppiumAvailability> _responses;
  AppiumAvailability? _last;
  int checks = 0;

  @override
  Future<AppiumAvailability> check() async {
    checks += 1;
    if (_responses.isNotEmpty) {
      _last = _responses.removeAt(0);
      return _last!;
    }
    return _last ??
        const AppiumAvailability(available: false, message: 'not ready');
  }
}

// 会话管理 fake，按顺序失败或成功，用于验证连接诊断生命周期。
final class SequencedSessionManager implements RuntimeSessionManager {
  SequencedSessionManager(this.results);

  final List<Object> results;
  WebDriverSession? _session;
  int connects = 0;
  int disconnects = 0;

  @override
  WebDriverSession? get session => _session;

  @override
  Future<WebDriverSession> connect() async {
    final index = connects < results.length ? connects : results.length - 1;
    connects += 1;
    final result = results[index];
    if (result is WebDriverSession) {
      _session = result;
      return result;
    }
    if (result is Exception) {
      throw result;
    }
    throw StateError(result.toString());
  }

  @override
  Future<void> disconnect() async {
    disconnects += 1;
    _session = null;
  }
}

// 本机依赖检查 fake，返回预设报告并验证 Appium 配置透传。
// 它只用于 Runtime 本机检查测试，不执行任何外部命令。
final class FakeDependencyChecker implements LocalDependencyChecker {
  FakeDependencyChecker(this.report);

  final LocalDependencyReport report;
  int checks = 0;

  @override
  Future<LocalDependencyReport> check({
    required AppiumProcessConfig appiumProcess,
  }) async {
    checks += 1;
    expect(appiumProcess.executable, 'appium');
    return report;
  }
}

// 本机依赖检查序列 fake，用于验证连接过程中检查结果发生变化的路径。
// 每次 check 返回下一个报告，耗尽后重复最后一个报告。
final class SequencedDependencyChecker implements LocalDependencyChecker {
  SequencedDependencyChecker(List<LocalDependencyReport> reports)
    : _reports = List<LocalDependencyReport>.of(reports);

  final List<LocalDependencyReport> _reports;
  int checks = 0;

  @override
  Future<LocalDependencyReport> check({
    required AppiumProcessConfig appiumProcess,
  }) async {
    expect(appiumProcess.executable, 'appium');
    final index = checks < _reports.length ? checks : _reports.length - 1;
    checks += 1;
    return _reports[index];
  }
}

// Appium 进程 fake，提供 pid、exitCode 和 kill 行为。
// 用例用它验证进程生命周期，不启动真实 appium 可执行文件。
final class FakeProcessHandle implements ProcessHandle {
  FakeProcessHandle({required this.pid});

  @override
  final int pid;

  bool killed = false;
  final Completer<int> _exitCode = Completer<int>();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exitCode.isCompleted) {
      _exitCode.complete(0);
    }
    return true;
  }
}

// 本机隧道进程 fake，记录 stdin 写入但不启动 sudo。
// 用例通过它验证密码只进入进程输入，不进入 Runtime 事件。
final class FakeTunnelProcessHandle implements AppiumTunnelProcessHandle {
  FakeTunnelProcessHandle({required this.pid});

  @override
  final int pid;

  final inputLines = <String>[];
  bool inputClosed = false;
  bool killed = false;
  final Completer<int> _exitCode = Completer<int>();

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  void writeInputLine(String value) {
    inputLines.add(value);
  }

  @override
  Future<void> closeInput() async {
    inputClosed = true;
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    completeExit(0);
    return true;
  }

  // 手动结束 fake 进程，模拟 sudo 失败或正常退出。
  void completeExit(int code) {
    if (!_exitCode.isCompleted) {
      _exitCode.complete(code);
    }
  }
}

// 设备动作 fake，记录截图、viewport、tap、swipe 和输入调用。
// 它只保存脱敏调用摘要，便于验证串行执行和隐私边界。
final class FakeDeviceActionExecutor implements DeviceActionExecutor {
  FakeDeviceActionExecutor({
    this.screenshotBase64 = 'base64-screenshot',
    this.pageSourceXml = '',
    this.failingTapLabels = const <String>{},
    ViewportSize viewportSize = const ViewportSize(width: 390, height: 844),
  }) : _viewportSize = viewportSize;

  final String screenshotBase64;
  final String pageSourceXml;
  final Set<String> failingTapLabels;
  final ViewportSize _viewportSize;
  final calls = <String>[];

  @override
  Future<void> releaseActions(String sessionId) async {
    calls.add('release');
  }

  @override
  Future<String> screenshot(String sessionId) async {
    calls.add('screenshot');
    return screenshotBase64;
  }

  @override
  Future<ViewportSize> viewportSize(String sessionId) async {
    calls.add('viewport:$sessionId');
    return _viewportSize;
  }

  @override
  Future<String> pageSource(String sessionId) async {
    calls.add('source:$sessionId');
    return pageSourceXml;
  }

  @override
  Future<void> tap(String sessionId, RuntimeTap tap) async {
    calls.add(
      'tap:${tap.label}:${tap.point.x},${tap.point.y}:${tap.durationMs}',
    );
    if (failingTapLabels.contains(tap.label)) {
      throw StateError('tap failed: ${tap.label}');
    }
  }

  @override
  Future<void> swipe(String sessionId, RuntimeSwipe swipe) async {
    calls.add(
      'swipe:${swipe.label}:${swipe.from.x},${swipe.from.y}->${swipe.to.x},${swipe.to.y}:${swipe.durationMs}',
    );
  }

  @override
  Future<void> pinch(String sessionId, RuntimePinch pinch) async {
    calls.add(
      'pinch:${pinch.label}:${pinch.firstFrom.x},${pinch.firstFrom.y}->${pinch.firstTo.x},${pinch.firstTo.y}|${pinch.secondFrom.x},${pinch.secondFrom.y}->${pinch.secondTo.x},${pinch.secondTo.y}:${pinch.durationMs}',
    );
  }

  @override
  Future<void> inputText(String sessionId, RuntimeInput input) async {
    calls.add('input:${input.label}:${input.text.length}');
  }

  @override
  Future<void> pressButton(String sessionId, RuntimeDeviceButton button) async {
    calls.add('button:${button.label}');
  }
}

// 生成小尺寸 RGB PNG fixture，供 Vision provider 和视觉分支测试使用。
// 默认黑底，可通过 colorAt 为指定像素上色。
String fixturePngBase64({
  required int width,
  required int height,
  List<int> Function(int x, int y)? colorAt,
}) {
  return base64Encode(
    _fixturePngBytes(width: width, height: height, colorAt: colorAt),
  );
}

// 生成 filter 0 的最小 PNG，避免 Runtime 测试依赖外部图片资产。
Uint8List _fixturePngBytes({
  required int width,
  required int height,
  List<int> Function(int x, int y)? colorAt,
}) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < height; y += 1) {
    raw.addByte(0);
    for (var x = 0; x < width; x += 1) {
      final color = colorAt?.call(x, y) ?? const [0, 0, 0];
      raw.add(color.take(3).toList(growable: false));
    }
  }

  final ihdr = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2)
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);

  final png = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    ..add(_pngChunk('IHDR', ihdr.buffer.asUint8List()))
    ..add(_pngChunk('IDAT', Uint8List.fromList(zlib.encode(raw.takeBytes()))))
    ..add(_pngChunk('IEND', Uint8List(0)));
  return png.takeBytes();
}

// 写入 PNG chunk，并附加 CRC32。
Uint8List _pngChunk(String type, Uint8List data) {
  final typeBytes = ascii.encode(type);
  final chunk = BytesBuilder(copy: false)
    ..add(_uint32Bytes(data.length))
    ..add(typeBytes)
    ..add(data)
    ..add(_uint32Bytes(_crc32([...typeBytes, ...data])));
  return chunk.takeBytes();
}

// 按 PNG 格式写入大端 uint32。
Uint8List _uint32Bytes(int value) {
  final data = ByteData(4)..setUint32(0, value);
  return data.buffer.asUint8List();
}

// 计算 PNG chunk CRC32。
int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit += 1) {
      final mask = -(crc & 1);
      crc = (crc >> 1) ^ (0xEDB88320 & mask);
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
