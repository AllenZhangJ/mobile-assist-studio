import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:appium_client/appium_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_runtime/studio_runtime.dart';
import 'package:workflow_dsl/workflow_dsl.dart';

// 测试夹具，收敛跨文件复用的桌面窗口、剪贴板和轻量 Runtime fake。
// 这里只提供测试辅助，不承载产品逻辑或设备动作。

// 设置桌面测试窗口尺寸，并在用例结束后自动恢复。
Future<void> useDesktopSurface(
  WidgetTester tester, {
  Size size = const Size(1200, 800),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
}

// 安装剪贴板读写 mock，返回最近一次剪贴板文本读取器。
String? Function() captureClipboardText([String? initialText]) {
  String? copiedText = initialText;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          copiedText = arguments['text'] as String?;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': copiedText};
        }
        return null;
      });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return () => copiedText;
}

// 构造缺失子流程引用的 Project DSL，用于验证全局状态和预检拦截。
WorkflowDefinition missingSubWorkflowDefinition() {
  return WorkflowDefinition(
    id: 'missing-sub-workflow-test',
    name: '缺失子流程测试',
    entryNodesId: 'start',
    nodes: const [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['child'],
      ),
      WorkflowNode(
        id: 'child',
        type: WorkflowNodeType.subWorkflow,
        label: '缺失子流程',
        parameters: {'workflowId': 'missing-child'},
        next: ['end'],
      ),
      WorkflowNode(id: 'end', type: WorkflowNodeType.end, label: '结束'),
    ],
  );
}

// 本机依赖检查 fake，供命令中心和设备准备度测试稳定返回结果。
final class FakeDependencyChecker implements LocalDependencyChecker {
  const FakeDependencyChecker(this.report);

  final LocalDependencyReport report;

  // 返回预设检查结果，不访问真实本机环境。
  @override
  Future<LocalDependencyReport> check({
    required AppiumProcessConfig appiumProcess,
  }) async {
    return report;
  }
}

// 运行详情读取 fake，用于 Monitor 和 Execute 的详情抽屉回归。
final class FakeRunDetailReader implements RunDetailReader {
  const FakeRunDetailReader(this.details);

  final Map<String, RunDetail> details;

  // 按 runId 返回预设详情，不访问真实 evidence 文件。
  @override
  Future<RunDetail?> readDetail(String runId) async {
    return details[runId];
  }
}

// 运行报告读取 fake，用于 Monitor 报告 UI 和导出回归。
final class FakeRunReportReader implements RunReportReader {
  const FakeRunReportReader(this.reports);

  final Map<String, RunLocalReport> reports;

  // 按 runId 返回预设报告，不访问真实 evidence 文件。
  @override
  Future<RunLocalReport?> readReport(String runId) async {
    return reports[runId];
  }
}

// 运行报告导出 fake，用于验证 UI 委托 Runtime 导出而非直接写文件。
final class FakeRunReportExporter implements RunReportExporter {
  FakeRunReportExporter(this.results);

  final Map<String, RunReportExportResult> results;
  final exportedRunIds = <String>[];

  // 记录导出请求，并按 runId 返回预设安全路径。
  @override
  Future<RunReportExportResult?> exportReport(String runId) async {
    exportedRunIds.add(runId);
    return results[runId];
  }
}

// 运行截图读取 fake，只从内存中的 base64 映射生成图片字节。
final class FakeRunEvidenceAssetReader implements RunEvidenceAssetReader {
  const FakeRunEvidenceAssetReader(this.screenshots);

  final Map<String, String> screenshots;

  // 使用 runId 与相对路径组合键读取截图，保持测试输入脱敏。
  @override
  Future<List<int>?> readScreenshot(String runId, String relativePath) async {
    final encoded = screenshots['$runId/$relativePath'];
    return encoded == null ? null : base64Decode(encoded);
  }
}

// 设备会话 fake，提供稳定 session，避免测试启动真实 Appium。
final class FakeDeviceSessionManager implements RuntimeSessionManager {
  FakeDeviceSessionManager(this.sessionId);

  final String sessionId;
  WebDriverSession? _session;

  // 暴露当前测试会话，模拟 Runtime 的会话缓存。
  @override
  WebDriverSession? get session => _session;

