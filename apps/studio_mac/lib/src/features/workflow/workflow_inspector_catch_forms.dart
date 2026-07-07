part of '../../studio_mac_workspace.dart';

// Inspector Catch 节点表单，集中处理重试次数、错误分支候选和显示文案。

// Catch 参数字段，集中处理重试次数和错误分支。
class _CatchParameterFields extends StatelessWidget {
  const _CatchParameterFields({
    required this.enabled,
    required this.workflow,
    required this.node,
    required this.maxRetriesController,
    required this.onErrorController,
  });

  final bool enabled;
  final WorkflowDefinition workflow;
  final WorkflowNode node;
  final TextEditingController maxRetriesController;
  final TextEditingController onErrorController;

  /// 渲染 Catch 节点参数。
  /// 错误分支用节点选择器设置，避免用户手写节点 ID。
  @override
  Widget build(BuildContext context) {
    final candidates = _catchOnErrorCandidates(workflow, node);
    final selected = _catchOnErrorSelectedNode(
      candidates,
      onErrorController.text,
    );
    final currentOnError = onErrorController.text.trim();
    final hasMissingTarget =
        currentOnError.isNotEmpty &&
        !workflow.nodes.any((target) => target.id == currentOnError);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('node-inspector-max-retries'),
          controller: maxRetriesController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: _inspectorInputDecoration('最大重试'),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          key: const ValueKey('node-inspector-on-error'),
          behavior: HitTestBehavior.opaque,
          onTap: enabled
              ? () => unawaited(
                  _showCatchOnErrorMenu(
                    context,
                    candidates: candidates,
                    onErrorController: onErrorController,
                  ),
                )
              : null,
          child: InputDecorator(
            decoration: _inspectorInputDecoration('错误分支'),
            isEmpty: currentOnError.isEmpty,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _catchOnErrorDisplayLabel(
                      selected: selected,
                      rawValue: currentOnError,
                    ),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? StudioColors.text : StudioColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: enabled ? StudioColors.muted : StudioColors.border,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          candidates.isEmpty ? '暂无可选节点。' : '超过重试后转到这里。',
          style: const TextStyle(color: StudioColors.muted, fontSize: 12),
        ),
        if (hasMissingTarget) ...[
          const SizedBox(height: 8),
          const Text(
            '当前错误分支不存在。',
            style: TextStyle(color: StudioColors.red, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// 生成 Catch 错误分支候选节点。
/// 候选排除自身，避免用户误选原地循环。
List<WorkflowNode> _catchOnErrorCandidates(
  WorkflowDefinition workflow,
  WorkflowNode node,
) {
  return workflow.nodes
      .where((target) => target.id != node.id)
      .toList(growable: false);
}

/// 将控制器中的目标 ID 转为候选节点。
/// 无效目标由 UI 显示提醒，不在这里静默改写。
WorkflowNode? _catchOnErrorSelectedNode(
  List<WorkflowNode> candidates,
  String rawValue,
) {
  final value = rawValue.trim();
  if (value.isEmpty) return null;
  for (final node in candidates) {
    if (node.id == value) return node;
  }
  return null;
}

/// 生成用户可读的错误分支选项。
/// 展示节点名和短中文类型，不要求用户理解底层枚举。
String _catchOnErrorTargetLabel(WorkflowNode node) {
  return '${node.label} · ${_nodePaletteLabel(node.type)}';
}

/// 展示错误分支菜单。
/// 选择结果只写入 Inspector 草稿控制器，保存仍走 Runtime validator。
Future<void> _showCatchOnErrorMenu(
  BuildContext context, {
  required List<WorkflowNode> candidates,
  required TextEditingController onErrorController,
}) async {
  final button = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (button == null || overlay == null) return;
  final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = button.localToGlobal(
    button.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(topLeft, bottomRight),
      Offset.zero & overlay.size,
    ),
    items: [
      const PopupMenuItem<String>(
        key: ValueKey('node-inspector-on-error-option-none'),
        value: '',
        child: Text('不设置'),
      ),
      for (final target in candidates)
        PopupMenuItem<String>(
          key: ValueKey('node-inspector-on-error-option-${target.id}'),
          value: target.id,
          child: Text(
            _catchOnErrorTargetLabel(target),
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
  );
  if (selected == null) return;
  onErrorController.text = selected;
}

/// 生成当前错误分支显示文案。
/// 缺失目标时保留可理解提示，不展示裸节点 ID。
String _catchOnErrorDisplayLabel({
  required WorkflowNode? selected,
  required String rawValue,
}) {
  if (selected != null) return _catchOnErrorTargetLabel(selected);
  if (rawValue.isEmpty) return '不设置';
  return '未找到目标';
}
