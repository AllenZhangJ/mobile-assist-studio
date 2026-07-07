part of '../../studio_mac_workspace.dart';

// 录制动作详情抽屉，负责延后展示并编辑坐标、时间和证据信息。
class _ActionsDetailDrawer extends StatefulWidget {
  const _ActionsDetailDrawer({required this.action});

  final _RecordedActions action;

  // 创建详情抽屉状态，持有本次编辑草稿。
  @override
  State<_ActionsDetailDrawer> createState() => _ActionsDetailDrawerState();
}

// 动作详情编辑状态，保存前不改写时间线动作。
class _ActionsDetailDrawerState extends State<_ActionsDetailDrawer> {
  late final TextEditingController _labelController;
  late final TextEditingController _targetController;
  late final TextEditingController _waitController;
  late final TextEditingController _durationController;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _toXController;
  late final TextEditingController _toYController;
  late final TextEditingController _textController;

  // 初始化编辑器，默认值来自当前录制动作。
  @override
  void initState() {
    super.initState();
    final action = widget.action;
    _labelController = TextEditingController(text: action.label);
    _targetController = TextEditingController(text: action.target);
    _waitController = TextEditingController(text: '${action.waitAfterMs}');
    _durationController = TextEditingController(text: '${action.durationMs}');
    _xController = TextEditingController(text: action.x?.toString() ?? '');
    _yController = TextEditingController(text: action.y?.toString() ?? '');
    _toXController = TextEditingController(text: action.toX?.toString() ?? '');
    _toYController = TextEditingController(text: action.toY?.toString() ?? '');
    _textController = TextEditingController(text: action.text ?? '');
  }

  // 释放文本控制器，避免抽屉关闭后保留输入资源。
  @override
  void dispose() {
    _labelController.dispose();
    _targetController.dispose();
    _waitController.dispose();
    _durationController.dispose();
    _xController.dispose();
    _yController.dispose();
    _toXController.dispose();
    _toYController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // 渲染动作详情，主时间线默认仍隐藏坐标。
  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    return Material(
      color: StudioColors.panel,
      child: SizedBox(
        width: 392,
        height: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RecorderActionDetailHeader(onSave: _save),
                const SizedBox(height: 12),
                StatusPill(
                  label: action.type.label,
                  tone: _toneForRecordedActions(action.type),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: _RecorderActionDetailFields(
                    action: action,
                    labelController: _labelController,
                    targetController: _targetController,
                    waitController: _waitController,
                    durationController: _durationController,
                    xController: _xController,
                    yController: _yController,
                    toXController: _toXController,
                    toYController: _toYController,
                    textController: _textController,
                    coordinateSummary: _draftCoordinateSummary(action),
                    timingSummary: _draftTimingSummary(action),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 保存编辑草稿，并把更新后的动作返回给 Recorder 页。
  void _save() {
    final action = widget.action;
    final waitMs = _boundedInt(
      _waitController.text,
      action.waitAfterMs,
      0,
      600000,
    );
    final durationMs =
        action.type == _RecordedActionsType.tap ||
            action.type == _RecordedActionsType.swipe
        ? _boundedInt(_durationController.text, action.durationMs, 1, 60000)
        : action.type == _RecordedActionsType.wait
        ? waitMs
        : action.durationMs;
    final updated = action.copyWith(
      label: _nonEmpty(_labelController.text, action.label),
      target: _nonEmpty(_targetController.text, action.target),
      waitAfterMs: waitMs,
      durationMs: durationMs,
      x: action.x == null
          ? null
          : _boundedInt(_xController.text, action.x!, 0, 10000),
      y: action.y == null
          ? null
          : _boundedInt(_yController.text, action.y!, 0, 10000),
      toX: action.toX == null
          ? null
          : _boundedInt(_toXController.text, action.toX!, 0, 10000),
      toY: action.toY == null
          ? null
          : _boundedInt(_toYController.text, action.toY!, 0, 10000),
      text: action.type == _RecordedActionsType.input
          ? _nonEmpty(_textController.text, action.text ?? '')
          : null,
    );
    Navigator.of(context).pop(updated);
  }

  // 根据草稿生成坐标摘要，便于保存前确认。
  String _draftCoordinateSummary(_RecordedActions action) {
    if (action.type == _RecordedActionsType.swipe && action.hasSwipePath) {
      final fromX = _boundedInt(_xController.text, action.x!, 0, 10000);
      final fromY = _boundedInt(_yController.text, action.y!, 0, 10000);
      final toX = _boundedInt(_toXController.text, action.toX!, 0, 10000);
      final toY = _boundedInt(_toYController.text, action.toY!, 0, 10000);
      return '从 $fromX，$fromY 到 $toX，$toY';
    }
    if (action.x == null || action.y == null) return '隐藏或不适用';
    final x = _boundedInt(_xController.text, action.x!, 0, 10000);
    final y = _boundedInt(_yController.text, action.y!, 0, 10000);
    return '横向 $x，纵向 $y';
  }

  // 根据草稿生成时间摘要，保持详情内的即时反馈。
  String _draftTimingSummary(_RecordedActions action) {
    final waitMs = _boundedInt(
      _waitController.text,
      action.waitAfterMs,
      0,
      600000,
    );
    if (action.type == _RecordedActionsType.wait) return '等 ${waitMs}ms';
    return switch (action.type) {
      _RecordedActionsType.tap =>
        '点击 ${_boundedInt(_durationController.text, action.durationMs, 1, 60000)}ms，等待 ${waitMs}ms',
      _RecordedActionsType.swipe =>
        '滑动 ${_boundedInt(_durationController.text, action.durationMs, 1, 60000)}ms，等待 ${waitMs}ms',
      _RecordedActionsType.input => '输入后等待 ${waitMs}ms',
      _RecordedActionsType.wait => '等 ${waitMs}ms',
    };
  }
}
