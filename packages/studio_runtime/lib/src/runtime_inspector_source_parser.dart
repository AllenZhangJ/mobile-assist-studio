part of '../studio_runtime.dart';

// InspectorSourceParseResult 是 source 解析后的脱敏结果。
// Runtime 只把摘要树和预览文本交给 UI，不长期保存原始 XML。
final class InspectorSourceParseResult {
  // 创建解析结果。
  const InspectorSourceParseResult({
    required this.root,
    required this.elementCount,
    required this.summary,
    required this.preview,
  });

  final InspectorElementSummary? root;
  final int elementCount;
  final String summary;
  final String preview;
}

// InspectorSourceParser 将 Appium source 转为脱敏元素树。
// 解析器只支持 Appium 常见 XML 结构，失败时返回摘要而不抛给 UI。
final class InspectorSourceParser {
  // 创建 source 解析器。
  const InspectorSourceParser();

  // 解析 Appium page source，生成元素摘要和脱敏 source 预览。
  InspectorSourceParseResult parse(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return const InspectorSourceParseResult(
        root: null,
        elementCount: 0,
        summary: '未读取到界面结构。',
        preview: '',
      );
    }

    final stack = <_InspectorElementBuilder>[];
    final roots = <InspectorElementSummary>[];
    var counter = 0;
    final tagPattern = RegExp(r'<([^!?/\s>]+)([^<>]*?)(/?)>|</([^>\s]+)>');
    for (final match in tagPattern.allMatches(trimmed)) {
      final closingTag = match.group(4);
      if (closingTag != null) {
        _closeTopElement(stack, roots);
        continue;
      }
      final tag = match.group(1);
      if (tag == null) continue;
      final rawAttributes = match.group(2) ?? '';
      final selfClosing = (match.group(3) ?? '').trim() == '/';
      final builder = _InspectorElementBuilder.fromTag(
        id: 'el_${counter++}',
        tag: tag,
        attributes: _parseAttributes(rawAttributes),
      );
      if (selfClosing) {
        _appendElement(stack, roots, builder.build());
      } else {
        stack.add(builder);
      }
    }

    while (stack.isNotEmpty) {
      _closeTopElement(stack, roots);
    }

    final root = roots.isEmpty
        ? null
        : roots.length == 1
        ? roots.single
        : InspectorElementSummary(
            id: 'root',
            type: 'Screen',
            children: List<InspectorElementSummary>.unmodifiable(roots),
          );
    final elementCount = root?.totalCount ?? 0;
    return InspectorSourceParseResult(
      root: root,
      elementCount: elementCount,
      summary: elementCount == 0 ? '未识别到元素。' : '已识别 $elementCount 个元素。',
      preview: _buildSourcePreview(root),
    );
  }

  // 解析 XML 属性，只处理常见双引号和单引号属性。
  Map<String, String> _parseAttributes(String raw) {
    final attributes = <String, String>{};
    final pattern = RegExp(
      r'''([A-Za-z0-9:_\-.]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''',
    );
    for (final match in pattern.allMatches(raw)) {
      final key = match.group(1);
      if (key == null) continue;
      final value = match.group(2) ?? match.group(3) ?? '';
      attributes[key] = _decodeXml(value);
    }
    return attributes;
  }

  // 关闭当前元素，并挂到父节点或根列表。
  void _closeTopElement(
    List<_InspectorElementBuilder> stack,
    List<InspectorElementSummary> roots,
  ) {
    if (stack.isEmpty) return;
    final element = stack.removeLast().build();
    _appendElement(stack, roots, element);
  }

  // 挂载一个元素到当前父节点或根列表。
  void _appendElement(
    List<_InspectorElementBuilder> stack,
    List<InspectorElementSummary> roots,
    InspectorElementSummary element,
  ) {
    if (stack.isEmpty) {
      roots.add(element);
    } else {
      stack.last.children.add(element);
    }
  }

  // 构造脱敏 source 预览，供高级查看使用。
  String _buildSourcePreview(InspectorElementSummary? root) {
    if (root == null) return '';
    final lines = <String>[];
    void visit(InspectorElementSummary element, int depth) {
      if (lines.length >= 120) return;
      final indent = '  ' * depth;
      final label = element.label == null ? '' : ' label="${element.label}"';
      final value = element.value == null ? '' : ' value="${element.value}"';
      lines.add('$indent<${element.type}$label$value>');
      for (final child in element.children) {
        visit(child, depth + 1);
      }
    }

    visit(root, 0);
    return lines.join('\n');
  }

  // 解码常见 XML 实体。
  String _decodeXml(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }
}

// _InspectorElementBuilder 临时保存子元素，最终构造不可变摘要。
final class _InspectorElementBuilder {
  _InspectorElementBuilder({
    required this.id,
    required this.type,
    required this.attributes,
    this.label,
    this.value,
    this.bounds,
  });

