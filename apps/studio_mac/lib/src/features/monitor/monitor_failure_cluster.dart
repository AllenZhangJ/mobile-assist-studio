part of '../../studio_mac_workspace.dart';

// 常见问题面板，负责展示 Runtime 聚合出的本地失败聚类。
class _FailureClusterPanel extends StatelessWidget {
  const _FailureClusterPanel({required this.history, required this.onShowRuns});

  final RunHistorySummary history;
  final ValueChanged<RunFailureCluster> onShowRuns;

  // 渲染本地问题聚类，空态用健康提示，不展示底层错误细节。
  @override
  Widget build(BuildContext context) {
    final clusters = history.failureClusters;
    return _Surface(
      child: SizedBox(
        height: 174,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hub_outlined, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '常见问题',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                StatusPill(
                  label: clusters.isEmpty ? '无问题' : '${clusters.length} 类',
                  tone: clusters.isEmpty
                      ? StudioStatusTone.ready
                      : StudioStatusTone.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (clusters.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    '暂无聚类',
                    style: TextStyle(color: StudioColors.muted),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: math.min(3, clusters.length),
                  separatorBuilder: (_, _) =>
                      const Divider(color: StudioColors.border, height: 12),
                  itemBuilder: (context, index) {
                    return _FailureClusterRow(
                      cluster: clusters[index],
                      onShowRuns: onShowRuns,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// 单个常见问题行，负责聚类名称、影响范围和次数展示。
class _FailureClusterRow extends StatelessWidget {
  const _FailureClusterRow({required this.cluster, required this.onShowRuns});

  final RunFailureCluster cluster;
  final ValueChanged<RunFailureCluster> onShowRuns;

  // 以分类和节点组合成用户可理解的短摘要。
  @override
  Widget build(BuildContext context) {
    final category = _analysisCategoryLabel(cluster.category);
    final nodeLabel = _failureClusterNodeLabel(cluster);
    final tone = _toneForAnalysisCategory(cluster.category);
    return Row(
      key: ValueKey('failure-cluster-${cluster.category}-${cluster.nodeId}'),
      children: [
        _FailureClusterMarker(tone: tone),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$category · $nodeLabel',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                _failureClusterMeta(cluster),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudioColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _FailureClusterCount(count: cluster.count),
        const SizedBox(width: 8),
        IconButton(
          key: ValueKey(
            'failure-cluster-runs-${cluster.category}-${cluster.nodeId}',
          ),
          tooltip: '看记录',
          onPressed: cluster.count <= 0 ? null : () => onShowRuns(cluster),
          icon: const Icon(Icons.manage_search_outlined, size: 18),
        ),
      ],
    );
  }
}

// 常见问题标记点，保持聚类列表的状态可扫读。
class _FailureClusterMarker extends StatelessWidget {
  const _FailureClusterMarker({required this.tone});

  final StudioStatusTone tone;

  // 复用状态色，避免问题聚类引入新颜色语义。
  @override
  Widget build(BuildContext context) {
    final color = _colorForTone(tone);
    return Container(
      width: 10,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}

// 常见问题次数胶囊，突出高频问题。
class _FailureClusterCount extends StatelessWidget {
  const _FailureClusterCount({required this.count});

  final int count;

  // 渲染固定宽度次数，避免中文计数挤压聚类标题。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: StudioColors.background.withValues(alpha: 0.54),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count 次',
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

// 生成人可读节点名，缺失标签时回退到节点类型。
String _failureClusterNodeLabel(RunFailureCluster cluster) {
  final label = cluster.label?.trim();
  if (label != null && label.isNotEmpty) return label;
  final nodeType = cluster.nodeType;
  if (nodeType != null && nodeType.isNotEmpty) {
    return _runtimeNodeTypeLabel(nodeType);
  }
  return '未知节点';
}

// 生成聚类范围摘要，说明次数、影响流程和最近时间。
String _failureClusterMeta(RunFailureCluster cluster) {
  final parts = <String>[
    '${cluster.workflowCount} 流程',
    '${cluster.relatedRuns.isEmpty ? cluster.count : cluster.relatedRuns.length} 记录',
  ];
  final recentAt = cluster.recentAt;
  if (recentAt != null) parts.add(_timeOnly(recentAt));
  return parts.join(' · ');
}
