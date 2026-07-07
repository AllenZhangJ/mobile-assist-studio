part of '../../studio_mac_workspace.dart';

// 录制页入口，负责录制状态、动作列表和详情抽屉协调。
class _RecorderPage extends StatefulWidget {
  const _RecorderPage({
    required this.snapshot,
    required this.controller,
    required this.onNavigate,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final ValueChanged<int> onNavigate;

  // 创建录制页状态，集中管理当前录制动作。
  @override
  State<_RecorderPage> createState() => _RecorderPageState();
}

// 录制页状态，协调控制区、设备预览、会话摘要和时间线。
class _RecorderPageState extends State<_RecorderPage> {
  bool _recording = false;
  bool _workflowGenerated = false;
  final List<_RecordedActions> _actions = <_RecordedActions>[];
  int _nextActionsId = 1;
  int _previewDecodeGeneration = 0;
  Size? _previewScreenshotSize;

  // 初始化时解析已有预览截图尺寸，供录制坐标换算使用。
  @override
  void initState() {
    super.initState();
    _decodePreviewScreenshotSize();
  }

  // 截图变化时重新解析尺寸，避免录制沿用旧机型坐标。
  @override
  void didUpdateWidget(_RecorderPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.latestScreenshotBase64 !=
        widget.snapshot.latestScreenshotBase64) {
      _decodePreviewScreenshotSize();
    }
  }

  // 渲染录制工作台，并按宽度切换单列或三栏布局。
  @override
  Widget build(BuildContext context) {
    final canCapture =
        widget.snapshot.connectionStatus == ConnectionStatus.connected &&
        widget.snapshot.runStatus == RunStatus.idle;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controls = _RecorderControls(
            recording: _recording,
            actionCount: _actions.length,
            onStart: _startRecording,
            onStop: _stopRecording,
            onAddTap: _recording ? _addTap : null,
            onAddWait: _recording ? _addWait : null,
            onAddSwipe: _recording ? _addSwipe : null,
            onAddInput: _recording ? _addInput : null,
            onClear: _actions.isEmpty ? null : _clearActions,
            onPromote:
                _actions.isNotEmpty &&
                    widget.snapshot.runStatus == RunStatus.idle
                ? _promoteToWorkflow
                : null,
            workflowGenerated: _workflowGenerated,
            onOpenWorkflow: _openGeneratedWorkflow,
            onOpenExecute: _openGeneratedExecute,
          );
          final capture = _RecorderDeviceStage(
            snapshot: widget.snapshot,
            screenshotSize: _previewScreenshotSize,
            canCapture: canCapture,
            recording: _recording,
            onPickTap: _recording ? _addTapFromPreview : null,
            onPickSwipe: _recording ? _addSwipeFromPreview : null,
            onCapture: () =>
                widget.controller.captureScreenshot(reason: 'recorder-preview'),
          );
          final summary = _RecorderSessionPanel(
            snapshot: widget.snapshot,
            controller: widget.controller,
            recording: _recording,
            actionCount: _actions.length,
          );
          final timeline = _RecorderTimeline(
            recording: _recording,
            actions: _actions,
            onOpenActions: (action) => _openActionsDrawer(action),
            onMoveActionsUp: _moveActionsUp,
            onMoveActionsDown: _moveActionsDown,
            onDuplicateActions: _duplicateActions,
            onDeleteActions: _deleteActions,
            onCopySummary: _actions.isEmpty ? null : _copyActionsSummary,
          );

          if (constraints.maxWidth < 1120) {
            return ListView(
              children: [
                controls,
                const SizedBox(height: 14),
                SizedBox(height: 420, child: capture),
                const SizedBox(height: 14),
                summary,
                const SizedBox(height: 14),
                SizedBox(height: 360, child: timeline),
              ],
            );
          }

          return Column(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 318, child: controls),
                    const SizedBox(width: 14),
                    Expanded(child: capture),
                    const SizedBox(width: 14),
                    SizedBox(width: 318, child: summary),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(flex: 3, child: timeline),
            ],
          );
        },
      ),
    );
  }

  // 更新录制状态，供动作分片统一收口 State 写入。
  void _setRecording(bool value) {
    setState(() => _recording = value);
  }

  // 更新流程生成状态，保持导航入口只在成功生成后开启。
  void _setWorkflowGenerated(bool value) {
    setState(() => _workflowGenerated = value);
  }

  // 统一处理动作列表变更，并让已生成流程入口回到不可用态。
  void _mutateActions(VoidCallback mutation) {
    setState(() {
      mutation();
      _workflowGenerated = false;
    });
  }

  // 异步解析当前截图尺寸，并用 generation 防止旧结果覆盖新截图。
  Future<void> _decodePreviewScreenshotSize() async {
    final generation = ++_previewDecodeGeneration;
    final screenshot = _decodeScreenshot(
      widget.snapshot.latestScreenshotBase64,
    );
    if (screenshot == null) {
      if (mounted) setState(() => _previewScreenshotSize = null);
      return;
    }
    final pngSize = _pngImageSizeFromBytes(screenshot);
    if (pngSize != null) {
      if (mounted) setState(() => _previewScreenshotSize = pngSize);
      return;
    }
    final size = await _imageSizeFromBytes(screenshot);
    if (!mounted || generation != _previewDecodeGeneration) return;
    setState(() => _previewScreenshotSize = size);
  }
}