  final String id;
  final String type;
  final String? label;
  final String? value;
  final RuntimeRegion? bounds;
  final Map<String, String> attributes;
  final List<InspectorElementSummary> children = <InspectorElementSummary>[];

  // 从 XML tag 和属性构造 builder。
  factory _InspectorElementBuilder.fromTag({
    required String id,
    required String tag,
    required Map<String, String> attributes,
  }) {
    return _InspectorElementBuilder(
      id: id,
      type: _elementType(tag, attributes),
      label: _safeLabel(attributes),
      value: _safeValue(attributes),
      bounds: _parseBounds(attributes),
      attributes: _safeAttributes(attributes),
    );
  }

  // 生成不可变元素摘要。
  InspectorElementSummary build() {
    return InspectorElementSummary(
      id: id,
      type: type,
      label: label,
      value: value,
      bounds: bounds,
      attributes: attributes,
      children: List<InspectorElementSummary>.unmodifiable(children),
    );
  }
}

// 选择用户可理解的元素类型。
String _elementType(String tag, Map<String, String> attributes) {
  final explicit = attributes['type'] ?? attributes['class'];
  final value = (explicit == null || explicit.trim().isEmpty)
      ? tag
      : explicit.trim();
  return _shortenType(value);
}

// 裁剪元素类型，隐藏包名前缀。
String _shortenType(String value) {
  final normalized = value.replaceFirst('XCUIElementType', '');
  final dotIndex = normalized.lastIndexOf('.');
  if (dotIndex >= 0 && dotIndex < normalized.length - 1) {
    return normalized.substring(dotIndex + 1);
  }
  return normalized.isEmpty ? 'Element' : normalized;
}

// 提取元素标签，避免展示过长或疑似敏感文本。
String? _safeLabel(Map<String, String> attributes) {
  return _firstSafeText(attributes, const [
    'label',
    'name',
    'content-desc',
    'text',
  ]);
}

// 提取元素值，密码字段统一隐藏。
String? _safeValue(Map<String, String> attributes) {
  final password = attributes['password']?.toLowerCase();
  if (password == 'true' || password == '1') return '已隐藏';
  return _firstSafeText(attributes, const ['value', 'text']);
}

// 从多个候选属性中取第一个可展示短文本。
String? _firstSafeText(Map<String, String> attributes, List<String> keys) {
  for (final key in keys) {
    final value = attributes[key]?.trim();
    if (value == null || value.isEmpty) continue;
    return _clipInspectorText(value);
  }
  return null;
}

// 裁剪 Inspector 文本，避免主界面泄露长内容。
String _clipInspectorText(String value) {
  final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (compact.length <= 32) return compact;
  return '${compact.substring(0, 32)}...';
}

// 仅保留安全、短小、用户能理解的元素属性。
Map<String, String> _safeAttributes(Map<String, String> attributes) {
  const allowed = <String>{
    'enabled',
    'visible',
    'accessible',
    'clickable',
    'selected',
    'focused',
    'checked',
    'displayed',
    'index',
  };
  final safe = <String, String>{};
  for (final key in allowed) {
    final value = attributes[key];
    if (value != null && value.trim().isNotEmpty) {
      safe[key] = _clipInspectorText(value);
    }
  }
  return Map<String, String>.unmodifiable(safe);
}

// 从 iOS 或 Android source 属性中解析元素 bounds。
RuntimeRegion? _parseBounds(Map<String, String> attributes) {
  final iosBounds = _parseIosBounds(attributes);
  if (iosBounds != null) return iosBounds;
  final androidBounds = attributes['bounds'];
  if (androidBounds == null) return null;
  final match = RegExp(
    r'^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$',
  ).firstMatch(androidBounds.trim());
  if (match == null) return null;
  final left = double.tryParse(match.group(1) ?? '');
  final top = double.tryParse(match.group(2) ?? '');
  final right = double.tryParse(match.group(3) ?? '');
  final bottom = double.tryParse(match.group(4) ?? '');
  if (left == null || top == null || right == null || bottom == null) {
    return null;
  }
  return RuntimeRegion(
    x: left,
    y: top,
    width: (right - left).clamp(0, double.infinity).toDouble(),
    height: (bottom - top).clamp(0, double.infinity).toDouble(),
  );
}

// 从 iOS x/y/width/height 属性中解析元素 bounds。
RuntimeRegion? _parseIosBounds(Map<String, String> attributes) {
  final x = double.tryParse(attributes['x'] ?? '');
  final y = double.tryParse(attributes['y'] ?? '');
  final width = double.tryParse(attributes['width'] ?? '');
  final height = double.tryParse(attributes['height'] ?? '');
  if (x == null || y == null || width == null || height == null) return null;
  return RuntimeRegion(
    x: x,
    y: y,
    width: width.clamp(0, double.infinity).toDouble(),
    height: height.clamp(0, double.infinity).toDouble(),
  );
}
