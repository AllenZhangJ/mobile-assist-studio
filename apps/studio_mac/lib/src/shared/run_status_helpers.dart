part of '../studio_mac_workspace.dart';

// 运行状态 helper，负责执行页、录制页和进度展示的状态映射。
StudioStatusTone _toneForRunStatus(String status) {
  return switch (_runHistoryStatusLabel(status)) {
    '完成' => StudioStatusTone.ready,
    '失败' => StudioStatusTone.error,
    '暂停' => StudioStatusTone.warning,
    '已停' => StudioStatusTone.warning,
    _ => StudioStatusTone.running,
  };
}

String _runHistoryStatusLabel(String status) {
  return switch (status) {
    'completed' => '完成',
    'failed' => '失败',
    'paused' => '暂停',
    'stopped' => '已停',
    'running' => '运行中',
    _ => status,
  };
}

StudioStatusTone _toneForLiveRunStatus(RunStatus status) {
  return switch (status) {
    RunStatus.idle => StudioStatusTone.ready,
    RunStatus.running => StudioStatusTone.running,
    RunStatus.paused => StudioStatusTone.warning,
    RunStatus.stopping => StudioStatusTone.warning,
  };
}

String _runStatusLabel(RunStatus status) {
  return switch (status) {
    RunStatus.idle => '空闲',
    RunStatus.running => '运行中',
    RunStatus.paused => '暂停',
    RunStatus.stopping => '停止中',
  };
}

String _executeReadyMessage(
  StudioRuntimeSnapshot snapshot, {
  required bool workflowIsValid,
}) {
  if (!workflowIsValid) {
    return '流程有问题，暂不能运行。';
  }
  if (snapshot.lastConnectionDiagnostic case final diagnostic?
      when snapshot.connectionStatus != ConnectionStatus.connected) {
    return '${diagnostic.summary} ${diagnostic.nextStep}';
  }
  if (snapshot.appiumStatus != AppiumProcessStatus.running) {
    return '点连接设备，会自动准备驱动。';
  }
  if (snapshot.connectionStatus != ConnectionStatus.connected) {
    return '请先连接一台 iPhone。';
  }
  return '选择轮数后开始串行运行。';
}

String _recorderNextStepMessage({
  required StudioRuntimeSnapshot snapshot,
  required bool recording,
  required int actionCount,
}) {
  if (snapshot.connectionStatus != ConnectionStatus.connected) {
    return '请先连接 iPhone。';
  }
  if (snapshot.runStatus != RunStatus.idle) {
    return '运行中录制会受限。';
  }
  if (recording && actionCount == 0) {
    return '先截图，再按画面添加动作。';
  }
  if (actionCount > 0) {
    return '确认动作后生成流程。';
  }
  return '画面就绪后开始录制。';
}

double _executionProgress(
  WorkflowDefinition workflow,
  RuntimeExecutionFocus focus,
) {
  final totalSteps = focus.totalSteps;
  if (totalSteps != null && totalSteps > 0) {
    return (focus.completedSteps / totalSteps).clamp(0, 1).toDouble();
  }
  final totalNodes = math.max(1, workflow.nodes.length);
  final completed = focus.completedNodeIds.length.clamp(0, totalNodes);
  return completed / totalNodes;
}

String _executionStepLabel(RuntimeExecutionFocus focus) {
  final totalSteps = focus.totalSteps;
  if (totalSteps != null && totalSteps > 0) {
    return '${focus.completedSteps.clamp(0, totalSteps)}/$totalSteps 步';
  }
  return '${focus.completedNodeIds.length} 个节点';
}

String _estimatedRemainingLabel(
  RuntimeExecutionFocus focus,
  RunStatus runStatus,
) {
  if (runStatus != RunStatus.running) return '-';
  final startedAt = focus.runStartedAt;
  final totalSteps = focus.totalSteps;
  if (startedAt == null || totalSteps == null || totalSteps <= 0) {
    return '计算中';
  }
  final completedSteps = focus.completedSteps;
  final remainingSteps = totalSteps - completedSteps;
  if (remainingSteps <= 0) return '收尾中';
  if (completedSteps <= 0) return '计算中';
  final elapsed = DateTime.now().difference(startedAt);
  if (elapsed.inMilliseconds <= 0) return '计算中';
  final averageStepMs = elapsed.inMilliseconds / completedSteps;
  final remainingMs = math.max(0, (averageStepMs * remainingSteps).round());
  return _formatDuration(Duration(milliseconds: remainingMs));
}
