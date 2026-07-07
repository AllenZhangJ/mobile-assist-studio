part of '../studio_runtime.dart';

// Sub Workflow 引用问题，供 Runtime 兜底和 Flutter 诊断共用。
// message 保持稳定定位，displayMessage 用于用户可见短中文提示。
final class WorkflowReferenceIssue {
  const WorkflowReferenceIssue({
    required this.nodeId,
    required this.workflowId,
    required this.message,
    required this.displayMessage,
  });

  final String nodeId;
  final String workflowId;
  final String message;
  final String displayMessage;
}

// Sub Workflow 引用校验器，集中处理缺失引用和自引用。
// 该校验只读取 Project DSL 和本地子流程清单，不连接设备、不启动驱动。
final class WorkflowReferenceValidator {
  const WorkflowReferenceValidator._();

  static List<WorkflowReferenceIssue> validate(
    WorkflowDefinition workflow, {
    required Set<String> availableSubWorkflowIds,
    Map<String, Set<String>> referencesByWorkflowId = const {},
  }) {
    final issues = <WorkflowReferenceIssue>[];
    final effectiveReferences = <String, Set<String>>{
      for (final entry in referencesByWorkflowId.entries)
        entry.key: Set<String>.unmodifiable(entry.value),
      workflow.id: _referencedSubWorkflowIds(workflow),
    };
    for (final node in workflow.nodes) {
      final workflowId = _subWorkflowIdFromNode(node);
      if (workflowId == null || workflowId.isEmpty) continue;
      if (workflowId == workflow.id) {
        issues.add(
          WorkflowReferenceIssue(
            nodeId: node.id,
            workflowId: workflowId,
            message: 'Sub Workflow node ${node.id} cannot reference itself.',
            displayMessage: '节点 ${node.label} 不能引用自己。',
          ),
        );
        continue;
      }
      if (!availableSubWorkflowIds.contains(workflowId)) {
        issues.add(
          WorkflowReferenceIssue(
            nodeId: node.id,
            workflowId: workflowId,
            message:
                'Sub Workflow node ${node.id} references missing workflow $workflowId.',
            displayMessage: '节点 ${node.label} 引用了不存在的子流程：$workflowId。',
          ),
        );
        continue;
      }
      final missingNestedWorkflowId = _firstMissingNestedSubWorkflowReference(
        workflowId,
        availableSubWorkflowIds: availableSubWorkflowIds,
        referencesByWorkflowId: effectiveReferences,
      );
      if (missingNestedWorkflowId != null) {
        issues.add(
          WorkflowReferenceIssue(
            nodeId: node.id,
            workflowId: workflowId,
            message:
                'Sub Workflow node ${node.id} references workflow $workflowId with missing nested workflow $missingNestedWorkflowId.',
            displayMessage:
                '节点 ${node.label} 的子流程链缺少：$missingNestedWorkflowId。',
          ),
        );
        continue;
      }
      if (_hasRecursiveSubWorkflowReference(
        workflowId,
        referencesByWorkflowId: effectiveReferences,
      )) {
        issues.add(
          WorkflowReferenceIssue(
            nodeId: node.id,
            workflowId: workflowId,
            message:
                'Sub Workflow node ${node.id} creates recursive workflow reference $workflowId.',
            displayMessage: '节点 ${node.label} 会造成子流程循环引用：$workflowId。',
          ),
        );
      }
    }
    return List<WorkflowReferenceIssue>.unmodifiable(issues);
  }
}

// 从 Sub Workflow 节点读取目标 workflowId。
// 非子流程节点或空值交给 DSL validator 处理，这里不重复报错。
String? _subWorkflowIdFromNode(WorkflowNode node) {
  if (node.type != WorkflowNodeType.subWorkflow) return null;
  final rawWorkflowId = node.parameters['workflowId'];
  if (rawWorkflowId is! String) return null;
  return rawWorkflowId.trim();
}