  // 建立内存会话，不连接真实 iPhone。
  @override
  Future<WebDriverSession> connect() async {
    return _session ??= WebDriverSession(
      id: sessionId,
      capabilities: const {'platformName': 'iOS'},
    );
  }

  // 清空内存会话，用于断开流程测试。
  @override
  Future<void> disconnect() async {
    _session = null;
  }
}

// 设备动作 fake，记录截图、点击、滑动和输入调用顺序。
final class FakePreviewDeviceActionExecutor implements DeviceActionExecutor {
  FakePreviewDeviceActionExecutor({
    required this.screenshotBase64,
    required ViewportSize viewportSize,
    this.pageSourceXml = '',
  }) : _viewportSize = viewportSize;

  final String screenshotBase64;
  final String pageSourceXml;
  final ViewportSize _viewportSize;
  final calls = <String>[];

  // 记录释放动作，验证指针动作最终被收口。
  @override
  Future<void> releaseActions(String sessionId) async {
    calls.add('release');
  }

  // 返回预设截图，避免测试访问真实设备画面。
  @override
  Future<String> screenshot(String sessionId) async {
    calls.add('screenshot');
    return screenshotBase64;
  }

  // 返回预设视口，保证坐标换算稳定可断言。
  @override
  Future<ViewportSize> viewportSize(String sessionId) async {
    calls.add('viewport:$sessionId');
    return _viewportSize;
  }

  // 返回预设页面源，默认空源用于视觉类安全暂停测试。
  @override
  Future<String> pageSource(String sessionId) async {
    calls.add('source:$sessionId');
    return pageSourceXml;
  }

  // 记录点击参数，验证 UI 坐标已转换到设备视口。
  @override
  Future<void> tap(String sessionId, RuntimeTap tap) async {
    calls.add(
      'tap:${tap.label}:${tap.point.x},${tap.point.y}:${tap.durationMs}',
    );
  }

  // 记录滑动参数，验证滚动和拖拽都走受保护手势。
  @override
  Future<void> swipe(String sessionId, RuntimeSwipe swipe) async {
    calls.add(
      'swipe:${swipe.label}:${swipe.from.x},${swipe.from.y}->${swipe.to.x},${swipe.to.y}:${swipe.durationMs}',
    );
  }

  // 记录双指缩放参数，验证 UI 只触发受控 Runtime 手势。
  @override
  Future<void> pinch(String sessionId, RuntimePinch pinch) async {
    calls.add(
      'pinch:${pinch.label}:${pinch.firstFrom.x},${pinch.firstFrom.y}->${pinch.firstTo.x},${pinch.firstTo.y}|${pinch.secondFrom.x},${pinch.secondFrom.y}->${pinch.secondTo.x},${pinch.secondTo.y}:${pinch.durationMs}',
    );
  }

  // 只记录输入长度，保持测试与产品日志一样不暴露明文。
  @override
  Future<void> inputText(String sessionId, RuntimeInput input) async {
    calls.add('input:${input.label}:${input.text.length}');
  }

  // 记录 App 启动动作，验证 UI fake 不连接真实设备。
  @override
  Future<void> launchApp(String sessionId, String appId) async {
    calls.add('launch:$appId');
  }

  // 记录 App 停止动作，验证 UI fake 不连接真实设备。
  @override
  Future<void> stopApp(String sessionId, String appId) async {
    calls.add('stop:$appId');
  }

  // 记录硬件键动作，验证 Flutter 只触发受控 Runtime 命令。
  @override
  Future<void> pressButton(String sessionId, RuntimeDeviceButton button) async {
    calls.add('button:${button.label}');
  }
}

// 一像素 PNG，用于预览类测试稳定构造截图。
const onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

// 生成指定尺寸的测试 PNG，供预览坐标换算用例使用。
// 图片内容不重要，尺寸才是录制坐标基准。
Future<String> testPngBase64({required int width, required int height}) async {
  return base64Encode(_testPngBytes(width: width, height: height));
}

