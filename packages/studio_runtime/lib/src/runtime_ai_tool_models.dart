part of '../studio_runtime.dart';

// AiToolRisk 表示 AI 工具调用风险等级。
// 危险工具必须经过用户确认，不得自动执行。
enum AiToolRisk { readOnly, draft, requiresConfirmation, forbidden }

// AiToolDecisionStatus 表示权限门禁结果。
// 需要确认和阻断都不会进入工具执行逻辑。
enum AiToolDecisionStatus { allowed, needsConfirmation, blocked }

// AiToolInvocationStatus 表示一次工具调用的最终状态。
// handoffRequired 表示用户已确认，但仍需交给 Runtime 主命令执行。
enum AiToolInvocationStatus {
  completed,
  needsConfirmation,
  blocked,
  unavailable,
  handoffRequired,
}

// AiToolDefinition 描述一个 V4 AI / MCP-compatible 工具。
// 工具定义只表达权限和输入，不直接持有执行逻辑。
final class AiToolDefinition {
  // 创建 AI 工具定义。
  const AiToolDefinition({
    required this.id,
    required this.label,
    required this.risk,
    required this.description,
  });

  final String id;
  final String label;
  final AiToolRisk risk;
  final String description;

  // 判断工具是否可在无确认下自动调用。
  bool get canAutoRun =>
      risk == AiToolRisk.readOnly || risk == AiToolRisk.draft;
}

// AiToolRegistry 是可用 AI 工具的只读注册表。
// 它用于限制 AI 能力边界，避免出现隐藏执行入口。
final class AiToolRegistry {
  // 创建工具注册表。
  const AiToolRegistry({required this.tools});

  final List<AiToolDefinition> tools;

  // 按 ID 查找工具定义。
  AiToolDefinition? toolById(String id) {
    for (final tool in tools) {
      if (tool.id == id) return tool;
    }
    return null;
  }

  static const v4Default = AiToolRegistry(
    tools: <AiToolDefinition>[
      AiToolDefinition(
        id: 'readCurrentScreenSummary',
        label: '读屏摘要',
        risk: AiToolRisk.readOnly,
        description: '读取当前截图和检查摘要的脱敏信息。',
      ),
      AiToolDefinition(
        id: 'proposeWorkflowDraft',
        label: '生成草稿',
        risk: AiToolRisk.draft,
        description: '生成流程草稿，不直接保存或运行。',
      ),
      AiToolDefinition(
        id: 'explainRunFailure',
        label: '解释失败',
        risk: AiToolRisk.readOnly,
        description: '基于本地日志和证据解释失败原因。',
      ),
      AiToolDefinition(
        id: 'suggestTarget',
        label: '建议目标',
        risk: AiToolRisk.draft,
        description: '根据截图或元素树建议目标定义。',
      ),
      AiToolDefinition(
        id: 'suggestLocator',
        label: '建议定位',
        risk: AiToolRisk.draft,
        description: '根据脱敏元素树建议可读定位短语法。',
      ),
      AiToolDefinition(
        id: 'suggestTemplateFix',
        label: '修模板',
        risk: AiToolRisk.draft,
        description: '根据视觉失败证据建议模板修复方向。',
      ),
      AiToolDefinition(
        id: 'runWorkflow',
        label: '运行流程',
        risk: AiToolRisk.requiresConfirmation,
        description: '危险动作，必须由用户确认后交给 Runtime。',
      ),
    ],
  );
}

// AiToolInvocationRequest 是一次 AI / MCP 工具调用请求。
// 参数只能是结构化 JSON，Runtime 会再次脱敏后再进入结果。
final class AiToolInvocationRequest {
  // 创建工具调用请求。
  const AiToolInvocationRequest({
    required this.toolId,
    this.arguments = const <String, Object?>{},
    this.userConfirmed = false,
  });

  final String toolId;
  final Map<String, Object?> arguments;
  final bool userConfirmed;
}

// AiToolPermissionDecision 是权限门禁的稳定输出。
// UI 和测试可以用它判断是否需要弹出确认。
final class AiToolPermissionDecision {
  // 创建权限决策。
  const AiToolPermissionDecision({
    required this.status,
    required this.message,
    this.tool,
  });

  final AiToolDecisionStatus status;
  final String message;
  final AiToolDefinition? tool;

  // 判断当前请求是否可进入受控工具执行。
  bool get isAllowed => status == AiToolDecisionStatus.allowed;
}

