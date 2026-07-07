part of '../studio_mac_workspace.dart';

// 控制台事件列表，负责展示日志和错误事件。
class _ConsoleEventList extends StatelessWidget {
  const _ConsoleEventList({required this.events});

  final List<RuntimeEvent> events;

  // 渲染事件列表，空列表时显示短空态。
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const _ConsoleEmptyState();
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      itemCount: events.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 12, color: StudioColors.border),
      itemBuilder: (context, index) => _ConsoleEventRow(event: events[index]),
    );
  }
}

// 控制台事件行，展示时间、级别和脱敏消息。
class _ConsoleEventRow extends StatelessWidget {
  const _ConsoleEventRow({required this.event});

  final RuntimeEvent event;

  // 渲染单条事件内容。
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            _timeOnly(event.at),
            style: const TextStyle(
              color: StudioColors.muted,
              fontFamily: 'Menlo',
              fontSize: 12,
            ),
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            _runtimeLevelLabel(event.level),
            style: TextStyle(
              color: _eventColor(event.level),
              fontFamily: 'Menlo',
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            _safeRuntimeEventMessage(event.message),
            style: const TextStyle(
              color: StudioColors.text,
              fontFamily: 'Menlo',
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

// 控制台检查视图，展示当前 Runtime 快照摘要。
class _ConsoleInspector extends StatelessWidget {
  const _ConsoleInspector({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染检查键值区，避免暴露完整设备或会话信息。
  @override
  Widget build(BuildContext context) {
    final diagnostic = snapshot.lastConnectionDiagnostic;
    return _ConsoleKeyValueList(
      values: <String, String>{
        '设备': _deviceStatusLabel(snapshot.connectionStatus),
        '驱动': _appiumStatusLabel(snapshot.appiumStatus),
        '运行': _runStatusLabel(snapshot.runStatus),
        '流程': snapshot.workflow.name,
        '会话': snapshot.sessionId == null
            ? '无'
            : _shortSession(snapshot.sessionId!),
        '截图': snapshot.latestScreenshotAt == null
            ? '无'
            : _timeOnly(snapshot.latestScreenshotAt!),
        if (diagnostic != null)
          '连接诊断': '${diagnostic.summary} ${diagnostic.nextStep}',
      },
    );
  }
}

// 控制台调试视图，展示本地工作站安全摘要。
class _ConsoleDebug extends StatelessWidget {
  const _ConsoleDebug({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染调试键值区，Workflow 有效性使用项目级校验。
  @override
  Widget build(BuildContext context) {
    final workflowValidation = _snapshotWorkflowValidation(snapshot);
    final diagnostic = snapshot.lastConnectionDiagnostic;
    return _ConsoleKeyValueList(
      values: <String, String>{
        '运行时': '桌面应用',
        '驱动': '本机驱动 / 手机会话',
        '流程有效': workflowValidation.isValid ? '是' : '否',
        '流程节点': '${snapshot.workflow.nodes.length}',
        '最近记录': '${snapshot.runHistory.recentRuns.length}',
        '驱动消息': _safeRuntimeEventMessage(snapshot.appiumMessage),
        if (diagnostic != null)
          '连接诊断': '${diagnostic.summary} ${diagnostic.nextStep}',
      },
    );
  }
}

// 控制台网络视图，展示本机驱动通道的只读摘要。
class _ConsoleNetwork extends StatelessWidget {
  const _ConsoleNetwork({required this.snapshot});

  final StudioRuntimeSnapshot snapshot;

  // 渲染脱敏通道信息，不展示 endpoint、source XML 或底层 payload。
  @override
  Widget build(BuildContext context) {
    final diagnostic = snapshot.lastConnectionDiagnostic;
    return _ConsoleKeyValueList(
      values: <String, String>{
        '通道': '应用 -> 本机驱动 -> 手机',
        '协议': '本机驱动',
        '驱动': _appiumStatusLabel(snapshot.appiumStatus),
        '手机': _deviceStatusLabel(snapshot.connectionStatus),
        '会话': snapshot.sessionId == null
            ? '无'
            : _shortSession(snapshot.sessionId!),
        '消息': _safeRuntimeEventMessage(snapshot.appiumMessage),
        if (diagnostic != null)
          '连接诊断': '${diagnostic.summary} ${diagnostic.nextStep}',
      },
    );
  }
}

// 控制台键值列表，供检查和调试视图复用。
class _ConsoleKeyValueList extends StatelessWidget {
  const _ConsoleKeyValueList({required this.values});

  final Map<String, String> values;

  // 渲染键值列表，长值保持可选择文本。
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      children: [
        for (final entry in values.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 132,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      color: StudioColors.muted,
                      fontFamily: 'Menlo',
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    entry.value,
                    style: const TextStyle(
                      color: StudioColors.text,
                      fontFamily: 'Menlo',
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// 控制台空态视图，使用短文案保持底栏轻量。
class _ConsoleEmptyState extends StatelessWidget {
  const _ConsoleEmptyState();

  // 渲染控制台空态。
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('暂无控制台事件', style: TextStyle(color: StudioColors.muted)),
    );
  }
}
