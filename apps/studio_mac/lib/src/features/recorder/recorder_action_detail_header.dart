part of '../../studio_mac_workspace.dart';

// 录制动作详情头部，负责标题、保存入口和关闭入口。
class _RecorderActionDetailHeader extends StatelessWidget {
  const _RecorderActionDetailHeader({required this.onSave});

  final VoidCallback onSave;

  // 渲染详情抽屉顶部操作区，避免主抽屉重复关心按钮布局。
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '动作详情',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        FilledButton.icon(
          key: const ValueKey('recorder-action-save'),
          onPressed: onSave,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('保存'),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