// 等待某个 Finder 在有限帧内出现。
// 用于图片解码等异步 UI 状态，避免 pumpAndSettle 无限等待。
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int attempts = 12,
}) async {
  for (var index = 0; index < attempts; index += 1) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// 用纯 Dart 生成最小 RGB PNG，避免 widget test 依赖渲染管线。
// 该 PNG 只用于截图尺寸解析，不表达真实设备画面。
Uint8List _testPngBytes({required int width, required int height}) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < height; y += 1) {
    raw.addByte(0);
    for (var x = 0; x < width; x += 1) {
      raw.add(const [0x10, 0x18, 0x20]);
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

// 写入 PNG chunk，并补充长度和 CRC。
// CRC 覆盖 type + data，保证 Flutter 图片解码器接受测试图。
Uint8List _pngChunk(String type, Uint8List data) {
  final typeBytes = ascii.encode(type);
  final chunk = BytesBuilder(copy: false)
    ..add(_uint32Bytes(data.length))
    ..add(typeBytes)
    ..add(data)
    ..add(_uint32Bytes(_crc32([...typeBytes, ...data])));
  return chunk.takeBytes();
}

// 按 PNG 要求写入大端 uint32。
// Dart ByteData 默认可指定 endian，避免手写移位出错。
Uint8List _uint32Bytes(int value) {
  final data = ByteData(4)..setUint32(0, value);
  return data.buffer.asUint8List();
}

// 计算 PNG 使用的 CRC32。
// 只用于测试图生成，保持本文件自包含。
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

// 在工作流画布中选择指定节点，统一节点点击后的等待节奏。
Future<void> selectWorkflowNode(WidgetTester tester, String nodeId) async {
  final finder = find.byKey(ValueKey('workflow-node-$nodeId'));
  final node = tester.widget<InkWell>(finder);
  expect(node.onTap, isNotNull);
  node.onTap!();
  await tester.pump(const Duration(milliseconds: 250));
}

// 保存当前 Inspector 选中节点，等待 Runtime 与 UI 状态同步完成。
Future<void> saveSelectedNodes(WidgetTester tester) async {
  final saveButton = tester.widget<FilledButton>(
    find.byKey(const ValueKey('node-inspector-save')),
  );
  expect(saveButton.onPressed, isNotNull);
  saveButton.onPressed!();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  });
  await tester.pump(const Duration(milliseconds: 250));
}

// 构造一个单入口双分支 workflow，用于验证画布复制不会压平分支结构。
// 分支源只包含脱敏节点和视觉位置，不包含设备或运行时数据。
WorkflowDefinition branchClipboardSourceWorkflow() {
  return const WorkflowDefinition(
    id: 'branch-copy-source',
    name: '分支复制源',
    entryNodesId: 'start',
    nodes: [
      WorkflowNode(
        id: 'start',
        type: WorkflowNodeType.start,
        label: '开始',
        next: ['condition_1'],
        visual: WorkflowNodeVisual(x: 20, y: 160),
      ),
      WorkflowNode(
        id: 'condition_1',
        type: WorkflowNodeType.condition,
        label: '判断',
        next: ['true_tap', 'false_tap'],
        parameters: {'expression': 'context.flag'},
        visual: WorkflowNodeVisual(x: 220, y: 160),
      ),
      WorkflowNode(
        id: 'true_tap',
        type: WorkflowNodeType.tap,
        label: '成功点击',
        next: ['end'],
        parameters: {'x': 100, 'y': 200},
        visual: WorkflowNodeVisual(x: 480, y: 80),
      ),
      WorkflowNode(
        id: 'false_tap',
        type: WorkflowNodeType.tap,
        label: '兜底点击',
        next: ['end'],
        parameters: {'x': 120, 'y': 220},
        visual: WorkflowNodeVisual(x: 480, y: 260),
      ),
      WorkflowNode(
        id: 'end',
        type: WorkflowNodeType.end,
        label: '结束',
        visual: WorkflowNodeVisual(x: 720, y: 160),
      ),
    ],
  );
}

// 生成画布系统剪贴板私有 JSON，测试只写入节点快照字段。
// 该格式不包含设备标识、session、WDA endpoint 或运行证据。
String workflowClipboardText(List<WorkflowNode> nodes) {
  return jsonEncode(<String, Object?>{
    'kind': 'ios-assist-studio.workflow-canvas-clipboard',
    'version': 1,
    'nodes': nodes.map((node) => node.toJson()).toList(growable: false),
  });
}
