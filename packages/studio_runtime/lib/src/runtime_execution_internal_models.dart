part of '../studio_runtime.dart';

// _ActiveCatch 表示当前生效的 Catch 保护上下文。
// 它只供工作流执行器内部使用，不暴露给 Flutter UI。
final class _ActiveCatch {
  // 创建 Catch 保护上下文。
  const _ActiveCatch({
    required this.nodeId,
    required this.label,
    required this.maxRetries,
    required this.onErrorNodeId,
  });

  final String nodeId;
  final String label;
  final int maxRetries;
  final String? onErrorNodeId;
}

// _WorkflowPausedException 表示工作流进入人工介入态。
// 执行器用它中断当前路径并保留 paused 状态。
final class _WorkflowPausedException implements Exception {
  // 创建暂停异常。
  const _WorkflowPausedException(this.message);

  final String message;

  // 返回可读暂停原因，供运行事件和测试断言使用。
  @override
  String toString() => message;
}

// _SubWorkflowTarget 表示已解析的子流程执行目标。
// 它把引用 ID 和工作流定义绑定，避免执行期重复查找。
final class _SubWorkflowTarget {
  // 创建子流程目标。
  const _SubWorkflowTarget({required this.workflowId, required this.workflow});

  final String workflowId;
  final WorkflowDefinition workflow;
}
