part of '../studio_runtime.dart';

// Runtime 子流程项目命令，负责本地 Sub Workflow Store 的受控写入。
// 子流程命令不触发设备动作，只维护可被主流程引用的 Project DSL。
extension StudioRuntimeSubWorkflowProjectCommands on StudioRuntimeController {
  // 注册本机子流程，供 Sub Workflow 节点选择和执行。
  // 该动作写入本地子流程真源，不连接设备、不启动驱动、不执行流程。
  Future<bool> registerSubWorkflow(WorkflowDefinition workflow) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能添加子流程。')));
      return false;
    }

    final validation = _workflowProjectValidationResult(
      workflow,
      _subWorkflows,
      _targetLibrarySnapshotFor(
        targets: _snapshot.targetLibrary.targets,
        workflow: workflow,
      ),
    );
    if (!validation.isValid) {
      _emit(
        _snapshot.copyWith(
          events: _appendEvent(
            'warning',
            '子流程未添加：${validation.errors.join(' ')}',
          ),
        ),
      );
      return false;
    }

    final updatedSubWorkflows = Map<String, WorkflowDefinition>.of(
      _subWorkflows,
    )..[workflow.id] = workflow;
    try {
      await _subWorkflowStore.saveSubWorkflows(updatedSubWorkflows);
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('error', '子流程保存失败：$error')),
      );
      return false;
    }

    _subWorkflows
      ..clear()
      ..addAll(updatedSubWorkflows);
    _emit(
      _snapshot.copyWith(
        subWorkflows: SubWorkflowSummary.fromWorkflows(_subWorkflows),
        events: _appendEvent('info', '子流程已添加：${workflow.name}。'),
      ),
    );
    return true;
  }

  // 把当前主流程复制成本地子流程，供后续 Sub Workflow 节点复用。
  // 该动作不替换当前 workflow，不连接设备，也不执行流程。
  Future<bool> registerCurrentWorkflowAsSubWorkflow() async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能添加子流程。')));
      return false;
    }

    final currentWorkflow = _snapshot.workflow;
    final copy = currentWorkflow.copyWith(
      id: _subWorkflowCopyId(currentWorkflow.id, DateTime.now()),
      name: '${currentWorkflow.name} 子流程',
    );
    return registerSubWorkflow(copy);
  }

  // 删除本机子流程，删除前检查当前 workflow 和其它子流程引用。
  // 只有本地 store 保存成功后才更新 Runtime snapshot，避免 UI 与文件漂移。
  Future<bool> deleteSubWorkflow(String workflowId) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能删除子流程。')));
      return false;
    }
    if (!_subWorkflows.containsKey(workflowId)) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '子流程不存在。')));
      return false;
    }
    if (_workflowReferencesSubWorkflow(_snapshot.workflow, workflowId)) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '当前流程正在使用该子流程。')),
      );
      return false;
    }
    for (final workflow in _subWorkflows.values) {
      if (workflow.id == workflowId) continue;
      if (_workflowReferencesSubWorkflow(workflow, workflowId)) {
        _emit(
          _snapshot.copyWith(
            events: _appendEvent('warning', '子流程 ${workflow.name} 正在使用它。'),
          ),
        );
        return false;
      }
    }

    final updatedSubWorkflows = Map<String, WorkflowDefinition>.of(
      _subWorkflows,
    )..remove(workflowId);
    try {
      await _subWorkflowStore.saveSubWorkflows(updatedSubWorkflows);
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('error', '子流程删除失败：$error')),
      );
      return false;
    }

    _subWorkflows
      ..clear()
      ..addAll(updatedSubWorkflows);
    _emit(
      _snapshot.copyWith(
        subWorkflows: SubWorkflowSummary.fromWorkflows(_subWorkflows),
        events: _appendEvent('info', '子流程已删除。'),
      ),
    );
    return true;
  }
}
