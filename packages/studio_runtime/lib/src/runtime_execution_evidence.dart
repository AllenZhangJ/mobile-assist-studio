part of '../studio_runtime.dart';

// Runtime 执行证据扩展，负责运行开始、结束、事件和截图证据写入。
// 证据写入失败只降级为 warning，不中断主执行链路。
extension StudioRuntimeExecutionEvidence on StudioRuntimeController {
  // 开始一次本地运行证据记录，并写入 runStart 事件。
  // 创建失败返回 null，让执行流程继续但不沉淀证据。
  Future<String?> _startEvidenceRun({required int loops}) async {
    try {
      final runId = await _evidenceStore.startRun(
        workflowName: _snapshot.workflow.name,
        loops: loops,
        startedAt: DateTime.now(),
      );
      await _evidenceStore.recordEvent(runId, <String, Object?>{
        'type': 'runStart',
        'workflowName': _snapshot.workflow.name,
        'loops': loops,
      });
      return runId;
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '证据开始失败：$error')),
      );
      return null;
    }
  }

  // 结束本地运行证据记录，并写入 runEnd 与 finish summary。
  // 收尾失败只写 warning，避免掩盖真实运行结果。
  Future<void> _finishEvidenceRun(
    String? runId, {
    required String status,
    required int completedLoops,
  }) async {
    if (runId == null) return;
    try {
      await _evidenceStore.recordEvent(runId, <String, Object?>{
        'type': 'runEnd',
        'status': status,
        'completedLoops': completedLoops,
      });
      await _evidenceStore.finishRun(
        runId,
        status: status,
        completedLoops: completedLoops,
        finishedAt: DateTime.now(),
      );
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '证据收尾失败：$error')),
      );
    }
  }

  // 写入单条运行事件，供 Monitor、Execute 和详情抽屉共用。
  // runId 为空时表示本次运行无证据文件，直接跳过。
  Future<void> _recordEvidenceEvent(
    String? runId,
    Map<String, Object?> event,
  ) async {
    if (runId == null) return;
    try {
      await _evidenceStore.recordEvent(runId, event);
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '证据事件失败：$error')),
      );
    }
  }

  // 保存 Snapshot 节点产出的截图证据，并返回相对证据路径。
  // 保存失败返回 null，后续事件仍可继续写入结构化摘要。
  Future<String?> _recordScreenshotEvidence(
    String? runId, {
    required WorkflowNode node,
    required int loopIndex,
    required String base64Png,
  }) async {
    if (runId == null) return null;
    try {
      return await _evidenceStore.recordScreenshot(
        runId,
        fileName: '${node.id}-loop-${loopIndex + 1}.png',
        base64Png: base64Png,
      );
    } on Object catch (error) {
      _emit(
        _snapshot.copyWith(events: _appendEvent('warning', '截图证据失败：$error')),
      );
      return null;
    }
  }
}
