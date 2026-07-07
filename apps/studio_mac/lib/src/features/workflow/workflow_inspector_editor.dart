part of '../../studio_mac_workspace.dart';

// Workflow 节点编辑器状态，负责节点参数草稿、校验和保存回写。
class _NodeInspectorEditorState extends State<_NodeInspectorEditor> {
  late final TextEditingController _labelController;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _msController;
  late final TextEditingController _fromXController;
  late final TextEditingController _fromYController;
  late final TextEditingController _toXController;
  late final TextEditingController _toYController;
  late final TextEditingController _durationController;
  late final TextEditingController _textController;
  late final TextEditingController _loopCountController;
  late final TextEditingController _expressionController;
  late final TextEditingController _confidenceController;
  late final TextEditingController _maxRetriesController;
  late final TextEditingController _onErrorController;
  late final TextEditingController _workflowIdController;
  late final TextEditingController _inputMapController;
  bool _saveEvidence = true;
  String? _edgeTargetId;

  // 初始化所有节点参数控制器，并绑定草稿刷新监听。
  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _xController = TextEditingController();
    _yController = TextEditingController();
    _msController = TextEditingController();
    _fromXController = TextEditingController();
    _fromYController = TextEditingController();
    _toXController = TextEditingController();
    _toYController = TextEditingController();
    _durationController = TextEditingController();
    _textController = TextEditingController();
    _loopCountController = TextEditingController();
    _expressionController = TextEditingController();
    _confidenceController = TextEditingController();
    _maxRetriesController = TextEditingController();
    _onErrorController = TextEditingController();
    _workflowIdController = TextEditingController();
    _inputMapController = TextEditingController();
    _syncFromNodes();
    for (final controller in _draftControllers) {
      controller.addListener(_handleDraftChanged);
    }
  }

  // 节点或参数变化时同步草稿，并保持连接候选有效。
  @override
  void didUpdateWidget(covariant _NodeInspectorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.id != widget.node.id ||
        oldWidget.node.toJson().toString() != widget.node.toJson().toString()) {
      _syncFromNodes();
    }
    _syncEdgeTarget();
  }

  // 释放所有输入控制器，避免 Inspector 频繁切换节点时泄漏监听。
  @override
  void dispose() {
    for (final controller in _draftControllers) {
      controller
        ..removeListener(_handleDraftChanged)
        ..dispose();
    }
    super.dispose();
  }

  // 收拢所有草稿控制器，生命周期代码只维护一份列表。
  List<TextEditingController> get _draftControllers => [
    _labelController,
    _xController,
    _yController,
    _msController,
    _fromXController,
    _fromYController,
    _toXController,
    _toYController,
    _durationController,
    _textController,
    _loopCountController,
    _expressionController,
    _confidenceController,
    _maxRetriesController,
    _onErrorController,
    _workflowIdController,
    _inputMapController,
  ];

  // 输入框变化后刷新草稿状态和保存按钮可用性。
  void _handleDraftChanged() {
    setState(() {});
  }

  // 渲染节点编辑器，具体字段、连接和动作由分片组件承载。
  @override
  Widget build(BuildContext context) {
    final draft = _nodeDraftFromControllers();
    final dirty =
        draft.node.toJson().toString() != widget.node.toJson().toString();
    final graphBusy = widget.savingGraphEdit || widget.saving;
    final canSave =
        dirty && draft.error == null && !widget.locked && !widget.saving;
    final canInsert =
        !widget.locked &&
        !graphBusy &&
        widget.node.type != WorkflowNodeType.end;
    final canDelete =
        !widget.locked &&
        !graphBusy &&
        widget.node.type != WorkflowNodeType.start &&
        widget.node.type != WorkflowNodeType.end;
    final canDuplicate = canDelete;
    final edgeTargets = _edgeTargetCandidates();
    final canAddEdge =
        !widget.locked &&
        !graphBusy &&
        widget.node.type != WorkflowNodeType.end &&
        _edgeTargetId != null &&
        widget.onAddEdge != null;
    final canRemoveEdge =
        !widget.locked &&
        !graphBusy &&
        widget.node.next.length > 1 &&
        widget.onRemoveEdge != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: StudioColors.border),
        const SizedBox(height: 8),
        const Text(
          '节点检查',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        _InspectorRow(label: '当前', value: widget.node.label),
        _InspectorRow(
          label: '类型',
          value: _workflowNodeTypeLabel(widget.node.type),
        ),
        const SizedBox(height: 10),
        _NodeInspectorEvidenceCard(
          summary: widget.evidenceSummary,
          loading: widget.loadingEvidence,
          latestRun: widget.latestRun,
          onOpenMonitor: widget.onOpenEvidence,
        ),
        if (widget.diagnostics.isNotEmpty) ...[
          const SizedBox(height: 10),
          _NodeInspectorDiagnostics(
            workflow: widget.workflow,
            diagnostics: widget.diagnostics,
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('node-inspector-label'),
          controller: _labelController,
          enabled: !widget.locked && !widget.saving,
          decoration: _inspectorInputDecoration('名称'),
        ),
        _NodeInspectorParameterFields(
          workflow: widget.workflow,
          node: widget.node,
          locked: widget.locked,
          saving: widget.saving,
          xController: _xController,
          yController: _yController,
          msController: _msController,
          fromXController: _fromXController,
          fromYController: _fromYController,
          toXController: _toXController,
          toYController: _toYController,
          durationController: _durationController,
          textController: _textController,
          loopCountController: _loopCountController,
          expressionController: _expressionController,
          confidenceController: _confidenceController,
          maxRetriesController: _maxRetriesController,
          onErrorController: _onErrorController,
          workflowIdController: _workflowIdController,
          inputMapController: _inputMapController,
          saveEvidence: _saveEvidence,
          onSaveEvidenceChanged: (value) {
            setState(() => _saveEvidence = value);
          },
          subWorkflows: widget.subWorkflows,
          onAddStarterSubWorkflow: widget.onAddStarterSubWorkflow,
          onAddCurrentAsSubWorkflow: widget.onAddCurrentAsSubWorkflow,
          onDeleteSubWorkflow: widget.onDeleteSubWorkflow,
        ),
        const SizedBox(height: 12),
        _NodeInspectorDraftStatus(locked: widget.locked, error: draft.error),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('node-inspector-save'),
            onPressed: canSave ? () => widget.onSave(draft.node) : null,
            icon: widget.saving
                ? const Icon(Icons.hourglass_top_outlined, size: 18)
                : const Icon(Icons.save_outlined, size: 18),
            label: const Text('保存节点'),
          ),
        ),
        const SizedBox(height: 16),
        _NodeInspectorConnections(
          workflow: widget.workflow,
          node: widget.node,
          edgeTargets: edgeTargets,
          edgeTargetId: _edgeTargetId,
          canAddEdge: canAddEdge,
          canRemoveEdge: canRemoveEdge,
          onEdgeTargetChanged: (value) => setState(() => _edgeTargetId = value),
          onAddEdge: widget.onAddEdge,
          onRemoveEdge: widget.onRemoveEdge,
        ),
        const SizedBox(height: 16),
        _NodeInspectorCanvasActions(
          canInsert: canInsert,
          canDuplicate: canDuplicate,
          canDelete: canDelete,
          onInsertNodes: widget.onInsertNodes,
          onDuplicateNodes: widget.onDuplicateNodes,
          onDeleteNodes: widget.onDeleteNodes,
        ),
      ],
    );
  }
}