// 读取 workflow 中直接引用的子流程 ID，用于构建本地引用图。
Set<String> _referencedSubWorkflowIds(WorkflowDefinition workflow) {
  final ids = <String>{};
  for (final node in workflow.nodes) {
    final workflowId = _subWorkflowIdFromNode(node);
    if (workflowId == null || workflowId.isEmpty) continue;
    ids.add(workflowId);
  }
  return Set<String>.unmodifiable(ids);
}

// 从某个子流程出发寻找第一条缺失的嵌套引用。
String? _firstMissingNestedSubWorkflowReference(
  String workflowId, {
  required Set<String> availableSubWorkflowIds,
  required Map<String, Set<String>> referencesByWorkflowId,
}) {
  final visited = <String>{};

  String? visit(String currentWorkflowId) {
    if (!visited.add(currentWorkflowId)) return null;
    final nextWorkflowIds =
        referencesByWorkflowId[currentWorkflowId] ?? const <String>{};
    for (final nextWorkflowId in nextWorkflowIds) {
      if (!availableSubWorkflowIds.contains(nextWorkflowId)) {
        return nextWorkflowId;
      }
      final nestedMissing = visit(nextWorkflowId);
      if (nestedMissing != null) return nestedMissing;
    }
    return null;
  }

  return visit(workflowId);
}

// 从某个子流程出发检查是否存在递归引用环。
bool _hasRecursiveSubWorkflowReference(
  String workflowId, {
  required Map<String, Set<String>> referencesByWorkflowId,
}) {
  final visiting = <String>{};
  final visited = <String>{};

  bool visit(String currentWorkflowId) {
    if (visiting.contains(currentWorkflowId)) return true;
    if (!visited.add(currentWorkflowId)) return false;
    visiting.add(currentWorkflowId);
    final nextWorkflowIds =
        referencesByWorkflowId[currentWorkflowId] ?? const <String>{};
    for (final nextWorkflowId in nextWorkflowIds) {
      if (visit(nextWorkflowId)) return true;
    }
    visiting.remove(currentWorkflowId);
    return false;
  }

  return visit(workflowId);
}

// 将本地子流程集合转换为引用图，供 Runtime 和 Flutter 状态复用。
Map<String, Set<String>> _subWorkflowReferencesByWorkflowId(
  Map<String, WorkflowDefinition> subWorkflows,
) {
  return <String, Set<String>>{
    for (final entry in subWorkflows.entries)
      entry.key: _referencedSubWorkflowIds(entry.value),
  };
}

// Runtime workflow 引用工具，集中处理子流程引用完整性。
// 这里只返回中文短提示，便于运行事件直接展示。
List<String> _subWorkflowReferenceErrors(
  WorkflowDefinition workflow,
  Map<String, WorkflowDefinition> subWorkflows,
) {
  return WorkflowReferenceValidator.validate(
    workflow,
    availableSubWorkflowIds: subWorkflows.keys.toSet(),
    referencesByWorkflowId: _subWorkflowReferencesByWorkflowId(subWorkflows),
  ).map((issue) => issue.displayMessage).toList(growable: false);
}

// 合并 DSL 结构校验和本地项目级引用校验。
// Runtime 保存、注册和运行前检查都应复用它，避免规则分叉。
WorkflowValidateResult _workflowProjectValidationResult(
  WorkflowDefinition workflow,
  Map<String, WorkflowDefinition> subWorkflows,
  TargetLibrarySnapshot targetLibrary,
) {
  final dslValidation = const WorkflowValidator().validate(workflow);
  return WorkflowValidateResult.fromErrors([
    ...dslValidation.errors,
    ..._subWorkflowReferenceErrors(workflow, subWorkflows),
    ...targetLibrary.issues
        .where((issue) => issue.nodeId != null)
        .map((issue) => issue.displayMessage),
  ]);
}

// 判断某个 workflow 是否引用指定子流程 ID。
// 只读取 Project DSL 参数，不展开执行子流程。
bool _workflowReferencesSubWorkflow(
  WorkflowDefinition workflow,
  String workflowId,
) {
  return workflow.nodes.any(
    (node) => _subWorkflowIdFromNode(node) == workflowId,
  );
}
