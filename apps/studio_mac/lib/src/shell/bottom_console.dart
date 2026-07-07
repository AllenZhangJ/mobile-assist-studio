part of '../studio_mac_workspace.dart';

// 全局底部控制台，负责日志、错误、检查器和调试信息的收起展开体验。
class _BottomConsole extends StatefulWidget {
  const _BottomConsole({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 创建控制台状态，保存展开、标签、筛选和清空时间。
  @override
  State<_BottomConsole> createState() => _BottomConsoleState();
}

// 底部控制台状态，负责协调外壳、标签页和复制清空动作。
class _BottomConsoleState extends State<_BottomConsole> {
  bool _expanded = false;
  _ConsoleTab _selectedTab = _ConsoleTab.log;
  _ConsoleLevelFilter _levelFilter = _ConsoleLevelFilter.all;
  DateTime? _clearedAt;

  // 返回清空时间之后且符合筛选级别的事件。
  List<RuntimeEvent> get _visibleEvents {
    final clearedAt = _clearedAt;
    return widget.snapshot.events
        .where((event) => clearedAt == null || event.at.isAfter(clearedAt))
        .where(_levelFilter.matches)
        .toList(growable: false);
  }

  // 返回当前可见事件中的错误和提醒。
  List<RuntimeEvent> get _errorEvents {
    return _visibleEvents
        .where((event) {
          final level = _runtimeLevelLabel(event.level);
          return level == '错误' || level == '提醒';
        })
        .toList(growable: false);
  }

  // 渲染底部控制台外壳，展开后显示标签和内容区。
  @override
  Widget build(BuildContext context) {
    final events = _visibleEvents;
    return Container(
      height: _expanded ? 320 : 48,
      decoration: const BoxDecoration(
        color: Color(0xF205080C),
        border: Border(top: BorderSide(color: StudioColors.border)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 47,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _expanded ? '收起控制台' : '展开控制台',
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      size: 20,
                    ),
                  ),
                  StatusPill(label: '控制台', tone: _consoleTone(events)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _consoleSummary(events),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: StudioColors.muted,
                        fontFamily: 'Menlo',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '复制',
                    onPressed: () => unawaited(_copyAll()),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: '清空',
                    onPressed: _clearAll,
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: StudioColors.border),
            SizedBox(
              height: 48,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    for (final tab in _ConsoleTab.values) ...[
                      _ConsoleTabButton(
                        tab: tab,
                        selected: _selectedTab == tab,
                        onPressed: () => setState(() => _selectedTab = tab),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    if (_selectedTab == _ConsoleTab.log ||
                        _selectedTab == _ConsoleTab.error) ...[
                      const Text(
                        '级别',
                        style: TextStyle(
                          color: StudioColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (final filter in _ConsoleLevelFilter.values) ...[
                        _ConsoleLevelFilterButton(
                          filter: filter,
                          selected: _levelFilter == filter,
                          onPressed: () =>
                              setState(() => _levelFilter = filter),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                    Text(
                      '${events.length} 个事件',
                      style: const TextStyle(
                        color: StudioColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: StudioColors.border),
            Expanded(child: _buildSelectedTab()),
          ],
        ],
      ),
    );
  }

  // 根据当前标签页选择对应内容视图。
  Widget _buildSelectedTab() {
    return switch (_selectedTab) {
      _ConsoleTab.log => _ConsoleEventList(events: _visibleEvents),
      _ConsoleTab.error => _ConsoleEventList(events: _errorEvents),
      _ConsoleTab.inspector => _ConsoleInspector(snapshot: widget.snapshot),
      _ConsoleTab.network => _ConsoleNetwork(snapshot: widget.snapshot),
      _ConsoleTab.debug => _ConsoleDebug(snapshot: widget.snapshot),
    };
  }

  // 复制当前标签页的文本内容到剪贴板。
  Future<void> _copyAll() async {
    await _copyPlainText(context, text: _selectedTabText());
  }

  // 清空当前时间之前的事件展示，不修改 Runtime 事件真源。
  void _clearAll() {
    setState(() => _clearedAt = DateTime.now());
  }

  // 生成当前标签页可复制文本。
  String _selectedTabText() {
    return switch (_selectedTab) {
      _ConsoleTab.log => _eventsText(_visibleEvents),
      _ConsoleTab.error => _eventsText(_errorEvents),
      _ConsoleTab.inspector => _inspectorText(widget.snapshot),
      _ConsoleTab.network => _networkText(widget.snapshot),
      _ConsoleTab.debug => _debugText(widget.snapshot),
    };
  }
}
