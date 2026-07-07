part of '../../studio_mac_workspace.dart';

// 设备界面检查面板，负责展示 Inspector 快照和触发 Runtime 检查。
class _DeviceInspectorPanel extends StatelessWidget {
  const _DeviceInspectorPanel({
    required this.snapshot,
    required this.controller,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;

  // 渲染 Device 内的 Inspector MVP。
  @override
  Widget build(BuildContext context) {
    final inspector = snapshot.inspectorSnapshot;
    final canInspect =
        snapshot.connectionStatus == ConnectionStatus.connected &&
        snapshot.runStatus == RunStatus.idle &&
        snapshot.mobileRuntime.resourceState != MobileResourceState.diagnosing;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '检查',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              _CommandButton(
                controlKey: const ValueKey('device-inspector-refresh'),
                label: '检查',
                icon: Icons.account_tree_outlined,
                onPressed: canInspect
                    ? () => controller.inspectCurrentScreen(reason: 'device')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _inspectorSummary(snapshot, inspector),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          if (inspector == null)
            const _InspectorEmptyState()
          else ...[
            _InspectorFacts(snapshot: snapshot, inspector: inspector),
            const SizedBox(height: 12),
            _InspectorCapabilityWrap(capabilities: inspector.capabilities),
            const SizedBox(height: 12),
            _InspectorElementTree(root: inspector.rootElement),
            const SizedBox(height: 12),
            _InspectorSourcePreview(preview: inspector.sourcePreview),
          ],
        ],
      ),
    );
  }
}

// Inspector 空态，提示用户先连接并检查。
class _InspectorEmptyState extends StatelessWidget {
  const _InspectorEmptyState();

  // 渲染空态，不展示底层 Appium 字段。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.72),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        '连接后点检查，可查看当前界面结构。',
        style: TextStyle(color: StudioColors.muted, height: 1.45),
      ),
    );
  }
}

// Inspector 基础事实，展示会话和元素数量摘要。
class _InspectorFacts extends StatelessWidget {
  const _InspectorFacts({required this.snapshot, required this.inspector});

  final StudioRuntimeSnapshot snapshot;
  final InspectorSnapshot inspector;

  // 渲染 Inspector 事实行。
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DeviceFactRow(
          label: '平台',
          value: _mobilePlatformLabel(inspector.platform),
        ),
        _DeviceFactRow(
          label: '会话',
          value: snapshot.sessionId == null
              ? '未连接'
              : _shortSession(snapshot.sessionId!),
        ),
        _DeviceFactRow(label: '元素', value: '${inspector.elementCount} 个'),
        _DeviceFactRow(label: '时间', value: _timeOnly(inspector.capturedAt)),
      ],
    );
  }
}

// Inspector 能力摘要，使用短标签降低专业感。
class _InspectorCapabilityWrap extends StatelessWidget {
  const _InspectorCapabilityWrap({required this.capabilities});

  final MobileDriverCapabilityReport capabilities;

  // 渲染能力标签。
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InspectorCapabilityPill(label: '截图', enabled: capabilities.screenshot),
        _InspectorCapabilityPill(label: '元素', enabled: capabilities.pageSource),
        _InspectorCapabilityPill(
          label: '选择',
          enabled: capabilities.selectorTarget,
        ),
        _InspectorCapabilityPill(label: '点击', enabled: capabilities.tap),
        _InspectorCapabilityPill(label: '输入', enabled: capabilities.input),
        _InspectorCapabilityPill(
          label: '视觉',
          enabled: capabilities.imageTarget,
        ),
      ],
    );
  }
}

// Inspector 单个能力标签。
class _InspectorCapabilityPill extends StatelessWidget {
  const _InspectorCapabilityPill({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  // 渲染能力状态。
  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: enabled ? label : '$label关',
      tone: enabled ? StudioStatusTone.ready : StudioStatusTone.offline,
    );
  }
}

// Inspector 元素树预览，只展示前几层，避免主界面堆太多技术细节。
class _InspectorElementTree extends StatelessWidget {
  const _InspectorElementTree({required this.root});

  final InspectorElementSummary? root;

  // 渲染元素树摘要。
  @override
  Widget build(BuildContext context) {
    if (root == null) {
      return const Text(
        '未读取到元素树。',
        style: TextStyle(color: StudioColors.muted),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('元素树', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        _InspectorElementRow(element: root!, depth: 0),
      ],
    );
  }
}

// Inspector 元素行，递归展示最多两层子节点。
class _InspectorElementRow extends StatelessWidget {
  const _InspectorElementRow({required this.element, required this.depth});

  final InspectorElementSummary element;
  final int depth;

  // 渲染单个元素和少量子元素。
  @override
  Widget build(BuildContext context) {
    final children = depth >= 2
        ? const <InspectorElementSummary>[]
        : element.children.take(4).toList(growable: false);
    return Padding(
      padding: EdgeInsets.only(left: depth * 12, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chevron_right,
                size: 14,
                color: StudioColors.muted.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _elementTitle(element),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          if (element.attributes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(
                _attributeSummary(element.attributes),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: StudioColors.muted, fontSize: 12),
              ),
            ),
          for (final child in children)
            _InspectorElementRow(element: child, depth: depth + 1),
        ],
      ),
    );
  }
}

// Inspector Source 预览，展示脱敏后的结构片段。
class _InspectorSourcePreview extends StatelessWidget {
  const _InspectorSourcePreview({required this.preview});

  final String? preview;

  // 渲染 Source 片段。
  @override
  Widget build(BuildContext context) {
    final value = preview?.trim();
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('源码', style: TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 160),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF080D12),
            border: Border.all(color: StudioColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: StudioColors.muted,
                fontFamily: 'monospace',
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// 生成 Inspector 总结文案。
String _inspectorSummary(
  StudioRuntimeSnapshot snapshot,
  InspectorSnapshot? inspector,
) {
  if (snapshot.connectionStatus != ConnectionStatus.connected) {
    return '先连接手机，再检查当前界面。';
  }
  if (snapshot.runStatus != RunStatus.idle) {
    return '运行中暂停检查，避免打断任务。';
  }
  if (snapshot.mobileRuntime.resourceState == MobileResourceState.diagnosing) {
    return '正在读取当前界面。';
  }
  if (inspector == null) {
    return '读取截图和界面结构，帮助判断当前页面。';
  }
  return inspector.sourceSummary ?? '界面结构已读取。';
}

// 生成元素行标题。
String _elementTitle(InspectorElementSummary element) {
  final label = element.label ?? element.value;
  if (label == null || label.isEmpty) return element.type;
  return '${element.type} · $label';
}

// 生成安全属性摘要。
String _attributeSummary(Map<String, String> attributes) {
  return attributes.entries
      .map((entry) => '${entry.key}:${entry.value}')
      .join('  ');
}

// 平台短中文。
String _mobilePlatformLabel(MobilePlatform platform) {
  return switch (platform) {
    MobilePlatform.ios => 'iOS',
    MobilePlatform.android => 'Android',
    MobilePlatform.unknown => '未知',
  };
}
