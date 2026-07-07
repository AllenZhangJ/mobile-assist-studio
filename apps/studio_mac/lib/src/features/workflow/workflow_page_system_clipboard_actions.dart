part of '../../studio_mac_workspace.dart';

// Workflow 系统剪贴板动作，负责跨流程复制粘贴的读写和兜底。
// 页面内剪贴板优先，系统剪贴板只接受本项目私有 JSON。
extension _WorkflowPageSystemClipboardActions on _WorkflowPageState {
  // 从页面内剪贴板优先粘贴，缺失时读取系统剪贴板。
  Future<void> _pasteWorkflowCanvasSelectionFromAnyClipboard() async {
    final localClipboard = _canvasClipboard;
    if (localClipboard != null && localClipboard.nodes.isNotEmpty) {
      await _pasteWorkflowCanvasClipboard(localClipboard);
      return;
    }
    final systemClipboard = await _readWorkflowCanvasSystemClipboard();
    if (systemClipboard == null || systemClipboard.nodes.isEmpty) return;
    if (!mounted) return;
    _updateWorkflowPageState(() => _canvasClipboard = systemClipboard);
    await _pasteWorkflowCanvasClipboard(systemClipboard);
  }

  // 写入系统剪贴板，失败只影响跨流程粘贴，不影响页面内剪贴板。
  Future<void> _writeWorkflowCanvasSystemClipboard(
    _WorkflowCanvasClipboard clipboard,
  ) async {
    try {
      await Clipboard.setData(ClipboardData(text: clipboard.toClipboardText()));
    } on Object {
      // 受限宿主可能拒绝剪贴板访问，页面内剪贴板仍可继续使用。
    }
  }

  // 读取系统剪贴板中的画布节点快照；普通文本或其它应用数据会被忽略。
  Future<_WorkflowCanvasClipboard?> _readWorkflowCanvasSystemClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return _WorkflowCanvasClipboard.tryParse(data?.text);
    } on Object {
      return null;
    }
  }
}
