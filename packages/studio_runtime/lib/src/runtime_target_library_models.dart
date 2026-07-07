part of '../studio_runtime.dart';

// TargetLibraryIssue 表示目标库或目标引用的可诊断问题。
// message 供测试和日志定位，displayMessage 面向 UI 展示短中文。
final class TargetLibraryIssue {
  // 创建目标库问题。
  const TargetLibraryIssue({
    required this.targetId,
    required this.message,
    required this.displayMessage,
    this.nodeId,
  });

  final String? targetId;
  final String? nodeId;
  final String message;
  final String displayMessage;
}

// TargetLibrarySnapshot 是 Runtime 暴露给 UI 的目标库摘要。
// 它只包含脱敏目标定义和校验问题，不包含设备会话或本机绝对路径。
final class TargetLibrarySnapshot {
  // 创建目标库快照。
  const TargetLibrarySnapshot({required this.targets, required this.issues});

  final List<RuntimeTargetDefinition> targets;
  final List<TargetLibraryIssue> issues;

  // 判断目标库和当前引用是否都可用。
  bool get isValid => issues.isEmpty;

  // 返回目标数量。
  int get count => targets.length;

  // 按 ID 查找目标，未找到返回 null。
  RuntimeTargetDefinition? targetById(String targetId) {
    final normalized = targetId.trim();
    for (final target in targets) {
      if (target.id == normalized) return target;
    }
    return null;
  }

  static const empty = TargetLibrarySnapshot(
    targets: <RuntimeTargetDefinition>[],
    issues: <TargetLibraryIssue>[],
  );
}

// TargetLibraryValidator 校验目标资产本身。
// 它不检查 workflow 引用，引用完整性交给 Runtime 项目校验。
final class TargetLibraryValidator {
  const TargetLibraryValidator();

  // 校验完整目标列表，返回稳定排序后的问题集合。
  List<TargetLibraryIssue> validate(Iterable<RuntimeTargetDefinition> targets) {
    final issues = <TargetLibraryIssue>[];
    final ids = <String>{};
    for (final target in targets) {
      final id = target.id.trim();
      if (id.isEmpty) {
        issues.add(
          const TargetLibraryIssue(
            targetId: null,
            message: 'Target id is required.',
            displayMessage: '目标缺少编号。',
          ),
        );
        continue;
      }
      if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
        issues.add(
          TargetLibraryIssue(
            targetId: id,
            message: 'Target $id id is invalid.',
            displayMessage: '目标 ${target.label} 的编号不安全。',
          ),
        );
      }
      if (!ids.add(id)) {
        issues.add(
          TargetLibraryIssue(
            targetId: id,
            message: 'Duplicate target id: $id.',
            displayMessage: '目标编号重复：$id。',
          ),
        );
      }
      if (target.label.trim().isEmpty) {
        issues.add(
          TargetLibraryIssue(
            targetId: id,
            message: 'Target $id label is required.',
            displayMessage: '目标 $id 缺少名称。',
          ),
        );
      }
      _validateTargetPayload(target, issues);
    }
    return List<TargetLibraryIssue>.unmodifiable(issues);
  }

  // 校验目标载荷，确保每类目标都有可理解的最小字段。
  void _validateTargetPayload(
    RuntimeTargetDefinition target,
    List<TargetLibraryIssue> issues,
  ) {
    for (final entry in target.payload.entries) {
      final value = entry.value;
      if (value is String && _containsSensitiveTargetPayload(value)) {
        issues.add(
          TargetLibraryIssue(
            targetId: target.id,
            message: 'Target ${target.id} payload ${entry.key} is sensitive.',
            displayMessage: '目标 ${target.label} 包含不安全内容。',
          ),
        );
      }
    }

    switch (target.kind) {
      case RuntimeTargetKind.coordinate:
        _requireIntPayload(target, 'x', issues);
        _requireIntPayload(target, 'y', issues);
      case RuntimeTargetKind.selector:
        _requireStringPayload(target, 'selector', issues);
      case RuntimeTargetKind.image:
        _requireStringPayload(target, 'imageRef', issues);
        _requireSafeImageRefPayload(target, issues);
      case RuntimeTargetKind.region:
        _requireIntPayload(target, 'x', issues);
        _requireIntPayload(target, 'y', issues);
        _requirePositiveIntPayload(target, 'width', issues);
        _requirePositiveIntPayload(target, 'height', issues);
      case RuntimeTargetKind.text:
        _requireStringPayload(target, 'query', issues);
    }
  }

  // 要求 payload 字段是整数。
  void _requireIntPayload(
    RuntimeTargetDefinition target,
    String key,
    List<TargetLibraryIssue> issues,
  ) {
    final value = target.payload[key];
    if (value is int && value >= 0) return;
    issues.add(
      TargetLibraryIssue(
        targetId: target.id,
        message: 'Target ${target.id} $key must be a non-negative integer.',
        displayMessage: '目标 ${target.label} 的 $key 不可用。',
      ),
    );
  }

  // 要求 payload 字段是正整数。
  void _requirePositiveIntPayload(
    RuntimeTargetDefinition target,
    String key,
    List<TargetLibraryIssue> issues,
  ) {
    final value = target.payload[key];
    if (value is int && value > 0) return;
    issues.add(
      TargetLibraryIssue(
        targetId: target.id,
        message: 'Target ${target.id} $key must be a positive integer.',
        displayMessage: '目标 ${target.label} 的 $key 不可用。',
      ),
    );
  }

  // 要求 payload 字段是非空字符串。
  void _requireStringPayload(
    RuntimeTargetDefinition target,
    String key,
    List<TargetLibraryIssue> issues,
  ) {
    final value = target.payload[key];
    if (value is String && value.trim().isNotEmpty) return;
    issues.add(
      TargetLibraryIssue(
        targetId: target.id,
        message: 'Target ${target.id} $key is required.',
        displayMessage: '目标 ${target.label} 缺少必要内容。',
      ),
    );
  }

  // 要求图片目标引用项目内相对模板路径。
  void _requireSafeImageRefPayload(
    RuntimeTargetDefinition target,
    List<TargetLibraryIssue> issues,
  ) {
    final value = target.payload['imageRef'];
    if (value is! String || value.trim().isEmpty) return;
    if (_isSafeTargetAssetRef(value)) return;
    issues.add(
      TargetLibraryIssue(
        targetId: target.id,
        message: 'Target ${target.id} imageRef is unsafe.',
        displayMessage: '目标 ${target.label} 的图片路径不安全。',
      ),
    );
  }
}

