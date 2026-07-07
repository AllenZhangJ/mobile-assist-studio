part of '../studio_mac_workspace.dart';

// 复制普通文本到系统剪贴板，并在页面仍可用时给出轻提示。
Future<void> _copyPlainText(
  BuildContext context, {
  required String text,
  String message = '已复制',
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}