// AiToolPermissionGate 统一判断 AI 工具权限。
// 所有 AI 调用必须先过门禁，避免隐藏执行入口。
final class AiToolPermissionGate {
  // 创建权限门禁。
  const AiToolPermissionGate({this.registry = AiToolRegistry.v4Default});

  final AiToolRegistry registry;

  // 根据工具风险和用户确认状态生成权限决策。
  AiToolPermissionDecision decide(AiToolInvocationRequest request) {
    final tool = registry.toolById(request.toolId.trim());
    if (tool == null) {
      return const AiToolPermissionDecision(
        status: AiToolDecisionStatus.blocked,
        message: '未知工具，已阻止。',
      );
    }

    switch (tool.risk) {
      case AiToolRisk.readOnly:
      case AiToolRisk.draft:
        return AiToolPermissionDecision(
          status: AiToolDecisionStatus.allowed,
          message: '允许调用。',
          tool: tool,
        );
      case AiToolRisk.requiresConfirmation:
        if (!request.userConfirmed) {
          return AiToolPermissionDecision(
            status: AiToolDecisionStatus.needsConfirmation,
            message: '需要用户确认。',
            tool: tool,
          );
        }
        return AiToolPermissionDecision(
          status: AiToolDecisionStatus.allowed,
          message: '用户已确认。',
          tool: tool,
        );
      case AiToolRisk.forbidden:
        return AiToolPermissionDecision(
          status: AiToolDecisionStatus.blocked,
          message: '该工具不允许使用。',
          tool: tool,
        );
    }
  }
}

// AiToolInvocationResult 是一次工具调用的安全结果。
// output 不包含截图 base64、完整路径、设备号或长 session。
final class AiToolInvocationResult {
  // 创建工具调用结果。
  const AiToolInvocationResult({
    required this.callId,
    required this.toolId,
    required this.status,
    required this.message,
    required this.at,
    this.output = const <String, Object?>{},
  });

  final String callId;
  final String toolId;
  final AiToolInvocationStatus status;
  final String message;
  final DateTime at;
  final Map<String, Object?> output;

  // 输出可复制的脱敏 JSON。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'callId': _sanitizeReportText(callId),
      'toolId': _sanitizeReportText(toolId),
      'status': status.name,
      'message': _sanitizeReportText(message),
      'at': at.toIso8601String(),
      'output': _sanitizeAiJson(output),
    };
  }
}

// AiToolAuditEntry 是 AI 行为日志。
// 它只记录调用摘要，不保存用户输入中的敏感大字段。
final class AiToolAuditEntry {
  // 创建 AI 行为日志。
  const AiToolAuditEntry({
    required this.callId,
    required this.toolId,
    required this.risk,
    required this.status,
    required this.message,
    required this.userConfirmed,
    required this.at,
  });

  final String callId;
  final String toolId;
  final AiToolRisk risk;
  final AiToolInvocationStatus status;
  final String message;
  final bool userConfirmed;
  final DateTime at;

  // 输出脱敏 JSON，供 Monitor 或 Command Center 展示。
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'callId': _sanitizeReportText(callId),
      'toolId': _sanitizeReportText(toolId),
      'risk': risk.name,
      'status': status.name,
      'message': _sanitizeReportText(message),
      'userConfirmed': userConfirmed,
      'at': at.toIso8601String(),
    };
  }
}

// _sanitizeAiJson 递归脱敏 AI 工具输出。
// 截图、口令、token 等大字段和敏感字段只返回占位说明。
Object? _sanitizeAiJson(Object? value) {
  if (value == null || value is num || value is bool) return value;
  if (value is String) return _sanitizeReportText(value);
  if (value is List<Object?>) {
    return value.map(_sanitizeAiJson).toList(growable: false);
  }
  if (value is Map<String, Object?>) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = _sanitizeReportText(entry.key);
      if (_aiKeyLooksSensitive(key)) {
        result[key] = '[已隐藏]';
      } else {
        result[key] = _sanitizeAiJson(entry.value);
      }
    }
    return result;
  }
  return _sanitizeReportText(value.toString());
}

// _aiKeyLooksSensitive 判断 AI 输出字段是否应隐藏。
// 默认不让截图、密钥和认证字段进入可复制结果。
bool _aiKeyLooksSensitive(String key) {
  final normalized = key.toLowerCase();
  return normalized.contains('screenshotbase64') ||
      normalized.contains('imagebase64') ||
      normalized.contains('password') ||
      normalized.contains('token') ||
      normalized.contains('secret') ||
      normalized == 'base64';
}
