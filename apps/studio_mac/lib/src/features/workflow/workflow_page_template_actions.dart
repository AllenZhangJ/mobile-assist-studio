part of '../../studio_mac_workspace.dart';

// Workflow 模板动作，负责模板抽屉打开和模板导入后的页面同步。
extension _WorkflowPageTemplateActions on _WorkflowPageState {
  // 打开模板抽屉，模板导入仍走统一 DSL 更新和历史记录。
  void _openWorkflowTemplateDrawer() {
    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: '关闭模板',
        barrierColor: Colors.black.withValues(alpha: 0.52),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: _WorkflowTemplateDrawer(
              templates: _workflowTemplates,
              onImport: (template) =>
                  unawaited(_importWorkflowTemplate(template)),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 180),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  // 导入本地模板为当前 workflow，并同步 Source 文本和可视选区。
  Future<void> _importWorkflowTemplate(_WorkflowTemplate template) async {
    if (_savingGraphEdit ||
        _savingSource ||
        _sourceDirty ||
        widget.snapshot.runStatus != RunStatus.idle) {
      return;
    }
    _updateWorkflowPageState(() => _savingGraphEdit = true);
    final updated = await _updateWorkflowWithHistory(template.workflow);
    if (!mounted) return;
    _updateWorkflowPageState(() {
      _savingGraphEdit = false;
      if (updated) {
        _selectedNodeId = null;
        _selectedNodeIds = const <String>{};
        _lastSyncedSource = _workflowSourceText(template.workflow);
        _sourceController.text = _lastSyncedSource;
        _sourceDirty = false;
        _selectedTab = _WorkflowTab.visual;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(updated ? '模板已导入。' : '模板未导入，请看控制台。')),
    );
  }
}
