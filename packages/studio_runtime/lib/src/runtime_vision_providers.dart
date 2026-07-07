part of '../studio_runtime.dart';

// CompositeTargetResolver 是 V4 Vision Core 的统一入口。
// 它只调度 provider 解析目标，不执行设备动作。
final class CompositeTargetResolver implements TargetResolver {
  const CompositeTargetResolver({required this.providers});

  final List<VisionProvider> providers;

  // 创建当前 V4 默认解析器。
  // Python sidecar 未接入时，fixture 级图片解析仍可用于测试和本地兜底。
  factory CompositeTargetResolver.v4Default() {
    return const CompositeTargetResolver(
      providers: <VisionProvider>[
        CoordinateTargetProvider(),
        RegionTargetProvider(),
        SelectorTargetProvider(),
        TextTargetProvider(),
        PyxelatorFixtureVisionProvider(),
      ],
    );
  }

  // 创建启用 Python 视觉增强的解析器。
  // Python 失败会返回结构化错误，避免静默退回后误判目标。
  factory CompositeTargetResolver.v4WithPython({
    PythonVisionSidecarClient client = const PythonVisionSidecarClient(),
  }) {
    return CompositeTargetResolver(
      providers: <VisionProvider>[
        const CoordinateTargetProvider(),
        const RegionTargetProvider(),
        const SelectorTargetProvider(),
        const TextTargetProvider(),
        PythonOcrTextProvider(client: client),
        PythonSidecarVisionProvider(
          client: client,
          backend: PythonVisionBackend.pyxelator,
        ),
        PythonSidecarVisionProvider(
          client: client,
          backend: PythonVisionBackend.airtest,
        ),
        PythonSidecarVisionProvider(
          client: client,
          backend: PythonVisionBackend.builtin,
        ),
        const PyxelatorFixtureVisionProvider(),
      ],
    );
  }

  // 按 provider 顺序解析目标，unsupported 会继续尝试下一个 provider。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    var unsupportedMessage = '当前目标暂不支持。';
    TargetResolutionResult? textNotMatchedFallback;
    for (final provider in providers) {
      if (!provider.supports(request.target.kind)) continue;
      final result = await provider.resolve(request);
      if (result.status == TargetResolutionStatus.unsupported) {
        unsupportedMessage = result.message;
        continue;
      }
      if (request.target.kind == RuntimeTargetKind.text &&
          result.status == TargetResolutionStatus.notMatched) {
        textNotMatchedFallback ??= result;
        continue;
      }
      return result;
    }
    if (textNotMatchedFallback != null) return textNotMatchedFallback;
    return TargetResolutionResult.unsupported(unsupportedMessage);
  }
}

// 坐标目标 provider，供 Visual Branch 和 TargetResolver 共享坐标解析语义。
// 坐标目标不需要截图识别，置信度固定为 1。
final class CoordinateTargetProvider implements VisionProvider {
  const CoordinateTargetProvider();

  @override
  String get id => 'coordinate';

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.coordinate;

  // 将坐标目标转换成匹配结果。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final x = _targetPayloadInt(request.target, 'x');
    final y = _targetPayloadInt(request.target, 'y');
    if (x == null || y == null) {
      return TargetResolutionResult.infrastructureError('坐标目标缺少位置。');
    }
    return TargetResolutionResult.matched(
      point: ViewportPoint(x: x, y: y),
      confidence: 1,
      evidenceRef: 'vision://coordinate',
    );
  }
}

// 区域目标 provider，把安全矩形解析为中心点。
// 它不读取设备 source，也不执行点击。
final class RegionTargetProvider implements VisionProvider {
  const RegionTargetProvider();

  @override
  String get id => 'region';

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.region;

  // 将区域目标转换成中心点匹配结果。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final x = _targetPayloadInt(request.target, 'x');
    final y = _targetPayloadInt(request.target, 'y');
    final width = _targetPayloadInt(request.target, 'width');
    final height = _targetPayloadInt(request.target, 'height');
    if (x == null || y == null || width == null || height == null) {
      return TargetResolutionResult.infrastructureError('区域目标缺少范围。');
    }
    if (width <= 0 || height <= 0) {
      return TargetResolutionResult.infrastructureError('区域目标范围不可用。');
    }
    return TargetResolutionResult.matched(
      point: ViewportPoint(
        x: (x + width / 2).round(),
        y: (y + height / 2).round(),
      ),
      region: RuntimeRegion(
        x: x.toDouble(),
        y: y.toDouble(),
        width: width.toDouble(),
        height: height.toDouble(),
      ),
      confidence: 1,
      evidenceRef: 'vision://region',
    );
  }
}

