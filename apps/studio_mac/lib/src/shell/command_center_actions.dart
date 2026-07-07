part of '../studio_mac_workspace.dart';

// Shell 命令中心动作分片，负责生成命令和处理安全剪贴板动作。
extension _StudioShellCommandActions on _StudioShellState {
  // 生成命令中心动作列表，动作只调用本地 Runtime、导航、抽屉或剪贴板。
  List<_CommandCenterCommand> _commandCenterCommands() {
    return [
      for (var index = 0; index < _StudioShellState._items.length; index += 1)
        _CommandCenterCommand(
          icon: _StudioShellState._items[index].icon,
          title: _StudioShellState._items[index].label,
          description: '前往${_StudioShellState._items[index].label}',
          keywords:
              '${_StudioShellState._items[index].shortLabel} '
              '${_StudioShellState._items[index].label}',
          action: () => _selectNavIndex(index),
        ),
      _CommandCenterCommand(
        icon: Icons.phone_iphone_outlined,
        title: '设备状态',
        description: '查看连接摘要',
        keywords: '手机 连接 状态',
        action: () => unawaited(
          _openStatusDetailDrawer(
            context,
            _snapshot,
            _StatusDetailFocus.device,
          ),
        ),
      ),
      _CommandCenterCommand(
        icon: Icons.settings_input_component_outlined,
        title: '驱动状态',
        description: '查看驱动摘要',
        keywords: '驱动 会话 状态',
        action: () => unawaited(
          _openStatusDetailDrawer(
            context,
            _snapshot,
            _StatusDetailFocus.driver,
          ),
        ),
      ),
      _CommandCenterCommand(
        icon: Icons.account_tree_outlined,
        title: '流程状态',
        description: '查看流程摘要',
        keywords: '流程 校验 状态',
        action: () => unawaited(
          _openStatusDetailDrawer(
            context,
            _snapshot,
            _StatusDetailFocus.workflow,
          ),
        ),
      ),
      _CommandCenterCommand(
        icon: Icons.play_circle_outline,
        title: '运行状态',
        description: '查看运行摘要',
        keywords: '运行 执行 状态',
        action: () => unawaited(
          _openStatusDetailDrawer(context, _snapshot, _StatusDetailFocus.run),
        ),
      ),
      _CommandCenterCommand(
        icon: Icons.rule_folder_outlined,
        title: '查环境',
        description: '检查本机准备',
        keywords: '本机 环境 依赖 检查',
        action: () => unawaited(_controller.refreshDependencyReport()),
      ),
      _CommandCenterCommand(
        icon: Icons.assignment_outlined,
        title: '复制诊断',
        description: '复制安全摘要',
        keywords: '诊断 摘要 复制 状态',
        action: () => unawaited(_copyDiagnosticsSummary()),
      ),
      _CommandCenterCommand(
        icon: Icons.cable_outlined,
        title: '复制隧道',
        description: '复制本机命令',
        keywords: '本机 隧道 命令 复制',
        action: () => unawaited(_copyTunnelCommand()),
      ),
      _CommandCenterCommand(
        icon: Icons.settings_outlined,
        title: '设置',
        description: '本机偏好',
        keywords: '设置 隐私 证据',
        action: _openSettingsDrawer,
      ),
    ];
  }

  // 复制本机隧道命令，只写剪贴板，不自动执行。
  Future<void> _copyTunnelCommand() async {
    await _copyCommandText(_iosTunnelCommand);
  }

  // 复制脱敏诊断摘要，便于沟通问题但不暴露设备和本机细节。
  Future<void> _copyDiagnosticsSummary() async {
    await _copyCommandText(_commandDiagnosticsSummary(_snapshot));
  }

  // 写入系统剪贴板并提示用户，统一收敛命令中心复制反馈。
  Future<void> _copyCommandText(String text) async {
    await _copyPlainText(context, text: text);
  }
}
