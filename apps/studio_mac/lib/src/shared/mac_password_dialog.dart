part of '../studio_mac_workspace.dart';

/// 弹出本机密码输入框。
/// 密码只回传给 Runtime 进程 stdin，不保存、不复制、不进入日志。
Future<String?> _requestMacPassword(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _MacPasswordDialog(),
  );
}

/// 本机密码对话框，保持短中文和固定宽度。
/// 该组件只管理输入态，不启动任何系统命令。
class _MacPasswordDialog extends StatefulWidget {
  const _MacPasswordDialog();

  @override
  State<_MacPasswordDialog> createState() => _MacPasswordDialogState();
}

class _MacPasswordDialogState extends State<_MacPasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _empty = false;

  /// 释放输入控制器，避免弹窗反复打开时泄漏。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 渲染密码输入弹窗。
  /// 宽度固定，中文不会撑开桌面布局。
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: StudioColors.panel,
      surfaceTintColor: Colors.transparent,
      title: const Text('密码'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '只用于连接，不会保存。',
              style: TextStyle(color: StudioColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('mac-password-input'),
              controller: _controller,
              autofocus: true,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: '密码',
                errorText: _empty ? '请输入密码' : null,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('mac-password-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('mac-password-submit'),
          onPressed: _submit,
          child: const Text('连接'),
        ),
      ],
    );
  }

  /// 校验非空后关闭弹窗。
  /// 不裁剪用户输入，避免修改真实密码。
  void _submit() {
    final password = _controller.text;
    if (password.isEmpty) {
      setState(() => _empty = true);
      return;
    }
    Navigator.of(context).pop(password);
  }
}
