part of '../../studio_mac_workspace.dart';

// Inspector 流程辅助面板，把当前可读元素沉淀为目标和 Tap 节点。
class _InspectorWorkflowAssistPanel extends StatefulWidget {
  const _InspectorWorkflowAssistPanel({
    required this.snapshot,
    required this.controller,
    required this.onNavigate,
  });

  final StudioRuntimeSnapshot snapshot;
  final StudioRuntimeController controller;
  final ValueChanged<int> onNavigate;

  @override
  State<_InspectorWorkflowAssistPanel> createState() =>
      _InspectorWorkflowAssistPanelState();
}

class _InspectorWorkflowAssistPanelState
    extends State<_InspectorWorkflowAssistPanel> {
  bool _saving = false;

  // 渲染建流程入口；只在空闲且找到可读元素时允许保存。
  @override
  Widget build(BuildContext context) {
    final candidate = _inspectorWorkflowCandidate(
      widget.snapshot.inspectorSnapshot?.rootElement,
    );
    final canCreate =
        !_saving &&
        candidate != null &&
        widget.snapshot.runStatus == RunStatus.idle &&
        widget.snapshot.mobileRuntime.resourceState !=
            MobileResourceState.diagnosing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudioColors.panel.withValues(alpha: 0.72),
        border: Border.all(color: StudioColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '建流程',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _CommandButton(
                controlKey: const ValueKey('device-inspector-create-tap-node'),
                label: _saving ? '保存中' : '加点击',
                icon: Icons.add_task_outlined,
                onPressed: canCreate ? () => _createTapNode(candidate) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _inspectorWorkflowAssistSummary(widget.snapshot, candidate),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: StudioColors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }

  // 创建 selector 目标并插入 Tap 节点；全过程只写本地项目真源。
  Future<void> _createTapNode(_InspectorWorkflowCandidate candidate) async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    final target = _targetFromInspectorCandidate(candidate);
    final targetSaved = await widget.controller.upsertTarget(target);
    if (!mounted) return;
    if (!targetSaved) {
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(content: Text('目标未存。')));
      return;
    }

    final workflow = widget.controller.snapshot.workflow;
    final anchorNodeId = _inspectorWorkflowAnchorNodeId(workflow);
    if (anchorNodeId == null) {
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(content: Text('流程不可改。')));
      return;
    }

    final insertedNode = _tapNodeForInspectorTarget(workflow, target);
    final updatedWorkflow = _workflowInsertingNodesAfter(
      workflow,
      anchorNodeId: anchorNodeId,
      insertedNodes: insertedNode,
    );
    final workflowSaved = await widget.controller.updateWorkflow(
      updatedWorkflow,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(content: Text(workflowSaved ? '已加到流程。' : '节点未加。')),
    );
    if (workflowSaved) widget.onNavigate(3);
  }
}

// Inspector 候选元素，只保留用户可读名称和安全 selector。
final class _InspectorWorkflowCandidate {
  const _InspectorWorkflowCandidate({
    required this.label,
    required this.selector,
  });

  final String label;
  final String selector;
}

// 从元素树中选择第一个可读元素，避免生成过宽的 type selector。
_InspectorWorkflowCandidate? _inspectorWorkflowCandidate(
  InspectorElementSummary? root,
) {
  if (root == null) return null;
  for (final element in _flattenInspectorElements(root)) {
    final label = _safeInspectorText(element.label);
    if (label != null) {
      return _InspectorWorkflowCandidate(
        label: label,
        selector: 'label=$label',
      );
    }
    final value = _safeInspectorText(element.value);
    if (value != null) {
      return _InspectorWorkflowCandidate(
        label: value,
        selector: 'value=$value',
      );
    }
  }
  return null;
}

// 深度优先展开元素树，保持和界面展示顺序一致。
Iterable<InspectorElementSummary> _flattenInspectorElements(
  InspectorElementSummary root,
) sync* {
  yield root;
  for (final child in root.children) {
    yield* _flattenInspectorElements(child);
  }
}

// 生成 selector target；ID 仅使用安全字符并追加时间，避免覆盖旧目标。
RuntimeTargetDefinition _targetFromInspectorCandidate(
  _InspectorWorkflowCandidate candidate,
) {
  final suffix = DateTime.now().toUtc().millisecondsSinceEpoch;
  return RuntimeTargetDefinition(
    id: '${_safeInspectorAssetId(candidate.label)}_$suffix',
    kind: RuntimeTargetKind.selector,
    label: candidate.label,
    payload: <String, Object?>{'selector': candidate.selector},
  );
}

// 构造 Tap targetRef 节点，点击执行仍由 Runtime 解析目标后串行执行。
WorkflowNode _tapNodeForInspectorTarget(
  WorkflowDefinition workflow,
  RuntimeTargetDefinition target,
) {
  return WorkflowNode(
    id: _uniqueNodesId(workflow, 'tap_target'),
    type: WorkflowNodeType.tap,
    label: '点${target.label}',
    parameters: <String, Object?>{
      'label': '点${target.label}',
      'targetRef': target.id,
      'durationMs': 80,
    },
  );
}

// 选择插入锚点；优先入口节点，入口不可用时找首个可连接节点。
String? _inspectorWorkflowAnchorNodeId(WorkflowDefinition workflow) {
  final entry = _selectedNode(workflow, workflow.entryNodesId);
  if (entry != null &&
      entry.type == WorkflowNodeType.start &&
      entry.next.length <= 1) {
    return entry.id;
  }
  for (final node in workflow.nodes) {
    if (node.type == WorkflowNodeType.start && node.next.length <= 1) {
      return node.id;
    }
  }
  for (final node in workflow.nodes) {
    if (_inspectorWorkflowCanAnchor(node)) return node.id;
  }
  return null;
}

// 只允许在线性节点后自动插入，避免误改条件、循环或错误分支结构。
bool _inspectorWorkflowCanAnchor(WorkflowNode node) {
  if (node.next.length > 1) return false;
  return switch (node.type) {
    WorkflowNodeType.tap ||
    WorkflowNodeType.wait ||
    WorkflowNodeType.swipe ||
    WorkflowNodeType.input ||
    WorkflowNodeType.snapshot ||
    WorkflowNodeType.subWorkflow => true,
    _ => false,
  };
}

// 建流程面板短说明，隐藏 selector 和底层 XML 细节。
String _inspectorWorkflowAssistSummary(
  StudioRuntimeSnapshot snapshot,
  _InspectorWorkflowCandidate? candidate,
) {
  if (snapshot.runStatus != RunStatus.idle) return '运行中先不改流程。';
  if (snapshot.mobileRuntime.resourceState == MobileResourceState.diagnosing) {
    return '正在检查界面。';
  }
  if (snapshot.inspectorSnapshot == null) return '先点检查，再从元素生成点击节点。';
  if (candidate == null) return '未找到可读元素，可先用截图或区域目标。';
  return '将“${candidate.label}”保存为目标，并加一个点击节点。';
}

// 清理短文本，避免空值或过长内容进入按钮摘要和目标名称。
String? _safeInspectorText(String? value) {
  final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized == null || normalized.isEmpty) return null;
  return normalized.length <= 24 ? normalized : normalized.substring(0, 24);
}

// 将目标名转为安全 ID 片段。
String _safeInspectorAssetId(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return normalized.isEmpty ? 'inspector_target' : normalized;
}
