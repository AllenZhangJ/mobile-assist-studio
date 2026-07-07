part of '../../studio_mac_workspace.dart';

// Workflow 页面子流程动作分片，集中承载本地子流程注册、保存和删除。
// 页面主文件只保留渲染与整体状态编排，具体命令仍交给 Runtime 兜底。
extension _WorkflowPageSubWorkflowActions on _WorkflowPageState {
  // 注册本机示例子流程，写入 Runtime 本地子流程真源，不触发设备或运行。
  Future<void> _registerStarterSubWorkflow() async {
    if (widget.snapshot.runStatus != RunStatus.idle) return;
    final registered = await widget.controller.registerSubWorkflow(
      _starterSubWorkflowTemplate(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(registered ? '子流程已添加。' : '子流程未添加，请看控制台。')),
    );
  }

  // 把当前主流程存为本地子流程，便于后续复用。
  Future<void> _registerCurrentWorkflowAsSubWorkflow() async {
    if (widget.snapshot.runStatus != RunStatus.idle) return;
    final registered = await widget.controller
        .registerCurrentWorkflowAsSubWorkflow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(registered ? '子流程已保存。' : '子流程未保存，请看控制台。')),
    );
  }

  // 删除子流程前弹出确认，真正的引用保护由 Runtime 兜底。
  Future<void> _confirmDeleteSubWorkflow(SubWorkflowSummary summary) async {
    if (widget.snapshot.runStatus != RunStatus.idle) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A0F14),
          title: const Text('删除子流程？'),
          content: Text('将删除“${summary.name}”。正在使用时会被拦截。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              key: const ValueKey('sub-workflow-delete-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    final deleted = await widget.controller.deleteSubWorkflow(
      summary.workflowId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? '子流程已删除。' : '子流程未删除，请看控制台。')),
    );
  }
}