// Selector 目标 provider，通过 Appium source 摘要树定位元素中心点。
// 它只读取脱敏元素树，不执行点击，也不支持任意 XPath 或脚本。
final class SelectorTargetProvider implements VisionProvider {
  const SelectorTargetProvider({this.parser = const InspectorSourceParser()});

  final InspectorSourceParser parser;

  @override
  String get id => 'selector';

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.selector;

  // 解析受控 selector，并返回第一个有可用 bounds 的元素中心点。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final query = _selectorTargetQuery(request.target);
    if (query == null) {
      return TargetResolutionResult.infrastructureError('元素目标缺少选择条件。');
    }
    final sourceXml = request.sourceXml?.trim();
    if (sourceXml == null || sourceXml.isEmpty) {
      return TargetResolutionResult.unsupported('界面结构缺失。');
    }
    final root = parser.parse(sourceXml).root;
    if (root == null) {
      return TargetResolutionResult.notMatched(
        evidenceRef: 'vision://selector-source',
      );
    }
    final match = _findSelectorMatch(root, query);
    if (match == null) {
      return TargetResolutionResult.notMatched(
        evidenceRef: 'vision://selector-source',
      );
    }
    final bounds = match.bounds;
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
      return TargetResolutionResult.infrastructureError('元素缺少范围。');
    }
    return TargetResolutionResult.matched(
      point: ViewportPoint(
        x: (bounds.x + bounds.width / 2).round(),
        y: (bounds.y + bounds.height / 2).round(),
      ),
      region: bounds,
      confidence: 1,
      evidenceRef: 'vision://selector-source',
    );
  }
}

// 文本目标 provider，通过 Appium source 中的可见短文本定位元素。
// Python OCR 是后续 provider，这里只做轻量 source 解析。
final class TextTargetProvider implements VisionProvider {
  const TextTargetProvider({this.parser = const InspectorSourceParser()});

  final InspectorSourceParser parser;

  @override
  String get id => 'text';

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.text;

  // 查找 label 或 value 与 query 完全一致的元素，并返回中心点。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final query = _textTargetQuery(request.target);
    if (query == null) {
      return TargetResolutionResult.infrastructureError('文本目标缺少查询内容。');
    }
    final sourceXml = request.sourceXml?.trim();
    if (sourceXml == null || sourceXml.isEmpty) {
      return TargetResolutionResult.unsupported('界面结构缺失。');
    }
    final root = parser.parse(sourceXml).root;
    if (root == null) {
      return TargetResolutionResult.notMatched(
        evidenceRef: 'vision://text-source',
      );
    }
    final match = _findSelectorMatch(
      root,
      _SelectorTargetQuery(field: _SelectorTargetField.text, value: query),
    );
    if (match == null) {
      return TargetResolutionResult.notMatched(
        evidenceRef: 'vision://text-source',
      );
    }
    final bounds = match.bounds;
    if (bounds == null || bounds.width <= 0 || bounds.height <= 0) {
      return TargetResolutionResult.infrastructureError('文本缺少范围。');
    }
    return TargetResolutionResult.matched(
      point: ViewportPoint(
        x: (bounds.x + bounds.width / 2).round(),
        y: (bounds.y + bounds.height / 2).round(),
      ),
      region: bounds,
      confidence: 1,
      evidenceRef: 'vision://text-source',
    );
  }
}

// Pyxelator fixture provider，提供轻量模板匹配能力。
// 真实 Pyxelator / OpenCV sidecar 进入前，它只处理小尺寸 fixture。
final class PyxelatorFixtureVisionProvider implements VisionProvider {
  const PyxelatorFixtureVisionProvider({this.maxOperations = 5000000});

  final int maxOperations;

  @override
  String get id => 'pyxelator-fixture';

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.image;

