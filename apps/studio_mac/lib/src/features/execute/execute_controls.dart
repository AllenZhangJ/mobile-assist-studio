part of '../../studio_mac_workspace.dart';

// 有限循环步进器，服务执行配置，不参与运行状态推断。
class _LoopStepper extends StatelessWidget {
  const _LoopStepper({
    required this.loops,
    required this.enabled,
    required this.onChanged,
  });

  final int loops;
  final bool enabled;
  final ValueChanged<int> onChanged;

  // 渲染有限循环步进器，避免用户输入不可控轮数。
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: '减少轮数',
            onPressed: !enabled || loops <= 1
                ? null
                : () => onChanged(loops - 1),
            icon: const Icon(Icons.remove, size: 18),
          ),
          SizedBox(
            width: 76,
            child: Center(
              child: Text(
                '$loops 轮',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            tooltip: '增加轮数',
            onPressed: !enabled || loops >= 999
                ? null
                : () => onChanged(loops + 1),
            icon: const Icon(Icons.add, size: 18),
          ),
        ],
      ),
    );
  }
}
