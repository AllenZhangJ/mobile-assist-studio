part of '../../studio_mac_workspace.dart';

// Workflow 模板卡片，负责展示模板摘要、节点统计和导入按钮。
class _WorkflowTemplateCard extends StatelessWidget {
  const _WorkflowTemplateCard({required this.template, required this.onImport});

  final _WorkflowTemplate template;
  final VoidCallback onImport;

  /// 构建模板卡片。
  /// 节点统计只用于理解模板，不参与 DSL 保存。
  @override
  Widget build(BuildContext context) {
    final tapCount = template.workflow.nodes
        .where((node) => node.type == WorkflowNodeType.tap)
        .length;
    final waitCount = template.workflow.nodes
        .where((node) => node.type == WorkflowNodeType.wait)
        .length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF030609),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(template.icon, size: 18, color: StudioColors.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    template.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusPill(
                  label: template.category,
                  tone: StudioStatusTone.running,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              template.description,
              style: const TextStyle(color: StudioColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TemplateStat(
                  label: '节点',
                  value: '${template.workflow.nodes.length}',
                ),
                _TemplateStat(label: '点击', value: '$tapCount'),
                _TemplateStat(label: '等待', value: '$waitCount'),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: ValueKey('workflow-template-import-${template.id}'),
                onPressed: onImport,
                icon: const Icon(Icons.download_done_outlined, size: 18),
                label: const Text('导入模板'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 模板统计胶囊，统一模板卡片内的信息密度。
class _TemplateStat extends StatelessWidget {
  const _TemplateStat({required this.label, required this.value});

  final String label;
  final String value;

  /// 构建短统计胶囊。
  /// 文案保持紧凑，避免模板抽屉横向撑开。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.72),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          '$label $value',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