  // 解析 image target 中的内联模板，返回中心点和置信度。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final templateBase64 = _targetPayloadString(request.target, 'imageBase64');
    if (templateBase64 == null || templateBase64.isEmpty) {
      return TargetResolutionResult.unsupported('图片目标缺少模板。');
    }

    final screen = _decodeRuntimePngBase64(request.screenshotBase64);
    final template = _decodeRuntimePngBase64(templateBase64);
    if (screen == null || template == null) {
      return TargetResolutionResult.infrastructureError('图片无法解析。');
    }
    final match = _matchTemplate(
      screen: screen,
      template: template,
      maxOperations: maxOperations,
    );
    if (match == null) {
      return TargetResolutionResult.unsupported('图片过大，请使用视觉服务。');
    }
    if (match.confidence >= request.confidenceThreshold) {
      return TargetResolutionResult.matched(
        point: ViewportPoint(
          x: match.centerX.round(),
          y: match.centerY.round(),
        ),
        region: RuntimeRegion(
          x: match.x.toDouble(),
          y: match.y.toDouble(),
          width: template.width.toDouble(),
          height: template.height.toDouble(),
        ),
        confidence: match.confidence,
        evidenceRef: 'vision://pyxelator-fixture',
      );
    }
    if (match.confidence <= 0) {
      return TargetResolutionResult.notMatched(
        evidenceRef: 'vision://pyxelator-fixture',
      );
    }
    return TargetResolutionResult.lowConfidence(
      confidence: match.confidence,
      evidenceRef: 'vision://pyxelator-fixture',
    );
  }
}

// Python sidecar provider，负责把图片目标解析委托给短生命周期 Python。
// Provider 只返回坐标和证据，不持有点击、滑动或输入能力。
final class PythonSidecarVisionProvider implements VisionProvider {
  const PythonSidecarVisionProvider({
    this.client = const PythonVisionSidecarClient(),
    this.backend = PythonVisionBackend.auto,
  });

  final PythonVisionSidecarClient client;
  final PythonVisionBackend backend;

  @override
  String get id => switch (backend) {
    PythonVisionBackend.pyxelator => 'pyxelator-sidecar',
    PythonVisionBackend.airtest => 'airtest-sidecar',
    PythonVisionBackend.builtin => 'python-builtin',
    PythonVisionBackend.auto => 'python-sidecar',
  };

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.image;

  // 调用 Python sidecar 解析图片目标，并映射为 Runtime 统一结果。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final templateBase64 = _targetPayloadString(request.target, 'imageBase64');
    if (templateBase64 == null || templateBase64.isEmpty) {
      return TargetResolutionResult.unsupported('图片目标缺少模板。');
    }
    try {
      final result = await client.locateTemplate(
        screenshotBase64: request.screenshotBase64,
        templateBase64: templateBase64,
        confidenceThreshold: request.confidenceThreshold,
        backend: backend,
      );
      return _pythonSidecarResultFromJson(result);
    } on Object {
      return TargetResolutionResult.infrastructureError('Python 视觉能力不可用。');
    }
  }
}

// Python OCR 文本 provider，把截图中的文字定位委托给短生命周期 Python。
// 它只支持 text target，只返回坐标和证据，不执行点击。
final class PythonOcrTextProvider implements VisionProvider {
  const PythonOcrTextProvider({
    this.client = const PythonVisionSidecarClient(),
  });

  final PythonVisionSidecarClient client;

  @override
  String get id => 'python-ocr';

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.text;

  // 调用 Python OCR 解析文本目标，并映射为 Runtime 统一结果。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final query = _textTargetQuery(request.target);
    if (query == null) {
      return TargetResolutionResult.infrastructureError('文本目标缺少查询内容。');
    }
    try {
      final result = await client.locateText(
        screenshotBase64: request.screenshotBase64,
        query: query,
        confidenceThreshold: request.confidenceThreshold,
      );
      return _pythonSidecarResultFromJson(result);
    } on Object {
      return TargetResolutionResult.infrastructureError('Python OCR 能力不可用。');
    }
  }
}

// Airtest fixture provider，复用模板匹配结果表达视觉断言。
// 它不运行 .air 文件，也不直接控制设备。
final class AirtestFixtureVisionProvider implements VisionProvider {
  const AirtestFixtureVisionProvider({
    this.delegate = const PyxelatorFixtureVisionProvider(),
  });

