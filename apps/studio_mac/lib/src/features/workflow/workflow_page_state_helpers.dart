part of '../../studio_mac_workspace.dart';

// Workflow 页面状态辅助，集中放置锁定判断和源码草稿监听。
extension _WorkflowPageStateHelpers on _WorkflowPageState {
  // 跟踪 Source 页签草稿是否变化，驱动画布锁定和保存按钮状态。
  void _handleSourceChanged() {
    final dirty = _sourceController.text != _lastSyncedSource;
    if (dirty != _sourceDirty) {
      _updateWorkflowPageState(() => _sourceDirty = dirty);
    }
  }

  // 汇总画布编辑锁，保证运行、保存和源码草稿期间都不能改图。
  bool get _workflowGraphEditLocked =>
      _savingGraphEdit ||
      _savingSource ||
      _savingNodes ||
      _sourceDirty ||
      widget.snapshot.runStatus != RunStatus.idle;

  // 判断画布历史是否暂时锁定，运行、保存和源码草稿都会阻止历史操作。
  bool get _workflowHistoryLocked =>
      _savingGraphEdit ||
      _savingSource ||
      _savingNodes ||
      _sourceDirty ||
      widget.snapshot.runStatus != RunStatus.idle;

  // 计算撤销按钮和快捷键是否可用。
  bool get _canUndoWorkflow =>
      _workflowHistory.canUndo(locked: _workflowHistoryLocked);

  // 计算重做按钮和快捷键是否可用。
  bool get _canRedoWorkflow =>
      _workflowHistory.canRedo(locked: _workflowHistoryLocked);

  // 判断是否可以从流程页进入运行页，避免未保存或无效流程被误认为可运行。
  bool _canOpenWorkflowExecute(WorkflowValidateResult validation) {
    return validation.isValid &&
        !_sourceDirty &&
        !_savingGraphEdit &&
        !_savingSource &&
        !_savingNodes &&
        widget.snapshot.runStatus == RunStatus.idle;
  }

  // 返回流程页运行入口的短提示，用户不需要理解底层校验细节。
  String _workflowOpenExecuteTooltip(WorkflowValidateResult validation) {
    if (widget.snapshot.runStatus != RunStatus.idle) return '运行中';
    if (_sourceDirty) return '先保存';
    if (_savingGraphEdit || _savingSource || _savingNodes) return '保存中';
    if (!validation.isValid) return '需修正';
    return '去运行';
  }

  // 生成面向用户的锁定原因，只展示简短可理解的状态。
  String? get _workflowGraphLockReason {
    if (widget.snapshot.runStatus != RunStatus.idle) {
      return '正在运行，画布只读。';
    }
    if (_sourceDirty) {
      return '源码未保存，请先保存或重置。';
    }
    if (_savingGraphEdit) {
      return '正在保存画布。';
    }
    if (_savingSource) {
      return '正在保存源码。';
    }
    if (_savingNodes) return '正在保存节点。';
    return null;
  }
}
