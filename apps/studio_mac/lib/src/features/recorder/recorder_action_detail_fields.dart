part of '../../studio_mac_workspace.dart';

// 录制动作详情字段区，负责展示和编辑动作核心参数。
class _RecorderActionDetailFields extends StatelessWidget {
  const _RecorderActionDetailFields({
    required this.action,
    required this.labelController,
    required this.targetController,
    required this.waitController,
    required this.durationController,
    required this.xController,
    required this.yController,
    required this.toXController,
    required this.toYController,
    required this.textController,
    required this.coordinateSummary,
    required this.timingSummary,
  });

  final _RecordedActions action;
  final TextEditingController labelController;
  final TextEditingController targetController;
  final TextEditingController waitController;
  final TextEditingController durationController;
  final TextEditingController xController;
  final TextEditingController yController;
  final TextEditingController toXController;
  final TextEditingController toYController;
  final TextEditingController textController;
  final String coordinateSummary;
  final String timingSummary;

  // 渲染详情字段，坐标和输入明文只在抽屉里延后展示。
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DrawerField(label: '摘要', value: action.detailSummary),
          _DrawerEditField(
            key: const ValueKey('recorder-action-label'),
            label: '名称',
            controller: labelController,
          ),
          _DrawerEditField(
            key: const ValueKey('recorder-action-target'),
            label: '目标',
            controller: targetController,
          ),
          _DrawerEditField(
            key: const ValueKey('recorder-action-wait'),
            label: '等待',
            controller: waitController,
            keyboardType: TextInputType.number,
          ),
          if (action.type == _RecordedActionsType.tap ||
              action.type == _RecordedActionsType.swipe)
            _DrawerEditField(
              key: const ValueKey('recorder-action-duration'),
              label: '时长',
              controller: durationController,
              keyboardType: TextInputType.number,
            ),
          if (action.type == _RecordedActionsType.input)
            _DrawerEditField(
              key: const ValueKey('recorder-action-text'),
              label: '文本',
              controller: textController,
            ),
          if (action.type == _RecordedActionsType.swipe &&
              action.hasSwipePath) ...[
            _DrawerEditField(
              key: const ValueKey('recorder-action-x'),
              label: '起横',
              controller: xController,
              keyboardType: TextInputType.number,
            ),
            _DrawerEditField(
              key: const ValueKey('recorder-action-y'),
              label: '起纵',
              controller: yController,
              keyboardType: TextInputType.number,
            ),
            _DrawerEditField(
              key: const ValueKey('recorder-action-to-x'),
              label: '终横',
              controller: toXController,
              keyboardType: TextInputType.number,
            ),
            _DrawerEditField(
              key: const ValueKey('recorder-action-to-y'),
              label: '终纵',
              controller: toYController,
              keyboardType: TextInputType.number,
            ),
          ] else if (action.x != null && action.y != null) ...[
            _DrawerEditField(
              key: const ValueKey('recorder-action-x'),
              label: '横向',
              controller: xController,
              keyboardType: TextInputType.number,
            ),
            _DrawerEditField(
              key: const ValueKey('recorder-action-y'),
              label: '纵向',
              controller: yController,
              keyboardType: TextInputType.number,
            ),
          ],
          _DrawerField(label: '坐标', value: coordinateSummary),
          _DrawerField(label: '时间', value: timingSummary),
          _DrawerField(label: '元素', value: action.elementSummary),
          _DrawerField(label: '重试', value: action.retryPolicy),
          _DrawerField(label: '证据', value: action.evidenceSummary),
          const SizedBox(height: 12),
          _RecorderEvidencePreview(action: action),
        ],
      ),
    );
  }
}
