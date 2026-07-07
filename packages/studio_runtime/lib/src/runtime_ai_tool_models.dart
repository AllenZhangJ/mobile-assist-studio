part of '../studio_runtime.dart';

// AiToolRisk 表示 AI 工具调用风险等级。
// 危险工具必须经过用户确认，不得自动执行。
enum AiToolRisk { readOnly, draft, requiresConfirmation, forbidden }

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
        id: 'runWorkflow',
        label: '运行流程',
        risk: AiToolRisk.requiresConfirmation,
        description: '危险动作，必须由用户确认后交给 Runtime。',
      ),
    ],
  );
}
