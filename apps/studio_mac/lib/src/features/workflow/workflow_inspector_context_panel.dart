part of '../../studio_mac_workspace.dart';

// Workflow Inspector 上下文变量面板，只展示可读字段和安全复制入口。
class _WorkflowContextPanel extends StatelessWidget {
  const _WorkflowContextPanel({
    required this.connectionStatus,
    required this.runStatus,
    required this.latestScreenshotAt,
    required this.executionFocus,
  });

  final ConnectionStatus connectionStatus;
  final RunStatus runStatus;
  final DateTime? latestScreenshotAt;
  final RuntimeExecutionFocus executionFocus;

  // 渲染安全上下文字段列表，供条件表达式复制使用。
  @override
  Widget build(BuildContext context) {
    final variables = _workflowContextVariables(
      connectionStatus: connectionStatus,
      runStatus: runStatus,
      latestScreenshotAt: latestScreenshotAt,
      executionFocus: executionFocus,
    );
    return DecoratedBox(
      key: const ValueKey('workflow-context-panel'),
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WorkflowContextPanelHeader(variables: variables),
            const SizedBox(height: 8),
            const Text(
              '条件可读取的字段，均来自本机运行时。',
              style: TextStyle(
                color: StudioColors.muted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            for (final variable in variables) ...[
              _WorkflowContextVariableRow(variable: variable),
              if (variable != variables.last)
                const Divider(color: StudioColors.border, height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

// 上下文变量面板头部，承载短标题和复制全部入口。
class _WorkflowContextPanelHeader extends StatelessWidget {
  const _WorkflowContextPanelHeader({required this.variables});

  final List<_WorkflowContextVariable> variables;

  // 渲染面板标题和整体摘要复制按钮，复制内容由模型层生成。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.data_object_outlined, size: 16),
        const Text(
          '上下文',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        StatusPill(label: '只读', tone: StudioStatusTone.offline),
        TextButton.icon(
          key: const ValueKey('workflow-context-copy-all'),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => unawaited(
            _copyPlainText(
              context,
              text: _workflowContextVariablesSummary(variables),
            ),
          ),
          icon: const Icon(Icons.copy_all_outlined, size: 14),
          label: const Text(
            '复制全部',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

// 单行上下文字段展示，负责表达式、说明和当前预览值。
class _WorkflowContextVariableRow extends StatelessWidget {
  const _WorkflowContextVariableRow({required this.variable});

  final _WorkflowContextVariable variable;

  // 渲染单个上下文字段，并提供复制表达式入口。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                variable.expression,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudioColors.cyan,
                  fontFamily: 'Menlo',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox.square(
              dimension: 28,
              child: IconButton(
                key: ValueKey('workflow-context-copy-${variable.key}'),
                tooltip: '复制 ${variable.expression}',
                padding: EdgeInsets.zero,
                iconSize: 14,
                onPressed: () => unawaited(
                  _copyPlainText(context, text: variable.expression),
                ),
                icon: const Icon(Icons.copy_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          variable.description,
          style: const TextStyle(
            color: StudioColors.muted,
            fontSize: 11,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            variable.previewValue,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}
