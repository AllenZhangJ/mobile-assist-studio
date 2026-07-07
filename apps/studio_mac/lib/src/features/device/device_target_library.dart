part of '../../studio_mac_workspace.dart';

// Device 目标库面板，负责把当前截图沉淀为可复用目标资产。
// 真实写入统一走 Runtime target commands，UI 不直接保存目标文件。
class _DeviceTargetLibraryPanel extends StatefulWidget {
  const _DeviceTargetLibraryPanel({
    required this.snapshot,
    required this.controller,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;

  @override
  State<_DeviceTargetLibraryPanel> createState() =>
      _DeviceTargetLibraryPanelState();
}

// 目标库面板本地状态，只记录一次保存中的 UI 锁。
// 目标库真值来自 Runtime snapshot，不在组件内复制一份。
class _DeviceTargetLibraryPanelState extends State<_DeviceTargetLibraryPanel> {
  bool _saving = false;
  String? _testingTargetId;

  // 渲染目标库摘要、创建入口和最近目标。
  // 主界面隐藏坐标细节，只展示用户能理解的目标数量和状态。
  @override
  Widget build(BuildContext context) {
    final targetLibrary = widget.snapshot.targetLibrary;
    final screenshotSize = _deviceScreenshotSize(widget.snapshot);
    final canCreate =
        !_saving &&
        screenshotSize != null &&
        widget.snapshot.runStatus == RunStatus.idle;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '目标库',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              StatusPill(
                label: '${targetLibrary.count} 个',
                tone: targetLibrary.isValid
                    ? StudioStatusTone.ready
                    : StudioStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _targetLibrarySummary(widget.snapshot, screenshotSize),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.45),
          ),
          const SizedBox(height: 12),
          _CommandButton(
            controlKey: const ValueKey('device-create-center-target'),
            label: _saving ? '保存中' : '存中心',
            icon: Icons.center_focus_strong_outlined,
            onPressed: canCreate ? () => _createCenterTarget(context) : null,
          ),
          const SizedBox(height: 12),
          _DeviceFactRow(
            label: '状态',
            value: targetLibrary.isValid
                ? '可用'
                : '${targetLibrary.issues.length} 项提醒',
          ),
          _DeviceFactRow(
            label: '来源',
            value: screenshotSize == null ? '先截图' : '当前画面',
          ),
          if (targetLibrary.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TargetLibraryIssuePreview(issue: targetLibrary.issues.first),
          ],
          if (targetLibrary.targets.isNotEmpty) ...[
            const SizedBox(height: 12),
            _TargetPreviewList(
              targets: targetLibrary.targets.take(3).toList(),
              canTest:
                  widget.snapshot.runStatus == RunStatus.idle &&
                  widget.snapshot.latestScreenshotBase64 != null,
              testingTargetId: _testingTargetId,
              onTest: _testTarget,
            ),
          ],
        ],
      ),
    );
  }

  // 将当前截图中心点保存为坐标目标。
  // 该动作只写本地目标库，不点击手机、不启动驱动。
  Future<void> _createCenterTarget(BuildContext context) async {
    final size = _deviceScreenshotSize(widget.snapshot);
    final messenger = ScaffoldMessenger.of(context);
    if (size == null) {
      messenger.showSnackBar(const SnackBar(content: Text('先截图。')));
      return;
    }
    setState(() => _saving = true);
    final label = '画面中心 ${widget.snapshot.targetLibrary.count + 1}';
    final target = await widget.controller.createCoordinateTarget(
      label: label,
      x: (size.width / 2).round(),
      y: (size.height / 2).round(),
      viewportWidth: size.width.round(),
      viewportHeight: size.height.round(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(content: Text(target == null ? '目标未存。' : '目标已存。')),
    );
  }

  // 使用当前截图测试图片目标能否命中。
  // 测试只调用 Runtime 解析目标，不会点击或刷新设备。
  Future<void> _testTarget(
    BuildContext context,
    RuntimeTargetDefinition target,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _testingTargetId = target.id);
    final result = await widget.controller.testTargetAgainstLatestScreenshot(
      target.id,
    );
    if (!mounted) return;
    setState(() => _testingTargetId = null);
    messenger.showSnackBar(
      SnackBar(content: Text(_targetTestSnackLabel(result))),
    );
  }
}

