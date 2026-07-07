part of '../../studio_mac_workspace.dart';

// 设备就绪面板，负责展示本机、会话和流程的可操作检查项。
class _DeviceReadinessPanel extends StatelessWidget {
  const _DeviceReadinessPanel({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  /// 渲染就绪检查清单和环境检查清单。
  /// 检查项来自共享 helper，面板只负责排序和展示。
  @override
  Widget build(BuildContext context) {
    final entries = _deviceReadinessEntries(snapshot);
    final dependencyEntries = _dependencyReadinessEntries(
      snapshot.dependencyReport,
    );
    final readyCount = entries
        .where((entry) => entry.tone == StudioStatusTone.ready)
        .length;
    final overallTone =
        entries.any((entry) => entry.tone == StudioStatusTone.error)
        ? StudioStatusTone.error
        : entries.any((entry) => entry.tone == StudioStatusTone.warning)
        ? StudioStatusTone.warning
        : readyCount == entries.length
        ? StudioStatusTone.ready
        : StudioStatusTone.offline;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '就绪检查',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: '$readyCount/${entries.length} 就绪',
                tone: overallTone,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '本机驱动、手机会话和信任检查。细节见控制台。',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: StudioColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (final entry in entries) ...[
            _ReadinessGuideCard(entry: entry),
            if (entry != entries.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '环境检查',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                _dependencyCheckedAt(snapshot.dependencyReport),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: StudioColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final entry in dependencyEntries) ...[
            _ReadinessGuideCard(entry: entry),
            if (entry != dependencyEntries.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