  final VisionProvider delegate;

  @override
  String get id => 'airtest-fixture';

  @override
  bool supports(RuntimeTargetKind kind) => kind == RuntimeTargetKind.image;

  // 使用同一 fixture 模板匹配能力，模拟 Airtest 视觉断言返回结构。
  @override
  Future<TargetResolutionResult> resolve(
    TargetResolutionRequest request,
  ) async {
    final result = await delegate.resolve(request);
    if (result.status == TargetResolutionStatus.matched) {
      return TargetResolutionResult.matched(
        point: result.point!,
        region: result.region,
        confidence: result.confidence ?? 1,
        evidenceRef: 'vision://airtest-fixture',
      );
    }
    return result;
  }
}

// 将 Python sidecar JSON 映射为目标解析结果。
TargetResolutionResult _pythonSidecarResultFromJson(Map<String, Object?> json) {
  final status = json['status']?.toString();
  final message = json['message']?.toString();
  final confidence = _jsonDouble(json['confidence']) ?? 0;
  final evidenceRef =
      json['evidenceRef']?.toString() ?? 'vision://python-sidecar';
  return switch (status) {
    'matched' => TargetResolutionResult.matched(
      point: ViewportPoint(
        x: _jsonDouble(json['centerX'])?.round() ?? 0,
        y: _jsonDouble(json['centerY'])?.round() ?? 0,
      ),
      region: RuntimeRegion(
        x: _jsonDouble(json['x']) ?? 0,
        y: _jsonDouble(json['y']) ?? 0,
        width: _jsonDouble(json['width']) ?? 0,
        height: _jsonDouble(json['height']) ?? 0,
      ),
      confidence: confidence,
      evidenceRef: evidenceRef,
    ),
    'lowConfidence' => TargetResolutionResult.lowConfidence(
      confidence: confidence,
      evidenceRef: evidenceRef,
    ),
    'notMatched' => TargetResolutionResult.notMatched(evidenceRef: evidenceRef),
    'unsupported' => TargetResolutionResult.unsupported(
      message ?? 'Python 视觉暂不支持该目标。',
    ),
    'infrastructureError' => TargetResolutionResult.infrastructureError(
      message ?? 'Python 视觉能力不可用。',
    ),
    _ => TargetResolutionResult.infrastructureError('Python 视觉结果不可读。'),
  };
}

// PNG 解码后的最小 RGB 图像。
final class _RuntimePngImage {
  const _RuntimePngImage({
    required this.width,
    required this.height,
    required this.rgb,
  });

  final int width;
  final int height;
  final Uint8List rgb;

  // 返回指定像素 RGB 数组中的起点。
  int offsetFor(int x, int y) => (y * width + x) * 3;
}

// 模板匹配结果，包含左上角、中心点和置信度。
final class _TemplateMatch {
  const _TemplateMatch({
    required this.x,
    required this.y,
    required this.centerX,
    required this.centerY,
    required this.confidence,
  });

  final int x;
  final int y;
  final double centerX;
  final double centerY;
  final double confidence;
}

// selector 字段白名单，防止把目标系统扩展成任意查询语言。
enum _SelectorTargetField { label, value, text, type }

// 受控 selector 查询，只表达字段和值，不包含表达式或脚本。
final class _SelectorTargetQuery {
  const _SelectorTargetQuery({this.field, required this.value});

  final _SelectorTargetField? field;
  final String value;
}

// 读取目标 payload 中的整数。
int? _targetPayloadInt(RuntimeTargetDefinition target, String key) {
  final value = target.payload[key];
  return value is int ? value : null;
}

// 读取目标 payload 中的字符串。
String? _targetPayloadString(RuntimeTargetDefinition target, String key) {
  final value = target.payload[key];
  return value is String ? value.trim() : null;
}

// 从 text target payload 读取受控查询文本。
String? _textTargetQuery(RuntimeTargetDefinition target) {
  final query = _targetPayloadString(target, 'query');
  if (query == null || query.isEmpty) return null;
  return _normalizeSelectorValue(query);
}

