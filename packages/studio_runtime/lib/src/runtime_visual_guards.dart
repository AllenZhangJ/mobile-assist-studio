part of '../studio_runtime.dart';

// Runtime 视觉守卫扩展，负责已知系统弹窗识别和安全上下文读取。
// 当前只做保守规则，不自动处理系统弹窗。
extension StudioRuntimeVisualGuards on StudioRuntimeController {
  // 读取脱敏后的页面结构并匹配已知系统弹窗。
  // source 读取失败时降级为普通截图判断，不中断工作流。
  Future<_KnownPopupMatch?> _knownPopupMatch(String sessionId) async {
    try {
      final source = await _deviceActions.pageSource(sessionId);
      return _knownPopupMatchFromSource(source);
    } on Object {
      return null;
    }
  }

  // 构建 Condition 表达式允许读取的安全上下文。
  // 不包含完整设备标识、本机路径、session 或 WebDriver payload。
  Map<String, Object?> _workflowContext({
    required int loopIndex,
    required int totalLoops,
    Map<String, Object?> workflowInputs = const <String, Object?>{},
  }) {
    return <String, Object?>{
      'loopIndex': loopIndex,
      'loopNumber': loopIndex + 1,
      'totalLoops': totalLoops,
      'inputs': workflowInputs,
      'hasScreenshot': _snapshot.latestScreenshotBase64 != null,
      'connectionStatus': _snapshot.connectionStatus.name,
      'runStatus': _snapshot.runStatus.name,
      'execution': <String, Object?>{
        'loopIndex': loopIndex,
        'loopNumber': loopIndex + 1,
        'totalLoops': totalLoops,
      },
    };
  }

  // 按 context.xxx 路径读取安全上下文字段。
  // 不支持任意脚本执行，也不做方法调用。
  Object? _readContextExpression(
    String expression,
    Map<String, Object?> context,
  ) {
    final parts = expression.trim().split('.');
    Object? current = context;
    for (final part in parts.skip(1)) {
      if (current is! Map<String, Object?>) return null;
      current = current[part];
    }
    return current;
  }

  // 将安全上下文字段转换为条件分支布尔值。
  // 字符串 false 和空字符串按 false 处理。
  bool _truthyContextValue(Object? value) {
    return switch (value) {
      bool() => value,
      num() => value != 0,
      String() => value.trim().isNotEmpty && value.toLowerCase() != 'false',
      _ => value != null,
    };
  }
}

// 已知弹窗命中结果，只记录规则和用户可读原因。
final class _KnownPopupMatch {
  const _KnownPopupMatch({required this.rule, required this.reason});

  final String rule;
  final String reason;
}

// 已知 iOS 系统弹窗规则，用少量关键词做保守识别。
final class _KnownPopupRule {
  const _KnownPopupRule({
    required this.id,
    required this.label,
    required this.any,
  });

  final String id;
  final String label;
  final List<String> any;
}

const _knownPopupRules = <_KnownPopupRule>[
  _KnownPopupRule(
    id: 'known_ios_developer_trust_popup',
    label: '开发者信任',
    any: ['developer app', 'not trusted', 'verify app', '开发者', '信任'],
  ),
  _KnownPopupRule(
    id: 'known_ios_notification_permission_popup',
    label: '通知权限',
    any: ['send you notifications', 'would like to send', '通知', '允许通知'],
  ),
  _KnownPopupRule(
    id: 'known_ios_location_permission_popup',
    label: '定位权限',
    any: ['use your location', 'location while', '位置', '定位'],
  ),
  _KnownPopupRule(
    id: 'known_ios_local_network_permission_popup',
    label: '本地网络权限',
    any: ['local network', '本地网络'],
  ),
  _KnownPopupRule(
    id: 'known_ios_clipboard_permission_popup',
    label: '粘贴权限',
    any: ['paste from', 'would like to paste', '粘贴'],
  ),
];

// 匹配常见 iOS 系统弹窗，只返回规则和中文原因，不保留原始 XML。
_KnownPopupMatch? _knownPopupMatchFromSource(String source) {
  final normalized = source.toLowerCase();
  for (final rule in _knownPopupRules) {
    for (final token in rule.any) {
      if (normalized.contains(token.toLowerCase())) {
        return _KnownPopupMatch(
          rule: rule.id,
          reason: '发现系统弹窗：${rule.label}。请人工处理后继续。',
        );
      }
    }
  }
  return null;
}
