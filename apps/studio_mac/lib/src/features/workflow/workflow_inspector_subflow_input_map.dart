part of '../../studio_mac_workspace.dart';

// Inspector 子流程传参分片，集中处理 inputMap 文本、快捷按钮和安全解析。

// 子流程传参字段，使用 name=context.xxx 的友好文本格式。
class _SubWorkflowInputMapField extends StatelessWidget {
  const _SubWorkflowInputMapField({
    required this.enabled,
    required this.controller,
  });

  final bool enabled;
  final TextEditingController controller;

  /// 渲染传入参数输入框和快捷按钮。
  /// 保存前仍由草稿解析和 DSL validator 兜底。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('node-inspector-input-map'),
          controller: controller,
          enabled: enabled,
          minLines: 2,
          maxLines: 4,
          decoration: _inspectorInputDecoration('传入参数'),
        ),
        const SizedBox(height: 8),
        _SubWorkflowInputMapShortcuts(enabled: enabled, controller: controller),
      ],
    );
  }
}

// 子流程传参快捷按钮，帮助用户不用手写常用 context 表达式。
class _SubWorkflowInputMapShortcuts extends StatelessWidget {
  const _SubWorkflowInputMapShortcuts({
    required this.enabled,
    required this.controller,
  });

  final bool enabled;
  final TextEditingController controller;

  /// 渲染紧凑快捷按钮。
  /// 按钮只更新草稿输入框，不直接保存 Project DSL。
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InputMapShortcutButton(
            keyName: 'loopNumber',
            label: '加轮次',
            expression: 'context.loopNumber',
            enabled: enabled,
            controller: controller,
          ),
          _InputMapShortcutButton(
            keyName: 'hasShot',
            label: '加截图',
            expression: 'context.hasScreenshot',
            enabled: enabled,
            controller: controller,
          ),
          OutlinedButton.icon(
            key: const ValueKey('node-inspector-input-map-clear'),
            onPressed: enabled && controller.text.trim().isNotEmpty
                ? () => controller.clear()
                : null,
            icon: const Icon(Icons.clear_all_outlined, size: 16),
            label: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

// 单个参数快捷按钮，负责把一个安全映射追加到 inputMap 草稿。
class _InputMapShortcutButton extends StatelessWidget {
  const _InputMapShortcutButton({
    required this.keyName,
    required this.label,
    required this.expression,
    required this.enabled,
    required this.controller,
  });

  final String keyName;
  final String label;
  final String expression;
  final bool enabled;
  final TextEditingController controller;

  /// 构建一个短按钮。
  /// 已存在同名参数时会覆盖为新的安全表达式。
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: ValueKey('node-inspector-input-map-add-$keyName'),
      onPressed: enabled
          ? () => _upsertSubWorkflowInputMapLine(
              controller,
              keyName: keyName,
              expression: expression,
            )
          : null,
      icon: const Icon(Icons.add, size: 16),
      label: Text(label),
    );
  }
}

/// 将 inputMap 参数格式化为 Inspector 可编辑文本。
/// 每行使用 name=context.xxx，避免用户编辑原始 JSON。
String _subWorkflowInputMapText(Object? inputMap) {
  if (inputMap is! Map<String, Object?> || inputMap.isEmpty) return '';
  final keys = inputMap.keys.toList()..sort();
  return keys
      .map((key) => '$key=${inputMap[key]?.toString() ?? ''}')
      .join('\n');
}

/// 解析 Inspector 的传入参数文本。
/// 只允许 context.xxx 读取，空文本会返回空 map。
({Map<String, Object?> inputMap, String? error}) _parseSubWorkflowInputMapText(
  String text,
) {
  final inputMap = <String, Object?>{};
  final lines = text.split('\n');
  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index].trim();
    if (line.isEmpty) continue;
    final separator = line.indexOf('=');
    if (separator <= 0 || separator == line.length - 1) {
      return (
        inputMap: const <String, Object?>{},
        error: '第 ${index + 1} 行格式不对。',
      );
    }
    final key = line.substring(0, separator).trim();
    final expression = line.substring(separator + 1).trim();
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(key)) {
      return (inputMap: const <String, Object?>{}, error: '参数名需用字母开头。');
    }
    if (!isSafeContextExpression(expression)) {
      return (inputMap: const <String, Object?>{}, error: '参数只能读取上下文。');
    }
    inputMap[key] = expression;
  }
  return (inputMap: inputMap, error: null);
}

/// 将快捷参数写入 inputMap 文本。
/// 输出按参数名排序，让同一配置在 Source 中更稳定。
void _upsertSubWorkflowInputMapLine(
  TextEditingController controller, {
  required String keyName,
  required String expression,
}) {
  final parsed = _parseSubWorkflowInputMapText(controller.text);
  final inputMap = Map<String, Object?>.of(parsed.inputMap);
  inputMap[keyName] = expression;
  controller.text = _subWorkflowInputMapText(inputMap);
}