// 从 selector target payload 读取受控查询。
_SelectorTargetQuery? _selectorTargetQuery(RuntimeTargetDefinition target) {
  final selector = _targetPayloadString(target, 'selector');
  if (selector == null || selector.isEmpty) return null;
  final separator = selector.indexOf('=');
  if (separator <= 0) {
    return _SelectorTargetQuery(value: _normalizeSelectorValue(selector));
  }
  final fieldName = selector.substring(0, separator).trim().toLowerCase();
  final value = _normalizeSelectorValue(selector.substring(separator + 1));
  if (value.isEmpty) return null;
  final field = switch (fieldName) {
    'label' || 'name' => _SelectorTargetField.label,
    'value' => _SelectorTargetField.value,
    'text' => _SelectorTargetField.text,
    'type' || 'class' => _SelectorTargetField.type,
    _ => null,
  };
  return field == null
      ? null
      : _SelectorTargetQuery(field: field, value: value);
}

// 在元素树中深度优先查找第一个 selector 命中元素。
InspectorElementSummary? _findSelectorMatch(
  InspectorElementSummary element,
  _SelectorTargetQuery query,
) {
  if (_selectorMatchesElement(element, query)) return element;
  for (final child in element.children) {
    final match = _findSelectorMatch(child, query);
    if (match != null) return match;
  }
  return null;
}

// 判断一个元素摘要是否命中受控 selector。
bool _selectorMatchesElement(
  InspectorElementSummary element,
  _SelectorTargetQuery query,
) {
  final label = _normalizeSelectorValue(element.label ?? '');
  final value = _normalizeSelectorValue(element.value ?? '');
  final type = _normalizeSelectorValue(element.type);
  return switch (query.field) {
    _SelectorTargetField.label => label == query.value,
    _SelectorTargetField.value => value == query.value,
    _SelectorTargetField.text => label == query.value || value == query.value,
    _SelectorTargetField.type => type == query.value,
    null => label == query.value || value == query.value || type == query.value,
  };
}

