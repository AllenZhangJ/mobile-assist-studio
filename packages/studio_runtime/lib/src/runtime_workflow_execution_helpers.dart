part of '../studio_runtime.dart';

// 工作流执行辅助分片，承载节点查找和用户可见运行文案。
extension StudioRuntimeControllerWorkflowExecutionHelpers
    on StudioRuntimeController {
  // 统一生成节点运行事件文案，避免 Runtime 直接暴露英文动作名。
  String _workflowNodeRunMessage({
    required int loopIndex,
    required int totalLoops,
    required String action,
    required String label,
  }) {
    final safeLabel = label.trim().isEmpty ? '当前节点' : label.trim();
    return '第 ${loopIndex + 1}/$totalLoops 轮：$action $safeLabel。';
  }

  // 向 Runtime 事件流写入单节点运行提示。
  void _emitNodeRunEvent({
    required int loopIndex,
    required int totalLoops,
    required String action,
    required String label,
  }) {
    _emit(
      _snapshot.copyWith(
        events: _appendEvent(
          'info',
          _workflowNodeRunMessage(
            loopIndex: loopIndex,
            totalLoops: totalLoops,
            action: action,
            label: label,
          ),
        ),
      ),
    );
  }

  // 按节点 id 查找 Project DSL 节点，缺失时直接给出中文错误。
  WorkflowNode _nodeById(WorkflowDefinition workflow, String nodeId) {
    return workflow.nodes.firstWhere(
      (node) => node.id == nodeId,
      orElse: () => throw StateError('流程节点不存在：$nodeId。'),
    );
  }
}
