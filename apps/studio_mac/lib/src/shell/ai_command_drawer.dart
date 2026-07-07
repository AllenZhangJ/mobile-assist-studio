part of '../studio_mac_workspace.dart';

// 智能工具抽屉，承载 Batch 8 的可见入口。
// 抽屉只调用 Runtime 受控工具，不保存流程、不写目标、不执行设备动作。
class _AiCommandDrawer extends StatefulWidget {
  const _AiCommandDrawer({required this.controller, required this.snapshot});

  final StudioRuntimeController controller;
  final StudioRuntimeSnapshot snapshot;

  @override
  State<_AiCommandDrawer> createState() => _AiCommandDrawerState();
}

// 智能抽屉状态，维护当前调用结果和短暂 loading。
class _AiCommandDrawerState extends State<_AiCommandDrawer> {
  AiToolInvocationResult? _result;
  String? _busyToolId;
  late List<AiToolAuditEntry> _auditLog;

  @override
  void initState() {
    super.initState();
    _auditLog = widget.controller.snapshot.aiAuditLog.isEmpty
        ? widget.snapshot.aiAuditLog
        : widget.controller.snapshot.aiAuditLog;
  }

  // 渲染右侧智能抽屉。
  // 内容使用滚动布局，避免结果 JSON 或审计列表撑爆桌面窗口。
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('ai-command-drawer'),
        width: 440,
        height: double.infinity,
        decoration: BoxDecoration(
          color: StudioColors.panel,
          border: const Border(left: BorderSide(color: StudioColors.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: 26,
              offset: const Offset(-10, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              _AiDrawerHeader(onClose: () => Navigator.of(context).pop()),
              const Divider(height: 1, color: StudioColors.border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    const _AiBoundaryCard(),
                    const SizedBox(height: 14),
                    _AiToolGrid(
                      busyToolId: _busyToolId,
                      onInvoke: _invoke,
                      onRunHandoff: _confirmRunHandoff,
                    ),
                    const SizedBox(height: 14),
                    _AiResultCard(result: _result, onCopy: _copyResult),
                    const SizedBox(height: 14),
                    _AiAuditCard(entries: _auditLog),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 调用 Runtime AI 工具，并把结果留在抽屉内复盘。
  Future<void> _invoke(
    String toolId, {
    Map<String, Object?> arguments = const <String, Object?>{},
    bool userConfirmed = false,
  }) async {
    if (_busyToolId != null) return;
    setState(() => _busyToolId = toolId);
    try {
      final result = await widget.controller.invokeAiTool(
        AiToolInvocationRequest(
          toolId: toolId,
          arguments: _argumentsFor(toolId, arguments),
          userConfirmed: userConfirmed,
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _auditLog = widget.controller.snapshot.aiAuditLog;
      });
    } finally {
      if (mounted) {
        setState(() => _busyToolId = null);
      }
    }
  }

  // 为需要运行记录的工具补最近运行 ID，缺失时交由 Runtime 安全降级。
  Map<String, Object?> _argumentsFor(
    String toolId,
    Map<String, Object?> arguments,
  ) {
    if (toolId != 'explainRunFailure' && toolId != 'suggestTemplateFix') {
      return arguments;
    }
    final controllerRuns = widget.controller.snapshot.runHistory.recentRuns;
    final previewRuns = widget.snapshot.runHistory.recentRuns;
    final runId = controllerRuns.isNotEmpty
        ? controllerRuns.first.runId
        : previewRuns.isNotEmpty
        ? previewRuns.first.runId
        : null;
    if (runId == null) return arguments;
    return <String, Object?>{...arguments, 'runId': runId};
  }

  // 危险工具只做用户确认后的 Runtime 交接，不直接运行流程。
  Future<void> _confirmRunHandoff() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: StudioColors.panel,
          title: const Text('确认交接'),
          content: const Text('智能不会直接运行，只生成交接结果。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _invoke('runWorkflow', userConfirmed: true);
  }

  // 复制当前结果的脱敏 JSON。
  Future<void> _copyResult() async {
    final result = _result;
    if (result == null) return;
    const encoder = JsonEncoder.withIndent('  ');
    await _copyPlainText(
      context,
      text: '${encoder.convert(result.toJson())}\n',
      message: '已复制结果',
    );
  }
}

// 智能抽屉头部，显示短标题和关闭入口。
class _AiDrawerHeader extends StatelessWidget {
  const _AiDrawerHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: StudioColors.cyan.withValues(alpha: 0.12),
              border: Border.all(
                color: StudioColors.cyan.withValues(alpha: 0.34),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              color: StudioColors.cyan,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '智能',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  '建议、草稿、解释',
                  style: TextStyle(color: StudioColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '关闭',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

// 智能边界卡片，先展示用户能理解的安全边界。
class _AiBoundaryCard extends StatelessWidget {
  const _AiBoundaryCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.cyan.withValues(alpha: 0.07),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('边界', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text(
              '只读和草稿可直接生成；涉及运行必须确认，且只交给主按钮。',
              style: TextStyle(color: StudioColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

// 智能工具网格，提供当前 Batch 8 的安全入口。
class _AiToolGrid extends StatelessWidget {
  const _AiToolGrid({
    required this.busyToolId,
    required this.onInvoke,
    required this.onRunHandoff,
  });

  final String? busyToolId;
  final Future<void> Function(
    String toolId, {
    Map<String, Object?> arguments,
    bool userConfirmed,
  })
  onInvoke;
  final Future<void> Function() onRunHandoff;

  @override
  Widget build(BuildContext context) {
    final items = <_AiToolAction>[
      _AiToolAction(
        id: 'readCurrentScreenSummary',
        title: '读屏',
        description: '看当前状态',
        icon: Icons.visibility_outlined,
      ),
      _AiToolAction(
        id: 'proposeWorkflowDraft',
        title: '草稿',
        description: '生成流程',
        icon: Icons.account_tree_outlined,
      ),
      _AiToolAction(
        id: 'suggestTarget',
        title: '目标',
        description: '建议目标',
        icon: Icons.ads_click_outlined,
      ),
      _AiToolAction(
        id: 'suggestLocator',
        title: '定位',
        description: '建议短语',
        icon: Icons.center_focus_strong_outlined,
      ),
      _AiToolAction(
        id: 'explainRunFailure',
        title: '释失败',
        description: '读本地证据',
        icon: Icons.manage_search_outlined,
      ),
      _AiToolAction(
        id: 'suggestTemplateFix',
        title: '修模板',
        description: '看视觉证据',
        icon: Icons.tune_outlined,
      ),
      _AiToolAction(
        id: 'runWorkflow',
        title: '交接',
        description: '确认后交给主按钮',
        icon: Icons.lock_outline,
        requiresConfirmation: true,
      ),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          _AiToolButton(
            item: item,
            busy: busyToolId == item.id,
            disabled: busyToolId != null && busyToolId != item.id,
            onPressed: item.requiresConfirmation
                ? onRunHandoff
                : () => onInvoke(item.id),
          ),
      ],
    );
  }
}

// 单个智能工具动作定义。
class _AiToolAction {
  const _AiToolAction({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.requiresConfirmation = false,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool requiresConfirmation;
}

// 智能工具按钮，固定尺寸防止中文文案撑开网格。
class _AiToolButton extends StatelessWidget {
  const _AiToolButton({
    required this.item,
    required this.busy,
    required this.disabled,
    required this.onPressed,
  });

  final _AiToolAction item;
  final bool busy;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      height: 88,
      child: OutlinedButton(
        key: ValueKey('ai-tool-${item.id}'),
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(
            color: item.requiresConfirmation
                ? StudioColors.amber.withValues(alpha: 0.42)
                : StudioColors.border,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              busy ? Icons.more_horiz : item.icon,
              size: 18,
              color: item.requiresConfirmation
                  ? StudioColors.amber
                  : StudioColors.cyan,
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 2),
            Text(
              item.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: StudioColors.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// 智能结果卡片，展示短结果和可复制脱敏 JSON。
class _AiResultCard extends StatelessWidget {
  const _AiResultCard({required this.result, required this.onCopy});

  final AiToolInvocationResult? result;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final result = this.result;
    return _AiSectionCard(
      title: '结果',
      trailing: result == null
          ? null
          : IconButton(
              tooltip: '复制结果',
              onPressed: () => unawaited(onCopy()),
              icon: const Icon(Icons.copy_all_outlined, size: 18),
            ),
      child: result == null
          ? const Text('暂无结果', style: TextStyle(color: StudioColors.muted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AiChip(label: _aiStatusLabel(result.status)),
                    _AiChip(label: result.toolId),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  result.message,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: const BoxConstraints(maxHeight: 210),
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.20),
                    border: Border.all(color: StudioColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(result.toJson()),
                      style: const TextStyle(
                        color: StudioColors.muted,
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// 智能审计卡片，展示最近 AI 行为。
class _AiAuditCard extends StatelessWidget {
  const _AiAuditCard({required this.entries});

  final List<AiToolAuditEntry> entries;

  @override
  Widget build(BuildContext context) {
    final visible = entries.reversed.take(6).toList(growable: false);
    return _AiSectionCard(
      title: '审计',
      child: visible.isEmpty
          ? const Text('暂无记录', style: TextStyle(color: StudioColors.muted))
          : Column(
              children: [
                for (final entry in visible) _AiAuditRow(entry: entry),
              ],
            ),
    );
  }
}

// 单条智能审计记录。
class _AiAuditRow extends StatelessWidget {
  const _AiAuditRow({required this.entry});

  final AiToolAuditEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _aiRiskIcon(entry.risk),
            size: 16,
            color: _aiRiskColor(entry.risk),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_aiToolLabel(entry.toolId)} · ${_aiStatusLabel(entry.status)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: StudioColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 智能抽屉通用分区卡片。
class _AiSectionCard extends StatelessWidget {
  const _AiSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.panelSoft,
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

// 智能结果胶囊，保持短文案。
class _AiChip extends StatelessWidget {
  const _AiChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: StudioColors.cyan.withValues(alpha: 0.08),
        border: Border.all(color: StudioColors.cyan.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// 把 Runtime AI 状态转为短中文。
String _aiStatusLabel(AiToolInvocationStatus status) {
  switch (status) {
    case AiToolInvocationStatus.completed:
      return '完成';
    case AiToolInvocationStatus.needsConfirmation:
      return '待确认';
    case AiToolInvocationStatus.blocked:
      return '已阻止';
    case AiToolInvocationStatus.unavailable:
      return '不可用';
    case AiToolInvocationStatus.handoffRequired:
      return '需交接';
  }
}

// 把工具 ID 转为用户能读的短中文。
String _aiToolLabel(String toolId) {
  switch (toolId) {
    case 'readCurrentScreenSummary':
      return '读屏';
    case 'proposeWorkflowDraft':
      return '草稿';
    case 'explainRunFailure':
      return '释失败';
    case 'suggestTarget':
      return '目标';
    case 'suggestLocator':
      return '定位';
    case 'suggestTemplateFix':
      return '修模板';
    case 'runWorkflow':
      return '交接';
    default:
      return '工具';
  }
}

// 根据风险返回审计图标。
IconData _aiRiskIcon(AiToolRisk risk) {
  switch (risk) {
    case AiToolRisk.readOnly:
      return Icons.visibility_outlined;
    case AiToolRisk.draft:
      return Icons.edit_note_outlined;
    case AiToolRisk.requiresConfirmation:
      return Icons.lock_outline;
    case AiToolRisk.forbidden:
      return Icons.block_outlined;
  }
}

// 根据风险返回审计颜色。
Color _aiRiskColor(AiToolRisk risk) {
  switch (risk) {
    case AiToolRisk.readOnly:
    case AiToolRisk.draft:
      return StudioColors.cyan;
    case AiToolRisk.requiresConfirmation:
      return StudioColors.amber;
    case AiToolRisk.forbidden:
      return StudioColors.red;
  }
}