// 规范化 selector 和元素文本，避免大小写或空白造成误判。
String _normalizeSelectorValue(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

// 从 JSON 读取数字字段。
double? _jsonDouble(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

// 从 base64 PNG 解出最小 RGB 图像。
_RuntimePngImage? _decodeRuntimePngBase64(String imageBase64) {
  try {
    return _decodeRuntimePng(base64Decode(imageBase64));
  } on Object {
    return null;
  }
}

// 解码 8-bit PNG，支持灰度、RGB 和 RGBA。
_RuntimePngImage? _decodeRuntimePng(Uint8List bytes) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (bytes.length < 33) return null;
  for (var index = 0; index < signature.length; index += 1) {
    if (bytes[index] != signature[index]) return null;
  }

  var offset = 8;
  var width = 0;
  var height = 0;
  var bitDepth = 0;
  var colorType = 0;
  final idat = BytesBuilder(copy: false);
  while (offset + 8 <= bytes.length) {
    final length = _readUint32(bytes, offset);
    offset += 4;
    if (offset + 4 + length + 4 > bytes.length) return null;
    final type = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    offset += 4;
    final data = bytes.sublist(offset, offset + length);
    offset += length + 4;
    if (type == 'IHDR') {
      if (data.length < 13) return null;
      width = _readUint32(data, 0);
      height = _readUint32(data, 4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type == 'IDAT') {
      idat.add(data);
    } else if (type == 'IEND') {
      break;
    }
  }
  if (width <= 0 || height <= 0 || bitDepth != 8) return null;
  final channels = switch (colorType) {
    0 => 1,
    2 => 3,
    6 => 4,
    _ => 0,
  };
  if (channels == 0) return null;

  final inflated = Uint8List.fromList(zlib.decode(idat.takeBytes()));
  final rowBytes = width * channels;
  final expected = (rowBytes + 1) * height;
  if (inflated.length < expected) return null;

  final raw = Uint8List(rowBytes * height);
  var sourceOffset = 0;
  for (var y = 0; y < height; y += 1) {
    final filter = inflated[sourceOffset];
    sourceOffset += 1;
    final rowStart = y * rowBytes;
    for (var x = 0; x < rowBytes; x += 1) {
      final current = inflated[sourceOffset + x];
      final left = x >= channels ? raw[rowStart + x - channels] : 0;
      final up = y > 0 ? raw[rowStart + x - rowBytes] : 0;
      final upLeft = y > 0 && x >= channels
          ? raw[rowStart + x - rowBytes - channels]
          : 0;
      raw[rowStart + x] = switch (filter) {
        0 => current,
        1 => (current + left) & 0xFF,
        2 => (current + up) & 0xFF,
        3 => (current + ((left + up) >> 1)) & 0xFF,
        4 => (current + _paeth(left, up, upLeft)) & 0xFF,
        _ => current,
      };
    }
    sourceOffset += rowBytes;
  }

  final rgb = Uint8List(width * height * 3);
  for (var y = 0; y < height; y += 1) {
    for (var x = 0; x < width; x += 1) {
      final rawOffset = y * rowBytes + x * channels;
      final rgbOffset = (y * width + x) * 3;
      if (channels == 1) {
        final value = raw[rawOffset];
        rgb[rgbOffset] = value;
        rgb[rgbOffset + 1] = value;
        rgb[rgbOffset + 2] = value;
      } else {
        rgb[rgbOffset] = raw[rawOffset];
        rgb[rgbOffset + 1] = raw[rawOffset + 1];
        rgb[rgbOffset + 2] = raw[rawOffset + 2];
      }
    }
  }
  return _RuntimePngImage(width: width, height: height, rgb: rgb);
}

// 在截图中查找模板，超出操作量上限时返回 null。
_TemplateMatch? _matchTemplate({
  required _RuntimePngImage screen,
  required _RuntimePngImage template,
  required int maxOperations,
}) {
  if (template.width > screen.width || template.height > screen.height) {
    return const _TemplateMatch(
      x: 0,
      y: 0,
      centerX: 0,
      centerY: 0,
      confidence: 0,
    );
  }
  final positions =
      (screen.width - template.width + 1) *
      (screen.height - template.height + 1);
  final operations = positions * template.width * template.height;
  if (operations > maxOperations) return null;

  var bestDiff = double.infinity;
  var bestX = 0;
  var bestY = 0;
  for (var y = 0; y <= screen.height - template.height; y += 1) {
    for (var x = 0; x <= screen.width - template.width; x += 1) {
      final diff = _templateDiff(screen, template, x, y);
      if (diff < bestDiff) {
        bestDiff = diff.toDouble();
        bestX = x;
        bestY = y;
        if (diff == 0) {
          return _TemplateMatch(
            x: bestX,
            y: bestY,
            centerX: bestX + template.width / 2,
            centerY: bestY + template.height / 2,
            confidence: 1,
          );
        }
      }
    }
  }
  final maxDiff = template.width * template.height * 3 * 255;
  final confidence = maxDiff <= 0 ? 0 : (1 - bestDiff / maxDiff).clamp(0, 1);
  return _TemplateMatch(
    x: bestX,
    y: bestY,
    centerX: bestX + template.width / 2,
    centerY: bestY + template.height / 2,
    confidence: confidence.toDouble(),
  );
}

// 计算模板在指定位置的 RGB 绝对差。
int _templateDiff(
  _RuntimePngImage screen,
  _RuntimePngImage template,
  int offsetX,
  int offsetY,
) {
  var diff = 0;
  for (var y = 0; y < template.height; y += 1) {
    for (var x = 0; x < template.width; x += 1) {
      final screenOffset = screen.offsetFor(offsetX + x, offsetY + y);
      final templateOffset = template.offsetFor(x, y);
      diff += (screen.rgb[screenOffset] - template.rgb[templateOffset]).abs();
      diff += (screen.rgb[screenOffset + 1] - template.rgb[templateOffset + 1])
          .abs();
      diff += (screen.rgb[screenOffset + 2] - template.rgb[templateOffset + 2])
          .abs();
    }
  }
  return diff;
}

// 读取大端 uint32。
int _readUint32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

// PNG Paeth filter predictor。
int _paeth(int left, int up, int upLeft) {
  final estimate = left + up - upLeft;
  final leftDistance = (estimate - left).abs();
  final upDistance = (estimate - up).abs();
  final upLeftDistance = (estimate - upLeft).abs();
  if (leftDistance <= upDistance && leftDistance <= upLeftDistance) {
    return left;
  }
  if (upDistance <= upLeftDistance) return up;
  return upLeft;
}
