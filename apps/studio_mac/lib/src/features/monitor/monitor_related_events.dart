part of '../../studio_mac_workspace.dart';

// Monitor 相关事件入口分片，负责运行事件区域的状态和装配。
// 筛选控件与单行展示已拆出，避免详情面板继续变大。

// 相关事件面板，读取当前 Run Detail 的本地事件流。
class _RunRelatedEventsPanel extends StatefulWidget {
  const _RunRelatedEventsPanel({required this.events});

  final List<RunEvidenceEvent> events;

  // 创建事件筛选状态，默认展示全部本地事件。
  @override
  State<_RunRelatedEventsPanel> createState() => _RunRelatedEventsPanelState();
}

// 相关事件面板状态，只保存当前 UI 筛选项。
class _RunRelatedEventsPanelState extends State<_RunRelatedEventsPanel> {
  _RunEventFilter _filter = _RunEventFilter.all;

  // 渲染相关事件列表，筛选只影响当前 UI 展示。
  @override
  Widget build(BuildContext context) {
    final visibleEvents = _filterRunEvents(widget.events, _filter);
    return _InsetSurface(
      key: const ValueKey('run-related-events'),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _RunRelatedEventsHeader(),
          const SizedBox(height: 10),
          _RunEventFilterBar(
            selected: _filter,
            events: widget.events,
            onSelected: (filter) => setState(() => _filter = filter),
          ),
          const SizedBox(height: 10),
          if (visibleEvents.isEmpty)
            const _RunDetailEmptyState(message: '无匹配事件')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleEvents.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: StudioColors.border),
              itemBuilder: (context, index) =>
                  _RunRelatedEventRow(event: visibleEvents[index]),
            ),
        ],
      ),
    );
  }
}

// 相关事件标题，保持抽屉内模块标题样式一致。
class _RunRelatedEventsHeader extends StatelessWidget {
  const _RunRelatedEventsHeader();

  // 渲染标题行，避免入口面板重复堆叠标题布局细节。
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.receipt_long_outlined, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '相关事件',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}
