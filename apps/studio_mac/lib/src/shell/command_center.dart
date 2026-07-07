part of '../studio_mac_workspace.dart';

// 命令中心动作模型，封装命令展示文案、搜索词和执行动作。
class _CommandCenterCommand {
  const _CommandCenterCommand({
    required this.icon,
    required this.title,
    required this.description,
    required this.keywords,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final String keywords;
  final VoidCallback action;

  // 判断命令是否匹配当前搜索词。
  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    final haystack = '$title $description $keywords'.toLowerCase();
    return haystack.contains(normalized);
  }
}

// 全局命令中心弹窗，负责搜索、键盘选择和命令触发。
class _CommandCenterDialog extends StatefulWidget {
  const _CommandCenterDialog({required this.commands});

  final List<_CommandCenterCommand> commands;

  // 创建命令中心状态，管理搜索和键盘焦点。
  @override
  State<_CommandCenterDialog> createState() => _CommandCenterDialogState();
}

// 命令中心状态，维护当前搜索词和选中项。
class _CommandCenterDialogState extends State<_CommandCenterDialog> {
  final _queryController = TextEditingController();
  String _query = '';
  int _selectedIndex = 0;

  // 注册弹窗内键盘处理，支持方向键、回车和 Esc。
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
  }

  // 释放键盘处理和搜索输入控制器。
  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _queryController.dispose();
    super.dispose();
  }

  // 返回当前搜索词过滤后的命令列表。
  List<_CommandCenterCommand> get _filteredCommands {
    return widget.commands
        .where((command) => command.matches(_query))
        .toList(growable: false);
  }

  // 渲染命令中心弹窗，列表结果保持紧凑可扫视。
  @override
  Widget build(BuildContext context) {
    final results = _filteredCommands;
    final selectedIndex = results.isEmpty
        ? -1
        : math.min(_selectedIndex, results.length - 1);
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('command-center-dialog'),
        width: 560,
        constraints: const BoxConstraints(maxHeight: 560),
        decoration: BoxDecoration(
          color: StudioColors.panel,
          border: Border.all(color: StudioColors.border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.42),
              blurRadius: 28,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.search, color: StudioColors.cyan, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('command-center-search'),
                      controller: _queryController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '搜索命令',
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      onChanged: (value) => setState(() {
                        _query = value;
                        _selectedIndex = 0;
                      }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '⌘K',
                    style: TextStyle(
                      color: StudioColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: StudioColors.border),
            Flexible(
              child: results.isEmpty
                  ? const _CommandCenterEmpty()
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final command = results[index];
                        return _CommandCenterResult(
                          command: command,
                          selected: index == selectedIndex,
                          onPressed: () => _execute(command),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 处理命令中心内部键盘事件。
  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return true;
    }
    final results = _filteredCommands;
    if (results.isEmpty) return false;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, results.length - 1);
      });
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, results.length - 1);
      });
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _execute(results[math.min(_selectedIndex, results.length - 1)]);
      return true;
    }
    return false;
  }

  // 关闭弹窗后异步执行命令，避免在路由关闭过程中触发状态变更。
  void _execute(_CommandCenterCommand command) {
    Navigator.of(context).pop();
    Future<void>.microtask(command.action);
  }
}
