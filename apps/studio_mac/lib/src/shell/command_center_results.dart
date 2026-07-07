part of '../studio_mac_workspace.dart';

// 命令中心结果 UI 分片，承载结果行和搜索空态。

// 命令中心单条结果，展示图标、标题、说明和键盘确认提示。
class _CommandCenterResult extends StatelessWidget {
  const _CommandCenterResult({
    required this.command,
    required this.selected,
    required this.onPressed,
  });

  final _CommandCenterCommand command;
  final bool selected;
  final VoidCallback onPressed;

  /// 渲染一条可点击命令结果。
  /// 选中态只影响视觉高亮，不触发命令执行。
  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('command-center-command-${command.title}'),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? StudioColors.cyan.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? StudioColors.cyan.withValues(alpha: 0.36)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                _CommandCenterResultIcon(
                  icon: command.icon,
                  selected: selected,
                ),
                const SizedBox(width: 12),
                Expanded(child: _CommandCenterResultText(command: command)),
                const SizedBox(width: 12),
                const Icon(
                  Icons.keyboard_return,
                  color: StudioColors.muted,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 命令结果图标块，统一选中和普通状态的颜色。
class _CommandCenterResultIcon extends StatelessWidget {
  const _CommandCenterResultIcon({required this.icon, required this.selected});

  final IconData icon;
  final bool selected;

  /// 渲染命令图标容器。
  /// 颜色只表达当前选中态，不参与命令语义。
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: selected
            ? StudioColors.cyan.withValues(alpha: 0.18)
            : StudioColors.cyan.withValues(alpha: 0.10),
        border: Border.all(
          color: selected
              ? StudioColors.cyan.withValues(alpha: 0.50)
              : StudioColors.cyan.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: StudioColors.cyan),
    );
  }
}

// 命令结果文本块，保持标题和说明的紧凑展示。
class _CommandCenterResultText extends StatelessWidget {
  const _CommandCenterResultText({required this.command});

  final _CommandCenterCommand command;

  /// 渲染命令标题和说明。
  /// 两行都使用省略号，避免长中文撑开弹窗。
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          command.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          command.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: StudioColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

// 命令搜索空态，保持短文案避免占用主空间。
class _CommandCenterEmpty extends StatelessWidget {
  const _CommandCenterEmpty();

  /// 渲染命令搜索空结果。
  /// 空态只提示没有命中，不提供额外动作。
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 34),
      child: Center(
        child: Text('没有结果', style: TextStyle(color: StudioColors.muted)),
      ),
    );
  }
}
