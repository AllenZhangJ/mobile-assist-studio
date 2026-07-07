part of '../studio_runtime.dart';

// 工作流与设置存储，负责本地 DSL 和用户偏好的读写。
final class WorkflowRunResult {
  const WorkflowRunResult({
    required this.requestedLoops,
    required this.completedLoops,
    required this.stopped,
    this.paused = false,
  });

  final int requestedLoops;
  final int completedLoops;
  final bool stopped;
  final bool paused;
}

abstract interface class WorkflowStore {
  Future<void> saveWorkflow(WorkflowDefinition workflow);
}

final class NoopWorkflowStore implements WorkflowStore {
  const NoopWorkflowStore();

  @override
  Future<void> saveWorkflow(WorkflowDefinition workflow) async {}
}

final class LocalWorkflowStore implements WorkflowStore {
  const LocalWorkflowStore({required File file}) : _file = file;

  final File _file;

  WorkflowDefinition? loadWorkflowSync() {
    if (!_file.existsSync()) return null;
    try {
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is Map<String, Object?>) {
        final workflow = WorkflowDefinition.fromJson(decoded);
        final validation = const WorkflowValidator().validate(workflow);
        if (validation.isValid) return workflow;
      }
    } on Object {
      return null;
    }
    return null;
  }

  @override
  Future<void> saveWorkflow(WorkflowDefinition workflow) async {
    await _file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file.writeAsString('${encoder.convert(workflow.toJson())}\n');
  }
}

abstract interface class SubWorkflowStore {
  // 保存当前项目的本地子流程集合。
  // 调用方必须先完成 validator 校验，store 只负责稳定落盘。
  Future<void> saveSubWorkflows(Map<String, WorkflowDefinition> workflows);
}

final class NoopSubWorkflowStore implements SubWorkflowStore {
  const NoopSubWorkflowStore();

  // 测试和无持久化环境使用的空实现，不写任何文件。
  @override
  Future<void> saveSubWorkflows(
    Map<String, WorkflowDefinition> workflows,
  ) async {}
}

// 本地子流程存储，负责把 Project DSL 子流程列表保存为单个 JSON 文件。
// 读取时只恢复 validator 通过的子流程，坏文件不会污染 Runtime 真值。
final class LocalSubWorkflowStore implements SubWorkflowStore {
  const LocalSubWorkflowStore({required File file}) : _file = file;

  final File _file;

  // 同步读取本地子流程列表，供项目启动阶段恢复 snapshot。
  // 无文件、格式错误或校验失败时返回空集合，让主流程继续可用。
  Map<String, WorkflowDefinition> loadSubWorkflowsSync() {
    if (!_file.existsSync()) return const <String, WorkflowDefinition>{};
    try {
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is! Map<String, Object?>) {
        return const <String, WorkflowDefinition>{};
      }
      final workflowsJson = decoded['workflows'];
      if (workflowsJson is! List<Object?>) {
        return const <String, WorkflowDefinition>{};
      }
      final workflows = <String, WorkflowDefinition>{};
      for (final item in workflowsJson) {
        if (item is! Map<String, Object?>) continue;
        final workflow = WorkflowDefinition.fromJson(item);
        final validation = const WorkflowValidator().validate(workflow);
        if (validation.isValid) {
          workflows[workflow.id] = workflow;
        }
      }
      return Map<String, WorkflowDefinition>.unmodifiable(workflows);
    } on Object {
      return const <String, WorkflowDefinition>{};
    }
  }

  // 将子流程按 id 稳定排序后写入本地，减少无意义的文件抖动。
  // 文件只包含 Project DSL，不写设备、会话、路径或底层 payload。
  @override
  Future<void> saveSubWorkflows(
    Map<String, WorkflowDefinition> workflows,
  ) async {
    await _file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final sorted = workflows.values.toList(growable: false)
      ..sort((a, b) => a.id.compareTo(b.id));
    final payload = <String, Object?>{
      'version': 1,
      'workflows': sorted.map((workflow) => workflow.toJson()).toList(),
    };
    await _file.writeAsString('${encoder.convert(payload)}\n');
  }
}

abstract interface class SettingsStore {
  Future<void> saveSettings(StudioSettings settings);
}

final class NoopSettingsStore implements SettingsStore {
  const NoopSettingsStore();

  @override
  Future<void> saveSettings(StudioSettings settings) async {}
}

final class LocalStudioSettingsStore implements SettingsStore {
  const LocalStudioSettingsStore({required File file}) : _file = file;

  final File _file;

  StudioSettings loadSettingsSync() {
    if (!_file.existsSync()) return StudioSettings.defaults;
    try {
      final decoded = jsonDecode(_file.readAsStringSync());
      if (decoded is Map<String, Object?>) {
        return StudioSettings.fromJson(decoded);
      }
    } on Object {
      return StudioSettings.defaults;
    }
    return StudioSettings.defaults;
  }

  @override
  Future<void> saveSettings(StudioSettings settings) async {
    await _file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await _file.writeAsString('${encoder.convert(settings.toJson())}\n');
  }
}
