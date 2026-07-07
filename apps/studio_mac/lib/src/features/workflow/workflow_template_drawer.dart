part of '../../studio_mac_workspace.dart';

// Workflow 模板抽屉，负责展示本地模板并把导入动作交回页面。
class _WorkflowTemplateDrawer extends StatelessWidget {
  const _WorkflowTemplateDrawer({
    required this.templates,
    required this.onImport,
  });

  final List<_WorkflowTemplate> templates;
  final ValueChanged<_WorkflowTemplate> onImport;

  /// 构建右侧模板抽屉。
  /// 列表中的导入动作只回传模板对象，不直接写 DSL。
  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudioColors.panel,
      child: SizedBox(
        width: 420,
        height: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '流程模板',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '导入本机流程模板，模板不会直接操作设备。',
                  style: TextStyle(color: StudioColors.muted, height: 1.4),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    key: const ValueKey('workflow-template-list'),
                    itemCount: templates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final template = templates[index];
                      return _WorkflowTemplateCard(
                        template: template,
                        onImport: () {
                          Navigator.of(context).pop();
                          onImport(template);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
