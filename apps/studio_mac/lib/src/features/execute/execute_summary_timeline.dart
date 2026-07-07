part of '../../studio_mac_workspace.dart';

// Execute 事件线分片，负责页面内最近事件摘要。
// 完整日志、错误和调试信息继续归全局底部控制台承载。

// 运行事件时间线，主界面只保留最近几条高信号事件。
class _ExecuteTimelinePanel extends StatelessWidget {
  const _ExecuteTimelinePanel({required this.events});

  final List<RuntimeEvent> events;

  // 渲染最近 Runtime 事件摘要，完整诊断仍留给底部控制台。
  @override
  Widget build(BuildContext context) {
    final recentEvents = events.reversed.take(5).toList(growable: false);
    return _InsetSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '运行线',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: '${recentEvents.length}/5',
                tone: recentEvents.isEmpty
                    ? StudioStatusTone.offline
                    : _eventTone(recentEvents.first.level),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: recentEvents.isEmpty
                ? const Center(
                    child: Text(
                      '暂无运行事件',
                      style: TextStyle(color: StudioColors.muted),
                    ),
                  )
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentEvents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ExecuteTimelineRow(event: recentEvents[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

// 单条运行事件行，做脱敏摘要和时间显示。
class _ExecuteTimelineRow extends StatelessWidget {
  const _ExecuteTimelineRow({required this.event});

  final RuntimeEvent event;

  // 渲染单条运行事件，主界面只展示短摘要。
  @override
  Widget build(BuildContext context) {
    final tone = _eventTone(event.level);
    final color = _colorForTone(tone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 54,
          child: Text(
            _timeOnly(event.at),
            style: const TextStyle(
              color: StudioColors.muted,
              fontFamily: 'Menlo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _safeRuntimeEventMessage(event.message),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, height: 1.25),
          ),
        ),
      ],
    );
  }
}
