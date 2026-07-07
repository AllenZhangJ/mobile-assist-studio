part of '../studio_runtime.dart';

// 单次运行最大轮次，持续模式也必须落在这个安全上限内。
const int _maxWorkflowRunLoops = 999;

// Runtime 的工作流运行控制命令。
// 这里只负责启动、停止和暂停收口，节点执行细节仍在 execution 分片。
extension StudioRuntimeRunCommands on StudioRuntimeController {
  // 运行当前 Project DSL workflow。
  Future<WorkflowRunResult?> runCurrentWorkflow({
    int loops = 1,
    int? tapDurationMs,
  }) async {
    final resolvedTapDurationMs = tapDurationMs ?? defaultTapDurationMs;
    if (loops < 1) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '运行次数至少为 1。')));
      return null;
    }
    if (loops > _maxWorkflowRunLoops) {
      _emit(
        _snapshot.copyWith(
          events: _appendEvent('warning', '最多支持 $_maxWorkflowRunLoops 轮。'),
        ),
      );
      return null;
    }
    if (_snapshot.connectionStatus != ConnectionStatus.connected) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '请先连接设备再运行。')));
      return null;
    }
    if (_snapshot.runStatus != RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '忙碌中不能启动运行。')));
      return null;
    }
    final session = _sessionManager.session;
    if (session == null) {
      _emit(
        _snapshot.copyWith(
          connectionStatus: ConnectionStatus.error,
          events: _appendEvent('error', '设备已连但会话缺失。'),
        ),
      );
      return null;
    }

    final validation = _workflowProjectValidationResult(
      _snapshot.workflow,
      _subWorkflows,
      _snapshot.targetLibrary,
    );
    if (!validation.isValid) {
      _emit(
        _snapshot.copyWith(
          runStatus: RunStatus.idle,
          events: _appendEvent('error', '流程无效：${validation.errors.join(' ')}'),
        ),
      );
      return null;
    }

    _stopRequested = false;
    var completedLoops = 0;
    String? evidenceRunId;
    evidenceRunId = await _startEvidenceRun(loops: loops);
    final runStartedAt = DateTime.now();
    final totalSteps = _estimatedTotalExecutionSteps(_snapshot.workflow, loops);
    _emit(
      _snapshot.copyWith(
        runStatus: RunStatus.running,
        executionFocus: RuntimeExecutionFocus.empty.copyWith(
          totalLoops: loops,
          activeLoopIndex: 0,
          runStartedAt: runStartedAt,
          totalSteps: totalSteps,
        ),
        events: _appendEvent(
          'info',
          '开始运行：$loops 轮，流程 ${_snapshot.workflow.name}。',
        ),
      ),
    );

    try {
      for (var loopIndex = 0; loopIndex < loops; loopIndex += 1) {
        if (_stopRequested) break;
        await _runWorkflowLoop(
          workflow: _snapshot.workflow,
          sessionId: session.id,
          loopIndex: loopIndex,
          totalLoops: loops,
          tapDurationMs: resolvedTapDurationMs,
          evidenceRunId: evidenceRunId,
          depth: 0,
          workflowInputs: const <String, Object?>{},
        );
        if (_stopRequested) break;
        completedLoops += 1;
      }
      final stopped = _stopRequested;
      _emit(
        _snapshot.copyWith(
          runStatus: RunStatus.idle,
          executionFocus: _snapshot.executionFocus.copyWith(
            activeNodeId: null,
            activeLoopIndex: null,
            totalLoops: null,
            runStartedAt: null,
          ),
          events: _appendEvent(
            stopped ? 'warning' : 'info',
            stopped
                ? '已安全停止：$completedLoops/$loops 轮。'
                : '运行完成：$completedLoops/$loops 轮。',
          ),
        ),
      );
      await _finishEvidenceRun(
        evidenceRunId,
        status: stopped ? 'stopped' : 'completed',
        completedLoops: completedLoops,
      );
      await refreshRunHistory();
      return WorkflowRunResult(
        requestedLoops: loops,
        completedLoops: completedLoops,
        stopped: stopped,
      );
    } on _WorkflowPausedException catch (pause) {
      _emit(
        _snapshot.copyWith(
          runStatus: RunStatus.paused,
          executionFocus: _snapshot.executionFocus.copyWith(
            activeNodeId: null,
            activeLoopIndex: null,
            totalLoops: null,
          ),
          events: _appendEvent('warning', '运行已暂停：${pause.message}'),
        ),
      );
      await _finishEvidenceRun(
        evidenceRunId,
        status: 'paused',
        completedLoops: completedLoops,
      );
      await refreshRunHistory();
      return WorkflowRunResult(
        requestedLoops: loops,
        completedLoops: completedLoops,
        stopped: false,
        paused: true,
      );
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(
          runStatus: RunStatus.idle,
          executionFocus: _snapshot.executionFocus.copyWith(
            activeNodeId: null,
            activeLoopIndex: null,
            totalLoops: null,
          ),
          events: _appendEvent('error', '运行失败：$error'),
        ),
      );
      await _finishEvidenceRun(
        evidenceRunId,
        status: 'failed',
        completedLoops: completedLoops,
      );
      await refreshRunHistory();
      return null;
    } finally {
      _stopRequested = false;
    }
  }

  // 请求安全停止；当前原子动作完成后才会停下。
  Future<void> stopRun() async {
    if (_snapshot.runStatus == RunStatus.idle) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '当前没有运行任务。')));
      return;
    }
    if (_snapshot.runStatus == RunStatus.paused) {
      await resolvePause();
      return;
    }
    _stopRequested = true;
    _emit(
      _snapshot.copyWith(
        runStatus: RunStatus.stopping,
        events: _appendEvent('warning', '已请求停止，等待当前动作完成。'),
      ),
    );
  }

  // 解除 paused 状态并回到 idle，不继续后续节点。
  Future<void> resolvePause() async {
    if (_snapshot.runStatus != RunStatus.paused) {
      _emit(_snapshot.copyWith(events: _appendEvent('warning', '当前没有暂停任务。')));
      return;
    }
    _emit(
      _snapshot.copyWith(
        runStatus: RunStatus.idle,
        executionFocus: _snapshot.executionFocus.copyWith(
          activeNodeId: null,
          activeLoopIndex: null,
          totalLoops: null,
        ),
        events: _appendEvent('warning', '暂停已解除，任务已安全收口。'),
      ),
    );
  }
}