// 目标库问题预览，只展示第一条短中文问题。
class _TargetLibraryIssuePreview extends StatelessWidget {
  const _TargetLibraryIssuePreview({required this.issue});

  final TargetLibraryIssue issue;

  // 渲染目标库提醒，避免把底层 validator message 铺到主界面。
  @override
  Widget build(BuildContext context) {
    return _ToneBorderSurface(
      tone: StudioStatusTone.warning,
      child: Text(
        issue.displayMessage,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(height: 1.4),
      ),
    );
  }
}

// 最近目标列表，只展示名称和类型。
class _TargetPreviewList extends StatelessWidget {
  const _TargetPreviewList({
    required this.targets,
    required this.canTest,
    required this.testingTargetId,
    required this.onTest,
  });

  final List<RuntimeTargetDefinition> targets;
  final bool canTest;
  final String? testingTargetId;
  final Future<void> Function(
    BuildContext context,
    RuntimeTargetDefinition target,
  )
  onTest;

  // 渲染最近几个目标，坐标、选择器和图片引用等细节默认隐藏。
  @override
  Widget build(BuildContext context) {
    return _InsetSurface(
      child: Column(
        children: [
          for (final target in targets)
            Padding(
              padding: EdgeInsets.only(bottom: target == targets.last ? 0 : 10),
              child: Row(
                children: [
                  Icon(
                    _targetKindIcon(target.kind),
                    size: 18,
                    color: StudioColors.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      target.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _targetKindLabel(target.kind),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: StudioColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  if (target.kind == RuntimeTargetKind.image) ...[
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      key: ValueKey('device-test-target-${target.id}'),
                      tooltip: '试找',
                      onPressed: canTest && testingTargetId == null
                          ? () => unawaited(onTest(context, target))
                          : null,
                      icon: Icon(
                        testingTargetId == target.id
                            ? Icons.hourglass_empty_outlined
                            : Icons.center_focus_weak_outlined,
                        size: 16,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// 把目标测试结果转换成短反馈。
String _targetTestSnackLabel(TargetResolutionResult? result) {
  if (result == null) return '未测试。';
  return switch (result.status) {
    TargetResolutionStatus.matched => '已找到。',
    TargetResolutionStatus.lowConfidence => '不够准。',
    TargetResolutionStatus.notMatched => '未找到。',
    TargetResolutionStatus.unsupported => '暂不可测。',
    TargetResolutionStatus.infrastructureError => '测试失败。',
  };
}

// 从最新截图同步读取图片尺寸，作为创建坐标目标的坐标系。
Size? _deviceScreenshotSize(StudioRuntimeSnapshot snapshot) {
  final screenshot = _decodeScreenshot(snapshot.latestScreenshotBase64);
  if (screenshot == null) return null;
  return _pngImageSizeFromBytes(screenshot);
}

// 生成目标库短说明。
String _targetLibrarySummary(StudioRuntimeSnapshot snapshot, Size? size) {
  if (snapshot.runStatus != RunStatus.idle) return '运行中先不改目标。';
  if (size == null) return '先截一张图，再把画面中心存为目标。';
  if (snapshot.targetLibrary.count == 0) return '可把当前画面中心存为目标。';
  return '目标可被录制和流程复用。';
}

// 将目标类型转换为用户可读短标签。
String _targetKindLabel(RuntimeTargetKind kind) {
  return switch (kind) {
    RuntimeTargetKind.coordinate => '坐标',
    RuntimeTargetKind.selector => '元素',
    RuntimeTargetKind.image => '图片',
    RuntimeTargetKind.region => '区域',
    RuntimeTargetKind.text => '文本',
  };
}

// 将目标类型转换为轻量图标。
IconData _targetKindIcon(RuntimeTargetKind kind) {
  return switch (kind) {
    RuntimeTargetKind.coordinate => Icons.my_location_outlined,
    RuntimeTargetKind.selector => Icons.ads_click_outlined,
    RuntimeTargetKind.image => Icons.image_search_outlined,
    RuntimeTargetKind.region => Icons.crop_free_outlined,
    RuntimeTargetKind.text => Icons.text_fields,
  };
}
