part of '../../studio_mac_workspace.dart';

// 当前焦点输入控件，负责把用户文字交给 Runtime 的手动输入入口。
class _PreviewInputControl extends StatelessWidget {
  const _PreviewInputControl({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.canSend,
    required this.onSubmitted,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final bool canSend;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSend;

  // 渲染固定宽度输入区，避免中文按钮和长文本撑开顶部工具栏。
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 228,
      height: 32,
      child: TextField(
        key: const ValueKey('device-preview-input-field'),
        controller: controller,
        enabled: enabled,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.send,
        style: const TextStyle(fontSize: 12, color: StudioColors.text),
        decoration: InputDecoration(
          isDense: true,
          hintText: enabled ? '输入到手机' : '输入锁定',
          hintStyle: TextStyle(
            color: StudioColors.muted.withValues(alpha: 0.72),
            fontSize: 12,
          ),
          filled: true,
          fillColor: StudioColors.background.withValues(alpha: 0.62),
          contentPadding: const EdgeInsets.fromLTRB(10, 7, 4, 7),
          suffixIconConstraints: const BoxConstraints.tightFor(
            width: 32,
            height: 32,
          ),
          suffixIcon: IconButton(
            key: const ValueKey('device-preview-input-send'),
            tooltip: sending ? '发送中' : '发送',
            padding: EdgeInsets.zero,
            iconSize: 16,
            color: StudioColors.text,
            disabledColor: StudioColors.muted.withValues(alpha: 0.45),
            onPressed: canSend ? onSend : null,
            icon: Icon(sending ? Icons.sync : Icons.send_outlined),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: StudioColors.border),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: StudioColors.border.withValues(alpha: 0.56),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: StudioColors.cyan),
          ),
        ),
      ),
    );
  }
}
