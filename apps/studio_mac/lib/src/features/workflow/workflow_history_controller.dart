part of '../../studio_mac_workspace.dart';

// Workflow 历史控制器，集中维护画布编辑的撤销和重做栈。
class _WorkflowHistoryController {
  final List<WorkflowDefinition> _undoStack = <WorkflowDefinition>[];
  final List<WorkflowDefinition> _redoStack = <WorkflowDefinition>[];

  // 判断当前是否可以撤销，页面只需要传入外部锁定状态。
  bool canUndo({required bool locked}) => _undoStack.isNotEmpty && !locked;

  // 判断当前是否可以重做，页面只需要传入外部锁定状态。
  bool canRedo({required bool locked}) => _redoStack.isNotEmpty && !locked;

  // 记录一次成功编辑，重复内容不会进入历史栈。
  void captureEdit({
    required WorkflowDefinition before,
    required WorkflowDefinition after,
  }) {
    if (_workflowSourceText(before) == _workflowSourceText(after)) return;
    _pushWorkflowHistory(_undoStack, before);
    _redoStack.clear();
  }

  // 取出下一次撤销目标，失败时由页面调用回滚方法放回。
  WorkflowDefinition? takeUndoTarget() {
    if (_undoStack.isEmpty) return null;
    return _undoStack.removeLast();
  }

  // 撤销成功后保存当前版本，供用户重做。
  void commitUndo(WorkflowDefinition current) {
    _pushWorkflowHistory(_redoStack, current);
  }

  // 撤销失败时恢复撤销栈，避免丢失用户历史。
  void rollbackUndo(WorkflowDefinition previous) {
    _pushWorkflowHistory(_undoStack, previous);
  }

  // 取出下一次重做目标，失败时由页面调用回滚方法放回。
  WorkflowDefinition? takeRedoTarget() {
    if (_redoStack.isEmpty) return null;
    return _redoStack.removeLast();
  }

  // 重做成功后保存当前版本，供用户再次撤销。
  void commitRedo(WorkflowDefinition current) {
    _pushWorkflowHistory(_undoStack, current);
  }

  // 重做失败时恢复重做栈，避免丢失用户历史。
  void rollbackRedo(WorkflowDefinition next) {
    _pushWorkflowHistory(_redoStack, next);
  }

  // 将 workflow 压入指定栈，并限制历史长度。
  void _pushWorkflowHistory(
    List<WorkflowDefinition> stack,
    WorkflowDefinition workflow,
  ) {
    final source = _workflowSourceText(workflow);
    if (stack.isNotEmpty && _workflowSourceText(stack.last) == source) return;
    stack.add(workflow);
    const maxHistoryLength = 40;
    if (stack.length > maxHistoryLength) {
      stack.removeRange(0, stack.length - maxHistoryLength);
    }
  }
}
