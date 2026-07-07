part of '../studio_mac_workspace.dart';

// 就绪指南数据，供 Device、状态详情和准备度 helper 共享。
class _ReadinessGuideEntry {
  const _ReadinessGuideEntry({
    required this.label,
    required this.status,
    required this.summary,
    required this.nextStep,
    required this.tone,
    required this.icon,
  });

  final String label;
  final String status;
  final String summary;
  final String nextStep;
  final StudioStatusTone tone;
  final IconData icon;
}

// 就绪指南卡片，统一本机准备项的短文案展示。
class _ReadinessGuideCard extends StatelessWidget {
  const _ReadinessGuideCard({required this.entry});

  final _ReadinessGuideEntry entry;

  /// 渲染一个准备项。
  /// 只显示摘要和下一步，不暴露底层路径或端点。
  @override
  Widget build(BuildContext context) {
    return _ToneBorderSurface(
      tone: entry.tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(entry.icon, size: 18, color: _colorForTone(entry.tone)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(label: entry.status, tone: entry.tone),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.arrow_forward,
                size: 14,
                color: StudioColors.muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.nextStep,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 指引内联步骤，统一详情和下一步的紧凑展示。
class _ReadinessInlineStep extends StatelessWidget {
  const _ReadinessInlineStep({required this.label, required this.value});

  final String label;
  final String value;

  /// 渲染一条紧凑说明。
  /// 左侧标签固定宽度，右侧长文自动换行。
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.62),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: StudioColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 简洁就绪行，供 Execute、Recorder 等页面复用。
class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.ready,
    required this.waiting,
  });

  final String label;
  final bool ready;
  final bool waiting;

  /// 渲染一条三态准备度。
  /// 状态只使用“就绪/等待中/等待”三种短文案。
  @override
  Widget build(BuildContext context) {
    final tone = ready
        ? StudioStatusTone.ready
        : waiting
        ? StudioStatusTone.warning
        : StudioStatusTone.offline;
    final status = ready
        ? '就绪'
        : waiting
        ? '等待中'
        : '等待';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(_iconForReadiness(tone), size: 18, color: _colorForTone(tone)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          StatusPill(label: status, tone: tone),
        ],
      ),
    );
  }
}
