part of '../../studio_mac_workspace.dart';

// Recorder 无法解析截图时使用的安全兜底尺寸。
// 正常录制会优先使用当前截图像素尺寸，避免不同机型坐标漂移。
const Size _recorderFallbackViewportSize = Size(390, 844);

// Recorder 捕获动作，负责把按钮或预览比例坐标转换为本地录制动作。
extension _RecorderCaptureActions on _RecorderPageState {
  // 添加一个示例点击动作，便于无预览时快速录制。
  void _addTap() {
    _mutateActions(() {
      _actions.add(
        _RecordedActions.tap(
          id: _nextId(),
          label: '点登录',
          target: '登录按钮',
          x: 92,
          y: 499,
          waitAfterMs: 50,
          evidence: _currentPreviewEvidence(),
        ),
      );
    });
  }

  // 从设备预览比例坐标生成点击动作。
  void _addTapFromPreview(Offset ratio) {
    final point = _previewPointFromRatio(ratio);
    _mutateActions(() {
      _actions.add(
        _RecordedActions.tap(
          id: _nextId(),
          label: '点画面',
          target: '屏幕位置',
          x: point.dx.round(),
          y: point.dy.round(),
          waitAfterMs: 50,
          evidence: _currentPreviewEvidence(),
        ),
      );
    });
  }

  // 从设备预览拖动比例生成滑动动作，不直接执行设备手势。
  void _addSwipeFromPreview(Offset fromRatio, Offset toRatio) {
    final from = _previewPointFromRatio(fromRatio);
    final to = _previewPointFromRatio(toRatio);
    _mutateActions(() {
      final action = _RecordedActions.swipe(
        id: _nextId(),
        label: '滑画面',
        target: '屏幕滑动',
        fromX: from.dx.round(),
        fromY: from.dy.round(),
        toX: to.dx.round(),
        toY: to.dy.round(),
        durationMs: 420,
        evidence: _currentPreviewEvidence(),
      );
      _actions.add(action.copyWith(label: action.swipeDirectionLabel));
    });
  }

  // 添加显式等待动作，表达用户想停顿的时间。
  void _addWait() {
    _mutateActions(() {
      _actions.add(
        _RecordedActions.wait(
          id: _nextId(),
          label: '等 500ms',
          waitMs: 500,
          evidence: _currentPreviewEvidence(),
        ),
      );
    });
  }

  // 添加快捷滑动动作，无法从预览拖动时回退为安全上滑。
  void _addSwipe() {
    _mutateActions(() {
      _actions.add(
        _RecordedActions.swipe(
          id: _nextId(),
          label: '上滑',
          target: '设备屏幕',
          durationMs: 420,
          evidence: _currentPreviewEvidence(),
        ),
      );
    });
  }

  // 添加输入动作，只记录要输入的文本，不在主时间线展示明文。
  void _addInput() {
    _mutateActions(() {
      _actions.add(
        _RecordedActions.input(
          id: _nextId(),
          label: '输入文本',
          target: '当前焦点',
          text: '示例文本',
          waitAfterMs: 50,
          evidence: _currentPreviewEvidence(),
        ),
      );
    });
  }

  // 读取当前预览截图作为动作的内存证据绑定。
  _RecordedEvidenceBinding _currentPreviewEvidence() {
    return _RecordedEvidenceBinding(
      imageBase64: widget.snapshot.latestScreenshotBase64,
      capturedAt: widget.snapshot.latestScreenshotAt,
    );
  }

  // 生成稳定的本地动作 ID，避免 UI 列表和 DSL 转换漂移。
  String _nextId() {
    final id = 'recorded_${_nextActionsId.toString().padLeft(3, '0')}';
    _nextActionsId += 1;
    return id;
  }

  // 将预览比例坐标转换为当前 Recorder 使用的屏幕坐标。
  Offset _previewPointFromRatio(Offset ratio) {
    final coordinateSize = _recorderCoordinateSize;
    return Offset(
      (ratio.dx * coordinateSize.width).clamp(0, coordinateSize.width - 1),
      (ratio.dy * coordinateSize.height).clamp(0, coordinateSize.height - 1),
    );
  }

  // 读取当前录制坐标基准，优先使用截图尺寸。
  // 截图尺寸缺失时才回退到旧竖屏基准，保证无预览快捷动作仍稳定。
  Size get _recorderCoordinateSize {
    final screenshotSize = _previewScreenshotSize;
    if (screenshotSize != null &&
        screenshotSize.width > 0 &&
        screenshotSize.height > 0) {
      return screenshotSize;
    }
    return _recorderFallbackViewportSize;
  }
}