// 从 workflow 中提取 targetRef 引用。
// 这里只读取参数，不尝试解析目标或访问设备。
Set<String> _referencedTargetIds(WorkflowDefinition workflow) {
  final targetIds = <String>{};
  for (final node in workflow.nodes) {
    final targetRef = _targetRefFromNode(node);
    if (targetRef == null) continue;
    targetIds.add(targetRef);
  }
  return Set<String>.unmodifiable(targetIds);
}

// 从节点参数读取 targetRef，空白值交给 DSL 或运行时兜底。
String? _targetRefFromNode(WorkflowNode node) {
  final value = node.parameters['targetRef'];
  if (value is! String) return null;
  final normalized = value.trim();
  if (normalized.isEmpty) return null;
  return normalized;
}

// 生成 workflow 对目标库的引用问题。
List<TargetLibraryIssue> _targetReferenceIssues(
  WorkflowDefinition workflow,
  Iterable<RuntimeTargetDefinition> targets,
) {
  final targetIds = targets.map((target) => target.id).toSet();
  final issues = <TargetLibraryIssue>[];
  for (final node in workflow.nodes) {
    final targetRef = _targetRefFromNode(node);
    if (targetRef == null) continue;
    if (!targetIds.contains(targetRef)) {
      issues.add(
        TargetLibraryIssue(
          targetId: targetRef,
          nodeId: node.id,
          message: 'Node ${node.id} references missing target $targetRef.',
          displayMessage: '节点 ${node.label} 引用了不存在的目标。',
        ),
      );
    }
  }
  return List<TargetLibraryIssue>.unmodifiable(issues);
}

// 重新构建目标库快照，用于保存目标或 workflow 后同步问题列表。
TargetLibrarySnapshot _targetLibrarySnapshotFor({
  required List<RuntimeTargetDefinition> targets,
  required WorkflowDefinition workflow,
}) {
  final sortedTargets = List<RuntimeTargetDefinition>.of(targets)
    ..sort((a, b) => a.id.compareTo(b.id));
  return TargetLibrarySnapshot(
    targets: List<RuntimeTargetDefinition>.unmodifiable(sortedTargets),
    issues: List<TargetLibraryIssue>.unmodifiable([
      ...const TargetLibraryValidator().validate(sortedTargets),
      ..._targetReferenceIssues(workflow, sortedTargets),
    ]),
  );
}

// 判断目标 payload 是否包含不应持久化的敏感路径或协议。
bool _containsSensitiveTargetPayload(String value) {
  final normalized = value.trim();
  if (normalized.startsWith('/')) return true;
  if (normalized.startsWith('file://')) return true;
  if (normalized.contains('/Users/')) return true;
  return false;
}
