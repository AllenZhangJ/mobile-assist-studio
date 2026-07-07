part of '../studio_mac_workspace.dart';

// 状态基础组件，负责通用命令按钮和顶部状态胶囊的轻量封装。
class _CommandButton extends StatelessWidget {
  const _CommandButton({
    this.controlKey,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Key? controlKey;
  final String label;
  final IconData icon;
  final Future<void> Function()? onPressed;

  // 构建通用命令按钮，空回调时自动禁用。
  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: controlKey,
      onPressed: onPressed == null ? null : () => unawaited(onPressed!()),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _StatusFromConnection extends StatelessWidget {
  const _StatusFromConnection({required this.status});

  final ConnectionStatus status;

  // 把连接状态转换为顶部可读状态胶囊。
  @override
  Widget build(BuildContext context) {
    final presentation = _connectionStatusPresentation(status);
    return StatusPill(label: presentation.label, tone: presentation.tone);
  }
}

class _StatusFromAppium extends StatelessWidget {
  const _StatusFromAppium({required this.status});

  final AppiumProcessStatus status;

  // 把驱动状态转换为顶部可读状态胶囊。
  @override
  Widget build(BuildContext context) {
    final presentation = _appiumStatusPresentation(status);
    return StatusPill(label: presentation.label, tone: presentation.tone);
  }
}

class _StatusFromRun extends StatelessWidget {
  const _StatusFromRun({required this.status});

  final RunStatus status;

  // 把运行状态转换为顶部可读状态胶囊。
  @override
  Widget build(BuildContext context) {
    final presentation = _runStatusPresentation(status);
    return StatusPill(label: presentation.label, tone: presentation.tone);
  }
}

// 将通用状态色调映射为具体颜色，供各页面统一使用。
Color _colorForTone(StudioStatusTone tone) {
  return switch (tone) {
    StudioStatusTone.ready => StudioColors.green,
    StudioStatusTone.warning => StudioColors.amber,
    StudioStatusTone.error => StudioColors.red,
    StudioStatusTone.offline => StudioColors.muted,
    StudioStatusTone.running => StudioColors.cyan,
  };
}
