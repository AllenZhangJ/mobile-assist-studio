part of '../studio_runtime.dart';

// Runtime 流程项目命令，负责当前 Project DSL 的保存、复制和重置。
// 这些命令只维护本地 workflow 真源，不连接设备、不启动驱动。
extension StudioRuntimeWorkflowProjectCommands on StudioRuntimeController {
  // 更新当前 Project DSL workflow，保存前必须通过同一个 validator。
  // 运行中拒绝写入，避免执行真源被中途替换。
  Future<bool> updateWorkflow(WorkflowDefinition workflow) async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能修改流程。')));
      return false;
    }

    return _replaceCurrentWorkflow(
      workflow,
      eventMessage: '流程已更新：${workflow.name}。',
    );
  }

  // 复制当前流程并把副本设为当前流程，仍经过 workflow store 保存。
  // 运行中拒绝复制，防止执行真源被中途替换。
  Future<bool> duplicateCurrentWorkflow() async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能复制流程。')));
      return false;
    }

    final copy = _snapshot.workflow.copyWith(
      id: _workflowCopyId(_snapshot.workflow.id, DateTime.now()),
      name: _workflowCopyName(_snapshot.workflow.name),
    );
    return _replaceCurrentWorkflow(copy, eventMessage: '流程已复制：${copy.name}。');
  }

  // 删除当前流程的轻量实现：回到内置 A-F 模板。
  // 当前版本保持单流程真源，不引入多项目回收站或数据库。
  Future<bool> resetCurrentWorkflowToTemplate() async {
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行中不能删除流程。')));
      return false;
    }

    final previousWorkflowId = _snapshot.workflow.id;
    final template = WorkflowDefinition.afTemplate();
    final targetLibrary = _targetLibrarySnapshotFor(
      targets: _snapshot.targetLibrary.targets,
      workflow: template,
    );
    final favorites = _snapshot.settings.favoriteWorkflowIds
        .where((id) => id != previousWorkflowId)
        .toList(growable: false);
    final updatedSettings = _snapshot.settings.copyWith(
      favoriteWorkflowIds: favorites,
    );

    try {
      await _workflowStore.saveWorkflow(template);
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '流程删除失败：$error')));
      return false;
    }

    var settingsSaved = true;
    try {
      await _settingsStore.saveSettings(updatedSettings);
    } on Object {
      settingsSaved = false;
    }

    _emit(
      _snapshot.copyWith(
        workflow: template,
        workflowIsValid: true,
        targetLibrary: targetLibrary,
        settings: settingsSaved ? updatedSettings : _snapshot.settings,
        executionFocus: RuntimeExecutionFocus.empty,
        events: _appendEvent(
          settingsSaved ? 'info' : 'warning',
          settingsSaved ? '流程已删除，已回到基础模板。' : '流程已删除，收藏状态未保存。',
        ),
      ),
    );
    return true;
  }

  // 统一保存当前流程，保证复制等动作和普通编辑走同一校验链路。
  // 这里不调用设备、不启动驱动，只更新 DSL 真源和运行时快照。
  Future<bool> _replaceCurrentWorkflow(
    WorkflowDefinition workflow, {
    required String eventMessage,
  }) async {
    final targetLibrary = _targetLibrarySnapshotFor(
      targets: _snapshot.targetLibrary.targets,
      workflow: workflow,
    );
    final validation = _workflowProjectValidationResult(
      workflow,
      _subWorkflows,
      targetLibrary,
    );
    if (!validation.isValid) {
      _emit(
        _snapshot.copyWith(
          events: _appendEvent(
            'warning',
            '流程未保存：${validation.errors.join(' ')}',
          ),
        ),
      );
      return false;
    }

    try {
      await _workflowStore.saveWorkflow(workflow);
    } on Object catch (error) {
      _emit(_snapshot.copyWith(events: _appendEvent('error', '流程保存失败：$error')));
      return false;
    }

    _emit(
      _snapshot.copyWith(
        workflow: workflow,
        workflowIsValid: true,
        targetLibrary: targetLibrary,
        executionFocus: RuntimeExecutionFocus.empty,
        events: _appendEvent('info', eventMessage),
      ),
    );
    return true;
  }
}
