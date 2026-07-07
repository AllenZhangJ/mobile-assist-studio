part of '../../studio_mac_workspace.dart';

// Workflow 页面入口与页面级状态，负责协调画布、源码、检查和 Inspector 的整体交互。
class _WorkflowPage extends StatefulWidget {
  const _WorkflowPage({
    required this.snapshot,
    required this.controller,
    required this.onNavigate,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final ValueChanged<int> onNavigate;

  @override
  State<_WorkflowPage> createState() => _WorkflowPageState();
}

// Workflow 页面状态只保留页面级数据和布局编排，具体动作由同目录 actions 分片承载。
class _WorkflowPageState extends State<_WorkflowPage> {
  _WorkflowTab _selectedTab = _WorkflowTab.visual;
  String? _selectedNodeId;
  Set<String> _selectedNodeIds = const <String>{};
  _WorkflowCanvasClipboard? _canvasClipboard;
  _WorkflowSelectedEdge? _selectedEdge;
  final _WorkflowHistoryController _workflowHistory =
      _WorkflowHistoryController();
  final FocusNode _workflowCanvasFocusNode = FocusNode(debugLabel: '流程画布');
  final ValueNotifier<_WorkflowCanvasViewportCommand?>
  _workflowCanvasViewportCommand =
      ValueNotifier<_WorkflowCanvasViewportCommand?>(null);
  late final TextEditingController _sourceController;
  late String _lastSyncedSource;
  bool _sourceDirty = false;
  bool _savingSource = false;
  bool _savingNodes = false;
  bool _savingGraphEdit = false;
  Map<String, _WorkflowNodeEvidenceSummary> _latestNodeEvidenceByNodeId =
      const {};
  String? _latestNodeEvidenceKey;
  bool _loadingLatestNodeEvidence = false;
  int _latestNodeEvidenceRequestToken = 0;

  // 初始化源码编辑器与历史同步基线，避免首次进入页面就被标记为脏数据。
  @override
  void initState() {
    super.initState();
    _lastSyncedSource = _workflowSourceText(widget.snapshot.workflow);
    _sourceController = TextEditingController(text: _lastSyncedSource);
    _sourceController.addListener(_handleSourceChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshWorkflowNodeEvidence());
    });
  }

  // 接收 Runtime 新快照后同步源码、选区和连线状态。
  // 若被选节点或连线已不存在，立即清掉本地选择，避免 Inspector 指向空对象。
  @override
  void didUpdateWidget(covariant _WorkflowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSource = _workflowSourceText(widget.snapshot.workflow);
    if (nextSource != _lastSyncedSource && !_sourceDirty) {
      _lastSyncedSource = nextSource;
      _sourceController.text = nextSource;
    }
    final selectedNodeId = _selectedNodeId;
    if (selectedNodeId != null &&
        !widget.snapshot.workflow.nodes.any(
          (node) => node.id == selectedNodeId,
        )) {
      _selectedNodeId = null;
    }
    final validNodesIds = widget.snapshot.workflow.nodes
        .map((node) => node.id)
        .toSet();
    final nextSelectedNodesIds = _selectedNodeIds
        .where(validNodesIds.contains)
        .toSet();
    if (nextSelectedNodesIds.length != _selectedNodeIds.length) {
      _selectedNodeIds = nextSelectedNodesIds;
    }
    final selectedEdge = _selectedEdge;
    if (selectedEdge != null &&
        !_workflowHasSelectedEdge(widget.snapshot.workflow, selectedEdge)) {
      _selectedEdge = null;
    }
    unawaited(_refreshWorkflowNodeEvidence());
  }

  // 释放源码编辑器和画布焦点，防止页面切换后仍保留监听。
  @override
  void dispose() {
    _sourceController
      ..removeListener(_handleSourceChanged)
      ..dispose();
    _workflowCanvasViewportCommand.dispose();
    _workflowCanvasFocusNode.dispose();
    super.dispose();
  }

  // 为同库动作分片提供受控状态更新入口，避免 extension 直接触碰 State 的受保护方法。
  void _updateWorkflowPageState(VoidCallback update) => setState(update);

  // 渲染 Workflow 主页面，左侧是画布/源码/检查，右侧是 Inspector。
  // 页面只协调状态和命令，具体控件已下沉到各自 part 文件。
  @override
  Widget build(BuildContext context) {
    final workflow = widget.snapshot.workflow;
    final validation = _workflowProjectValidation(
      workflow,
      widget.snapshot.subWorkflows,
    );
    final diagnosticsByNodeId = _workflowDiagnosticsByNodesId(validation);
    final draft = _parseWorkflowSource(
      _sourceController.text,
      widget.snapshot.subWorkflows,
    );
    final selectedNode = _selectedNode(workflow, _selectedNodeId);
    final selectedNodes = workflow.nodes
        .where((node) => _selectedNodeIds.contains(node.id))
        .toList(growable: false);
    final graphLocked = _workflowGraphEditLocked;
    final graphLockReason = _workflowGraphLockReason;
    final canEditGraph =
        widget.snapshot.runStatus == RunStatus.idle &&
        !_sourceDirty &&
        !_savingGraphEdit &&
        !_savingSource;
    final canOpenExecute = _canOpenWorkflowExecute(validation);
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _buildWorkflowMainPanel(
            context: context,
            workflow: workflow,
            validation: validation,
            draft: draft,
            diagnosticsByNodeId: diagnosticsByNodeId,
            selectedNode: selectedNode,
            graphLocked: graphLocked,
            graphLockReason: graphLockReason,
            canEditGraph: canEditGraph,
            canOpenExecute: canOpenExecute,
            openExecuteTooltip: _workflowOpenExecuteTooltip(validation),
          ),
          const SizedBox(width: 14),
          _buildWorkflowInspectorPanel(
            workflow: workflow,
            validation: validation,
            diagnosticsByNodeId: diagnosticsByNodeId,
            selectedNode: selectedNode,
            selectedNodes: selectedNodes,
          ),
        ],
      ),
    );
  }
}
