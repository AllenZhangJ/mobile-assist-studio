part of '../../studio_mac_workspace.dart';

// 问题分类面板，展示本地运行详情聚合出的主要问题。
class _RunIssueCategoryPanel extends StatelessWidget {
  const _RunIssueCategoryPanel({
    required this.history,
    required this.onShowRuns,
  });

  final RunHistorySummary history;
  final ValueChanged<RunIssueCategoryCount> onShowRuns;

  // 渲染最多四类问题；无问题时只给出明确健康态。
  @override
  Widget build(BuildContext context) {
    final categories = history.issueCategories;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '问题分类',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (categories.isEmpty)
            const Expanded(
              child: Center(
                child: StatusPill(label: '无问题', tone: StudioStatusTone.ready),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: math.min(4, categories.length),
                separatorBuilder: (_, _) =>
                    const Divider(color: StudioColors.border, height: 12),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return _IssueCategoryRow(
                    category: category,
                    onShowRuns: onShowRuns,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// 单个问题分类行，负责类别中文化和计数展示。
class _IssueCategoryRow extends StatelessWidget {
  const _IssueCategoryRow({required this.category, required this.onShowRuns});

  final RunIssueCategoryCount category;
  final ValueChanged<RunIssueCategoryCount> onShowRuns;

  // 根据问题类别映射颜色和短中文标签。
  @override
  Widget build(BuildContext context) {
    final tone = _toneForAnalysisCategory(category.category);
    final label = _analysisCategoryLabel(category.category);
    return Row(
      children: [
        _IssueCategoryDot(tone: tone),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${category.count}',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: ValueKey('issue-category-runs-${category.category}'),
          tooltip: '看记录',
          onPressed: category.count <= 0 ? null : () => onShowRuns(category),
          icon: const Icon(Icons.manage_search_outlined, size: 16),
        ),
      ],
    );
  }
}

// 问题分类颜色点，给紧凑列表保留状态识别。
class _IssueCategoryDot extends StatelessWidget {
  const _IssueCategoryDot({required this.tone});

  final StudioStatusTone tone;

  // 按状态 tone 映射稳定颜色和轻微发光效果。
  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      StudioStatusTone.ready => StudioColors.green,
      StudioStatusTone.warning => StudioColors.amber,
      StudioStatusTone.error => StudioColors.red,
      StudioStatusTone.offline => StudioColors.muted,
      StudioStatusTone.running => StudioColors.cyan,
    };
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.34),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
